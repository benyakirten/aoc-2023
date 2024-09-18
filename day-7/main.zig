const std = @import("std");

const Hand = @import("hand.zig").Hand;
const root = @import("root.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const hands = try root.getHandsFromFile(inputs, allocator, Hand.new);
    defer allocator.free(hands);

    try root.mergeSort(Hand, hands, 0, hands.len - 1, compFn, allocator);

    var total_value: usize = 0;
    for (hands, 1..) |hand, i| {
        const value = i * hand.bid;
        total_value += value;
    }

    std.debug.print("Total bid value: {}\n", .{total_value});

    try inputs.seekTo(0);

    const hands_with_jokers = try root.getHandsFromFile(inputs, allocator, Hand.newWithJokers);
    defer allocator.free(hands_with_jokers);

    try root.mergeSort(Hand, hands_with_jokers, 0, hands.len - 1, compWithJokersFn, allocator);

    var total_value_with_jokers: usize = 0;
    for (hands_with_jokers, 1..) |hand, i| {
        const value = i * hand.bid;
        total_value_with_jokers += value;
    }

    std.debug.print("Total bid value with jokers: {}\n", .{total_value_with_jokers});
}

fn compFn(a: *Hand, b: *Hand) bool {
    return a.isBetter(b);
}

fn compWithJokersFn(a: *Hand, b: *Hand) bool {
    return a.isBetterWithJokers(b);
}

test "main functionality has no memory leaks" {
    const inputs = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const hands = try root.getHandsFromFile(inputs, std.testing.allocator, Hand.new);
    defer std.testing.allocator.free(hands);

    try root.mergeSort(Hand, hands, 0, hands.len - 1, compFn, std.testing.allocator);

    try inputs.seekTo(0);

    const hands_with_jokers = try root.getHandsFromFile(inputs, std.testing.allocator, Hand.newWithJokers);
    defer std.testing.allocator.free(hands_with_jokers);

    try root.mergeSort(Hand, hands_with_jokers, 0, hands.len - 1, compWithJokersFn, std.testing.allocator);
}
