const std = @import("std");

const Hand = @import("hand.zig").Hand;

fn merge(comptime T: type, slice: []T, left_index: usize, middle_index: usize, right_index: usize, isBetter: fn (item: *T, other: *T) bool, allocator: std.mem.Allocator) !void {
    const left_size: usize = middle_index - left_index + 1;
    const right_size: usize = right_index - middle_index;

    var left = try allocator.alloc(T, left_size);
    defer allocator.free(left);

    var right = try allocator.alloc(T, right_size);
    defer allocator.free(right);

    for (0..left_size) |idx| {
        left[idx] = slice[left_index + idx];
    }

    for (0..right_size) |idx| {
        right[idx] = slice[middle_index + idx + 1];
    }

    var i: usize = 0;
    var j: usize = 0;
    var k: usize = left_index;

    while (i < left_size and j < right_size) {
        // Sorted in ascending order of betterness
        if (!isBetter(&left[i], &right[j])) {
            slice[k] = left[i];
            i += 1;
        } else {
            slice[k] = right[j];
            j += 1;
        }
        k += 1;
    }

    // Copy remaining items
    while (i < left_size) {
        slice[k] = left[i];
        i += 1;
        k += 1;
    }

    while (j < right_size) {
        slice[k] = right[j];
        j += 1;
        k += 1;
    }
}

pub fn mergeSort(comptime T: type, slice: []T, left_index: usize, right_index: usize, isBetter: fn (item: *T, other: *T) bool, allocator: std.mem.Allocator) !void {
    if (left_index < right_index) {
        const middle_index: usize = left_index + (right_index - left_index) / 2;
        try mergeSort(T, slice, left_index, middle_index, isBetter, allocator);
        try mergeSort(T, slice, middle_index + 1, right_index, isBetter, allocator);

        try merge(T, slice, left_index, middle_index, right_index, isBetter, allocator);
    }
}

pub const ReadError = error{
    HandReadError,
    BidReadError,
    IncorrectSizeError,
};

const HandData = struct {
    hand: [5]u8,
    bid: u32,
};

fn getHandDataFromFile(file: std.fs.File, allocator: std.mem.Allocator) ![]HandData {
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
    defer allocator.free(hands);

    const bids = try bid_list.toOwnedSlice();
    defer allocator.free(bids);

    if (hands.len != bids.len) {
        return ReadError.IncorrectSizeError;
    }

    var hand_data = try allocator.alloc(HandData, hands.len);
    for (0..hands.len) |i| {
        const hand_datum = hands[i];
        const bid_datum = bids[i];
        const datum = HandData{ .bid = bid_datum, .hand = hand_datum };
        hand_data[i] = datum;
    }

    return hand_data;
}

pub fn getHandsFromFile(file: std.fs.File, allocator: std.mem.Allocator) ![]Hand {
    const hand_data = try getHandDataFromFile(file, allocator);
    defer allocator.free(hand_data);

    var hand_items = try std.ArrayList(Hand).initCapacity(allocator, hand_data.len);
    defer hand_items.deinit();

    for (hand_data) |datum| {
        const hand_item = try Hand.new(datum.hand, datum.bid);
        try hand_items.append(hand_item);
    }

    const all_hands = try hand_items.toOwnedSlice();
    hand_items.clearAndFree();

    return all_hands;
}
