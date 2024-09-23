const std = @import("std");

const HotSprings = @import("springs.zig").HotSprings;
const Record = @import("springs.zig").Record;

const MAX_BUFFER_SIZE = 1_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const content = try inputs.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
    defer allocator.free(content);

    const hot_springs = try HotSprings.parse(content, allocator);
    defer allocator.free(hot_springs);

    // var num_permutations: usize = 0;
    // for (hot_springs) |springs| {
    //     const permutations = try springs.bruteForcePermute();
    //     num_permutations += permutations.len;
    // }

    // std.debug.print("Total permutations: {}\n", .{num_permutations});

    var num_unfolded_permutations: usize = 0;
    for (hot_springs) |springs| {
        const permutations = try springs.permute(5);
        num_unfolded_permutations += permutations;
    }

    std.debug.print("Total unfolded permutations: {}\n", .{num_unfolded_permutations});
}
