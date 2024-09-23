const std = @import("std");

const Races = @import("race.zig").Races;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const unconsolidated_races = try Races.fromFile(inputs, allocator);
    defer unconsolidated_races.deinit();

    const unconsolidated_hold_times = try unconsolidated_races.getWaysToWinByRace();
    defer allocator.free(unconsolidated_hold_times);

    var num_ways_to_win: usize = 1;
    for (unconsolidated_hold_times) |time| {
        num_ways_to_win *= time;
    }

    std.debug.print("Unconsolidated num ways to win: {}\n", .{num_ways_to_win});

    try inputs.seekTo(0);
    const consolidated_races = try Races.fromFileConsolidated(inputs, allocator);
    defer consolidated_races.deinit();

    const consolidated_hold_times = try consolidated_races.getWaysToWinByRace();
    defer allocator.free(consolidated_hold_times);

    std.debug.print("Consolidted num ways to win: {}\n", .{consolidated_hold_times[0]});
}

test "main has no memory leaks" {
    try main();
}
