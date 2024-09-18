const std = @import("std");

const Hand = @import("hand.zig").Hand;
const root = @import("root.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const hands = try getHandsFromFile(inputs, allocator);
    defer allocator.free(hands);

    try root.mergeSort(Hand, hands, 0, hands.len - 1, compFn, allocator);

    var total_value: usize = 0;
    for (hands, 1..) |hand, i| {
        hand.print();
        const value = i * hand.bid;
        total_value += value;
    }

    std.debug.print("Total bid value: {}\n", .{total_value});
}

const ReadError = error{
    HandReadError,
    BidReadError,
    IncorrectSizeError,
};
fn getHandsFromFile(file: std.fs.File, allocator: std.mem.Allocator) ![]Hand {
    const hand_buf = try allocator.alloc(u8, 5);
    defer allocator.free(hand_buf);

    const bid_buf = try allocator.alloc(u8, 1);
    defer allocator.free(bid_buf);

    var letters_read: usize = 0;

    var hand_list = std.ArrayList([5]u8).init(allocator);
    defer hand_list.deinit();

    var bid_list = std.ArrayList(u32).init(allocator);
    defer bid_list.deinit();

    outer_loop: while (true) {
        letters_read = try file.read(hand_buf);
        if (letters_read != 5) {
            return ReadError.HandReadError;
        }

        letters_read = try file.read(bid_buf);
        if (letters_read != 1 or bid_buf[0] != ' ') {
            return ReadError.BidReadError;
        }

        const hand_array = [5]u8{
            hand_buf[0],
            hand_buf[1],
            hand_buf[2],
            hand_buf[3],
            hand_buf[4],
        };
        try hand_list.append(hand_array);

        var bid: u32 = 0;
        inner_loop: while (true) {
            letters_read = try file.read(bid_buf);
            const letter = bid_buf[0];

            if (letter == '\n' or letters_read == 0) {
                try bid_list.append(bid);

                if (letters_read == 0) {
                    break :outer_loop;
                } else {
                    break :inner_loop;
                }
            }

            if (letter < '0' or letter > '9') {
                return ReadError.BidReadError;
            }

            bid = bid * 10 + letter - '0';
        }
    }

    const hands = try hand_list.toOwnedSlice();
    const bids = try bid_list.toOwnedSlice();

    if (hands.len != bids.len) {
        return ReadError.IncorrectSizeError;
    }

    var hand_items = try std.ArrayList(Hand).initCapacity(allocator, hands.len);
    defer hand_items.deinit();

    for (0..hands.len) |i| {
        const hand_item = try Hand.new(hands[i], bids[i]);
        try hand_items.append(hand_item);
    }

    const all_hands = try hand_items.toOwnedSlice();
    hand_items.clearAndFree();

    return all_hands;
}

fn compFn(a: *Hand, b: *Hand) bool {
    return a.isBetter(b);
}
