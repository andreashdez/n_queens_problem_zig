const std = @import("std");

pub const Chromosome = struct {
    positions: std.ArrayList(u16),
    conflicts: std.ArrayList(u16),
    conflicts_sum: u16,
    fitness: f16,

    pub fn init(positions: std.ArrayList(u16), allocator: std.mem.Allocator) !Chromosome {
        const conflicts: std.ArrayList(u16) = try countConflicts(positions, allocator);
        var conflicts_sum: u16 = 0;
        for (conflicts.items) |conflict| {
            conflicts_sum += conflict;
        }
        return Chromosome{
            .positions = positions,
            .conflicts = conflicts,
            .conflicts_sum = conflicts_sum / 2,
            .fitness = 0.0,
        };
    }

    pub fn deinit(self: *Chromosome, allocator: std.mem.Allocator) void {
        self.positions.deinit(allocator);
        self.conflicts.deinit(allocator);
    }
};

pub fn generateDistRandVals(size: usize, allocator: std.mem.Allocator) !std.ArrayList(u16) {
    const rand = std.crypto.random;
    var list = try std.ArrayList(u16).initCapacity(allocator, size);
    for (0..size) |i| {
        const element: u16 = @intCast(i);
        try list.append(allocator, element);
    }
    rand.shuffle(u16, list.items);
    return list;
}

pub fn countConflicts(positions: std.ArrayList(u16), allocator: std.mem.Allocator) !std.ArrayList(u16) {
    const size = positions.items.len;
    var conflicts = try std.ArrayList(u16).initCapacity(allocator, size);
    try conflicts.appendNTimes(allocator, 0, size);
    for (0..size - 1) |x_two| {
        for (x_two + 1..size) |x_one| {
            const distance = x_one - x_two;
            const y_one: i16 = @intCast(positions.items[x_one]);
            const y_two: i16 = @intCast(positions.items[x_two]);
            const y_dist = @abs(y_one - y_two);
            if (y_dist == distance) {
                conflicts.items[x_one] += 1;
                conflicts.items[x_two] += 1;
            }
        }
    }
    return conflicts;
}
