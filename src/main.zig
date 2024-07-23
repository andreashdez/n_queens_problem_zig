const std = @import("std");
const chrm = @import("chromosome.zig");
const ga = @import("ga.zig");

pub const std_options = .{
    .log_level = .info,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("DATA LEAK");
    }

    var genetic_algorithm = try ga.buildGeneticAlgorithm(16, 400, allocator);
    defer genetic_algorithm.deinit();
    const best_chromosome = try genetic_algorithm.runAlgorithm(allocator);
    const worst_chromosome = genetic_algorithm.getWorstChromosome();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("population: {any}\n", .{genetic_algorithm.population.items.len});
    try stdout.print("--------------------------------\n", .{});
    try stdout.print(" best chromosome:\n", .{});
    try stdout.print("  positions     = {any}\n", .{best_chromosome.positions.items});
    try stdout.print("  conflicts     = {any}\n", .{best_chromosome.conflicts.items});
    try stdout.print("  conflicts_sum = {any}\n", .{best_chromosome.conflicts_sum});
    try stdout.print("  fitness       = {any}\n", .{best_chromosome.fitness});
    try stdout.print("--------------------------------\n", .{});
    try stdout.print(" worst chromosome:\n", .{});
    try stdout.print("  positions     = {any}\n", .{worst_chromosome.positions.items});
    try stdout.print("  conflicts     = {any}\n", .{worst_chromosome.conflicts.items});
    try stdout.print("  conflicts_sum = {any}\n", .{worst_chromosome.conflicts_sum});
    try stdout.print("  fitness       = {any}\n", .{worst_chromosome.fitness});
    try bw.flush();
}

test "random slice order test" {
    const test_allocator = std.testing.allocator;
    const rand = std.crypto.random;
    const slice: []const u16 = &.{ 0, 1, 2, 3, 4, 5, 6, 7 };
    var list = std.ArrayList(u16).init(test_allocator);
    defer list.deinit();
    try list.appendSlice(slice);
    const s = list.items;
    rand.shuffle(u16, s);
}

test "find position test" {
    const test_allocator = std.testing.allocator;
    var parent_one = try std.ArrayList(u16).initCapacity(test_allocator, 8);
    var parent_two = try std.ArrayList(u16).initCapacity(test_allocator, 8);
    var child = try std.ArrayList(?u16).initCapacity(test_allocator, 8);
    defer parent_one.deinit();
    defer parent_two.deinit();
    defer child.deinit();
    try parent_one.appendSlice(&.{ 0, 2, 4, 6, 1, 3, 5, 7 });
    try parent_two.appendSlice(&.{ 2, 7, 1, 6, 5, 3, 0, 4 });
    try child.appendSlice(&.{ null, 2, 4, 6, 1, null, null, null });
    const position = ga.findPosition(4, parent_one, parent_two, child);
    try std.testing.expectEqual(7, position);
}

test "calculate fitness test" {
    const test_allocator = std.testing.allocator;
    var genes_1 = try std.ArrayList(u16).initCapacity(test_allocator, 8);
    var genes_2 = try std.ArrayList(u16).initCapacity(test_allocator, 8);
    var genes_3 = try std.ArrayList(u16).initCapacity(test_allocator, 8);
    var genes_4 = try std.ArrayList(u16).initCapacity(test_allocator, 8);
    var genes_5 = try std.ArrayList(u16).initCapacity(test_allocator, 8);
    var genes_6 = try std.ArrayList(u16).initCapacity(test_allocator, 8);
    try genes_1.appendSlice(&.{ 0, 2, 4, 6, 1, 3, 5, 7 });
    try genes_2.appendSlice(&.{ 2, 4, 1, 7, 5, 0, 6, 3 });
    try genes_3.appendSlice(&.{ 2, 4, 1, 7, 6, 0, 3, 5 });
    try genes_4.appendSlice(&.{ 2, 4, 5, 7, 6, 0, 3, 1 });
    try genes_5.appendSlice(&.{ 1, 4, 5, 7, 6, 0, 3, 2 });
    try genes_6.appendSlice(&.{ 2, 4, 1, 7, 6, 0, 5, 3 });
    const chromosome_1 = try chrm.Chromosome.init(genes_1, test_allocator);
    const chromosome_2 = try chrm.Chromosome.init(genes_2, test_allocator);
    const chromosome_3 = try chrm.Chromosome.init(genes_3, test_allocator);
    const chromosome_4 = try chrm.Chromosome.init(genes_4, test_allocator);
    const chromosome_5 = try chrm.Chromosome.init(genes_5, test_allocator);
    const chromosome_6 = try chrm.Chromosome.init(genes_6, test_allocator);
    var population = try std.ArrayList(chrm.Chromosome).initCapacity(test_allocator, 6);
    try population.appendSlice(&.{ chromosome_1, chromosome_2, chromosome_3, chromosome_4, chromosome_5, chromosome_6 });
    var genetic_algorithm = ga.GeneticAlgorithm.init(population);
    defer genetic_algorithm.deinit();
    try genetic_algorithm.calcFitness();
    try std.testing.expectEqual(0.0, genetic_algorithm.getWorstChromosome().fitness);
    try std.testing.expectEqual(1.0, genetic_algorithm.getBestChromosome().fitness);
}

test "chromosome conflicts test" {
    const test_allocator = std.testing.allocator;
    const slice: []const u16 = &.{ 0, 2, 4, 6, 1, 3, 5, 7 };
    var positions = std.ArrayList(u16).init(test_allocator);
    try positions.appendSlice(slice);
    const chromosome = try chrm.Chromosome.init(positions, test_allocator);
    defer chromosome.deinit();
    const conflicts = chromosome.conflicts.items;
    const expected_conflicts: []const u16 = &.{ 1, 0, 0, 0, 0, 0, 0, 1 };
    try std.testing.expectEqualSlices(u16, conflicts, expected_conflicts);
}
