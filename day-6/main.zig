const std = @import("std");

const Races = @import("race.zig").Races;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const races = try Races.fromFile(inputs, allocator);
    const hold_times = try races.getAllHoldTimesSuperiorToDistance();

    var num_ways_to_win: usize = 1;
    for (hold_times) |time| {
        num_ways_to_win *= time;
    }

    std.debug.print("Num ways to win: {}\n", .{num_ways_to_win});
}

test "main has no memory leaks" {
    try main();
}
