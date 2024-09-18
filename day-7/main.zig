const std = @import("std");

const Hand = @import("hand.zig").Hand;
const root = @import("root.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const hands = try root.getHandsFromFile(inputs, allocator);
    defer allocator.free(hands);

    try root.mergeSort(Hand, hands, 0, hands.len - 1, compFn, allocator);

    var total_value: usize = 0;
    for (hands, 1..) |hand, i| {
        const value = i * hand.bid;
        total_value += value;
    }

    std.debug.print("Total bid value: {}\n", .{total_value});
}

fn compFn(a: *Hand, b: *Hand) bool {
    return a.isBetter(b);
}
