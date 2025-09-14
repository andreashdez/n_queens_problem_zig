const std = @import("std");
const chrm = @import("chromosome.zig");

const MIN_TO_MATE: usize = 10;
const MAX_TO_MATE: usize = 50;
const MAX_EPOCH_COUNT: usize = 5000;

pub const GeneticAlgorithm = struct {
    population: std.ArrayList(chrm.Chromosome),
    pub fn init(population: std.ArrayList(chrm.Chromosome)) GeneticAlgorithm {
        return GeneticAlgorithm{ .population = population };
    }
    pub fn deinit(self: *GeneticAlgorithm, allocator: std.mem.Allocator) void {
        for (self.population.items) |*chromosome| {
            chromosome.deinit(allocator);
        }
        self.population.deinit(allocator);
    }
    pub fn getBestChromosome(self: GeneticAlgorithm) chrm.Chromosome {
        const pop = self.population.items;
        var least_conflicts = pop[0].conflicts_sum;
        var index: usize = 0;
        for (pop[1..], 1..) |item, i| {
            const index_conflicts = item.conflicts_sum;
            if (index_conflicts < least_conflicts) {
                least_conflicts = index_conflicts;
                index = i;
            }
        }
        return self.population.items[index];
    }
    pub fn getWorstChromosome(self: GeneticAlgorithm) chrm.Chromosome {
        const pop = self.population.items;
        var most_conflicts = pop[0].conflicts_sum;
        var index: usize = 0;
        for (pop[1..], 1..) |item, i| {
            const index_conflicts = item.conflicts_sum;
            if (index_conflicts > most_conflicts) {
                most_conflicts = index_conflicts;
                index = i;
            }
        }
        return self.population.items[index];
    }
    pub fn calcFitness(self: GeneticAlgorithm) !void {
        const most_conflicts = self.getWorstChromosome().conflicts_sum;
        const least_conflicts = self.getBestChromosome().conflicts_sum;
        const diff_conflicts = most_conflicts - least_conflicts;
        std.log.debug("calculating fitness [worst_score={any}, best_score={any}, diff={any}]", .{ most_conflicts, least_conflicts, diff_conflicts });
        for (self.population.items, 0..) |chromosome, i| {
            const conflicts_sum = chromosome.conflicts_sum;
            const numerator: f16 = @floatFromInt(try std.math.powi(u16, most_conflicts - conflicts_sum, 3));
            const denominator: f16 = @floatFromInt(try std.math.powi(u16, diff_conflicts, 3));
            const fitness = numerator / denominator;
            self.population.items[i].fitness = fitness;
            std.log.debug("calculating fitness for chromosome [conflicts={any}, fitness={any}]", .{ conflicts_sum, fitness });
        }
    }

    fn mateRandomChromosomes(self: *GeneticAlgorithm, min_to_mate: usize, max_to_mate: usize, allocator: std.mem.Allocator) !void {
        const rand = std.crypto.random;
        const mate_amount = rand.intRangeAtMost(usize, min_to_mate, max_to_mate);
        var fitness_sum: f32 = 0.0;
        for (self.population.items) |chromosome| {
            fitness_sum += chromosome.fitness;
        }
        std.log.debug("select random chromosomes [mate_amount={any}, fitness_sum={any}]", .{ mate_amount, fitness_sum });
        for (0..mate_amount) |_| {
            const parent_one = self.selectRandomChromosome(fitness_sum) orelse self.getBestChromosome();
            const parent_two = self.selectRandomChromosome(fitness_sum) orelse self.getWorstChromosome();
            const child = try mateChromosomes(parent_one, parent_two, allocator);
            try self.population.append(allocator, child);
        }
    }

    fn selectRandomChromosome(self: GeneticAlgorithm, fitness_sum: f32) ?chrm.Chromosome {
        const rand = std.crypto.random;
        const roulette_spin = (rand.float(f32) * fitness_sum);
        var selection_rank: f32 = 0.0;
        for (self.population.items) |chromosome| {
            selection_rank += chromosome.fitness;
            if (selection_rank > roulette_spin) {
                std.log.debug("selecting chromosome: {any}", .{chromosome.positions.items});
                return chromosome;
            }
        }
        return null;
    }

    pub fn runAlgorithm(self: *GeneticAlgorithm, allocator: std.mem.Allocator) !chrm.Chromosome {
        try self.calcFitness();
        for (0..MAX_EPOCH_COUNT) |epoch| {
            try self.mateRandomChromosomes(MIN_TO_MATE, MAX_TO_MATE, allocator);
            try self.calcFitness();
            std.log.info("epoch: {any}", .{epoch});
            std.log.info("best chromosome conflicts sum: {any}", .{self.getBestChromosome().conflicts_sum});
            if (self.getBestChromosome().conflicts_sum == 0) {
                return self.getBestChromosome();
            }
        }
        return self.getBestChromosome();
    }
};

fn mateChromosomes(parent_one: chrm.Chromosome, parent_two: chrm.Chromosome, allocator: std.mem.Allocator) !chrm.Chromosome {
    std.log.debug("mate chromosomes", .{});
    std.log.debug("parent_one={any}", .{parent_one.positions.items});
    std.log.debug("parent_two={any}", .{parent_two.positions.items});
    const child_genes: std.ArrayList(u16) = try pmx(parent_one.positions, parent_two.positions, allocator);
    const child = try chrm.Chromosome.init(child_genes, allocator);
    std.log.debug("child={any}", .{child.positions.items});
    return child;
}

fn pmx(parent_one: std.ArrayList(u16), parent_two: std.ArrayList(u16), allocator: std.mem.Allocator) !std.ArrayList(u16) {
    const rand = std.crypto.random;
    const chromosome_size = parent_one.items.len;
    const chromosome_half_size = chromosome_size / 2;
    const point_one = rand.intRangeAtMost(usize, 0, chromosome_half_size);
    const point_two = rand.intRangeAtMost(usize, chromosome_half_size, chromosome_size);
    std.log.debug("partially mapped crossover [point_one={any}, point_two={any}]", .{ point_one, point_two });
    var child_genes = try std.ArrayList(?u16).initCapacity(allocator, parent_one.items.len);
    defer child_genes.deinit(allocator);
    try child_genes.appendNTimes(allocator, null, parent_one.items.len);
    for (point_one..point_two) |i| {
        child_genes.items[i] = parent_one.items[i];
    }
    std.log.debug("child positions one: {any}", .{child_genes.items});
    for (point_one..point_two) |i| {
        var child_contains = false;
        for (child_genes.items) |child_gene| {
            if (child_gene == parent_two.items[i]) {
                child_contains = true;
            }
        }
        if (!child_contains) {
            const position = findPosition(i, parent_one, parent_two, child_genes);
            child_genes.items[position] = parent_two.items[i];
        }
    }
    std.log.debug("child positions two: {any}", .{child_genes.items});
    for (0..chromosome_size) |i| {
        if (child_genes.items[i] == null) {
            child_genes.items[i] = parent_two.items[i];
        }
    }
    std.log.debug("child positions three: {any}", .{child_genes.items});
    var child_genes_result = try std.ArrayList(u16).initCapacity(allocator, parent_one.items.len);
    for (child_genes.items) |child_gene| {
        const child_gene_result = child_gene orelse unreachable;
        try child_genes_result.append(allocator, child_gene_result);
    }
    return child_genes_result;
}

fn compareChromosomeByConflictsSum(a: chrm.Chromosome, b: chrm.Chromosome) bool {
    return a.conflicts_sum < b.conflicts_sum;
}

pub fn buildGeneticAlgorithm(size: usize, initial_population: usize, allocator: std.mem.Allocator) !GeneticAlgorithm {
    var population = try std.ArrayList(chrm.Chromosome).initCapacity(allocator, size);
    for (0..initial_population) |_| {
        const positions = try chrm.generateDistRandVals(size, allocator);
        const chromosome = try chrm.Chromosome.init(positions, allocator);
        try population.append(allocator, chromosome);
    }
    return GeneticAlgorithm.init(population);
}

pub fn findPosition(
    index: usize,
    parent_one: std.ArrayList(u16),
    parent_two: std.ArrayList(u16),
    child: std.ArrayList(?u16),
) u16 {
    var position: u16 = undefined;
    for (parent_two.items, 0..) |gene_two, i| {
        if (gene_two == parent_one.items[index]) {
            position = @intCast(i);
        }
    }
    if (child.items[position] == null) {
        return position;
    } else {
        return findPosition(position, parent_one, parent_two, child);
    }
}
