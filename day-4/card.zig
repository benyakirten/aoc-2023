const std = @import("std");

const CARD_START: []const u8 = "Card"[0..];

const CardError = error{
    ParsingError,
};

pub const Card = struct {
    // This is more efficient than a hashmap/set
    // for small numbers of elements (<50k elements)
    winning_numbers: []u8,
    my_numbers: []u8,
    id: u16,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Card) void {
        self.allocator.free(self.winning_numbers);
        self.allocator.free(self.my_numbers);
    }

    pub fn tabulateMultiplicative(self: Card) u16 {
        var score: u16 = 0;
        for (self.my_numbers) |my_number| {
            for (self.winning_numbers) |winning_number| {
                if (my_number == winning_number) {
                    if (score == 0) {
                        score = 1;
                    } else {
                        score *= 2;
                    }
                }
            }
        }

        return score;
    }

    pub fn tabulate(self: Card) u16 {
        var score: u16 = 0;
        for (self.my_numbers) |my_number| {
            for (self.winning_numbers) |winning_number| {
                if (my_number == winning_number) {
                    score += 1;
                }
            }
        }

        return score;
    }

    pub fn fromString(card: []u8, allocator: std.mem.Allocator) !Card {
        var winning_numbers = std.ArrayList(u8).init(allocator);
        defer winning_numbers.deinit();

        var my_numbers = std.ArrayList(u8).init(allocator);
        defer my_numbers.deinit();

        var starting_index = CARD_START.len;

        if (!std.mem.eql(u8, card[0..starting_index], CARD_START)) {
            return CardError.ParsingError;
        }

        var id: u16 = 0;
        while (true) {
            starting_index += 1;
            const letter = card[starting_index];

            if (letter == ':') {
                if (id == 0) {
                    return CardError.ParsingError;
                }
                break;
            }

            if (letter >= '0' and letter <= '9') {
                id = id * 10 + (letter - '0');
            }
        }

        var is_parsing_winning_numbers = true;
        var current_number: u8 = 0;

        const remaining_card = card[starting_index..];
        for (remaining_card, 0..) |c, i| {
            if (c == '|') {
                is_parsing_winning_numbers = false;
                continue;
            }

            if (c >= '0' and c <= '9') {
                current_number = current_number * 10 + (c - '0');
            }

            if ((c == ' ' or i == remaining_card.len - 1) and current_number > 0) {
                if (is_parsing_winning_numbers) {
                    try winning_numbers.append(current_number);
                } else {
                    try my_numbers.append(current_number);
                }

                current_number = 0;
                continue;
            }
        }

        return Card{
            .winning_numbers = try winning_numbers.toOwnedSlice(),
            .my_numbers = try my_numbers.toOwnedSlice(),
            .id = id,
            .allocator = allocator,
        };
    }
};

test "Card.fromString" {
    var card_list = std.ArrayList(u8).init(std.testing.allocator);
    defer card_list.deinit();

    try card_list.appendSlice("Card  11:  1 48 83 86 17 | 83 86  6 31 17  9 48 53"[0..]);

    const card_string = try card_list.toOwnedSlice();
    defer std.testing.allocator.free(card_string);

    const card = try Card.fromString(card_string, std.testing.allocator);
    defer card.deinit();

    var want_winning_numbers_list = std.ArrayList(u8).init(std.testing.allocator);
    defer want_winning_numbers_list.deinit();

    try want_winning_numbers_list.append(1);
    try want_winning_numbers_list.append(48);
    try want_winning_numbers_list.append(83);
    try want_winning_numbers_list.append(86);
    try want_winning_numbers_list.append(17);

    var want_my_numbers_list = std.ArrayList(u8).init(std.testing.allocator);
    defer want_my_numbers_list.deinit();

    try want_my_numbers_list.append(83);
    try want_my_numbers_list.append(86);
    try want_my_numbers_list.append(6);
    try want_my_numbers_list.append(31);
    try want_my_numbers_list.append(17);
    try want_my_numbers_list.append(9);
    try want_my_numbers_list.append(48);
    try want_my_numbers_list.append(53);

    const want_winning_numbers = try want_winning_numbers_list.toOwnedSlice();
    defer std.testing.allocator.free(want_winning_numbers);

    const want_my_numbers = try want_my_numbers_list.toOwnedSlice();
    defer std.testing.allocator.free(want_my_numbers);

    try std.testing.expectEqualDeep(want_winning_numbers, card.winning_numbers);
    try std.testing.expectEqualDeep(want_my_numbers, card.my_numbers);
    try std.testing.expectEqual(11, card.id);
}

test "Card.tabulateMultiplicative 0" {
    const winning_numbers = [5]u8{ 1, 2, 3, 4, 5 };
    const winning_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    winning_numbers_slice[0] = winning_numbers[0];
    winning_numbers_slice[1] = winning_numbers[1];
    winning_numbers_slice[2] = winning_numbers[2];
    winning_numbers_slice[3] = winning_numbers[3];
    winning_numbers_slice[4] = winning_numbers[4];

    const my_numbers = [5]u8{ 6, 7, 8, 9, 10 };
    const my_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    my_numbers_slice[0] = my_numbers[0];
    my_numbers_slice[1] = my_numbers[1];
    my_numbers_slice[2] = my_numbers[2];
    my_numbers_slice[3] = my_numbers[3];
    my_numbers_slice[4] = my_numbers[4];

    const card = Card{
        .winning_numbers = winning_numbers_slice,
        .my_numbers = my_numbers_slice,
        .id = 0,
        .allocator = std.testing.allocator,
    };
    defer card.deinit();

    const got = card.tabulateMultiplicative();
    const want: u16 = 0;

    try std.testing.expectEqual(want, got);
}

test "Card.tabulateMultiplicative 1" {
    const winning_numbers = [5]u8{ 1, 2, 3, 4, 5 };
    const winning_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    winning_numbers_slice[0] = winning_numbers[0];
    winning_numbers_slice[1] = winning_numbers[1];
    winning_numbers_slice[2] = winning_numbers[2];
    winning_numbers_slice[3] = winning_numbers[3];
    winning_numbers_slice[4] = winning_numbers[4];

    const my_numbers = [5]u8{ 5, 6, 7, 8, 9 };
    const my_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    my_numbers_slice[0] = my_numbers[0];
    my_numbers_slice[1] = my_numbers[1];
    my_numbers_slice[2] = my_numbers[2];
    my_numbers_slice[3] = my_numbers[3];
    my_numbers_slice[4] = my_numbers[4];

    const card = Card{
        .winning_numbers = winning_numbers_slice,
        .my_numbers = my_numbers_slice,
        .id = 0,
        .allocator = std.testing.allocator,
    };
    defer card.deinit();

    const got = card.tabulateMultiplicative();
    const want: u16 = 1;

    try std.testing.expectEqual(want, got);
}

test "Card.tabulateMultiplicative 4" {
    const winning_numbers = [5]u8{ 1, 2, 3, 4, 5 };
    const winning_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    winning_numbers_slice[0] = winning_numbers[0];
    winning_numbers_slice[1] = winning_numbers[1];
    winning_numbers_slice[2] = winning_numbers[2];
    winning_numbers_slice[3] = winning_numbers[3];
    winning_numbers_slice[4] = winning_numbers[4];

    const my_numbers = [5]u8{ 3, 4, 5, 6, 7 };
    const my_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    my_numbers_slice[0] = my_numbers[0];
    my_numbers_slice[1] = my_numbers[1];
    my_numbers_slice[2] = my_numbers[2];
    my_numbers_slice[3] = my_numbers[3];
    my_numbers_slice[4] = my_numbers[4];

    const card = Card{
        .winning_numbers = winning_numbers_slice,
        .my_numbers = my_numbers_slice,
        .id = 0,
        .allocator = std.testing.allocator,
    };
    defer card.deinit();

    const got = card.tabulateMultiplicative();
    const want: u16 = 4;

    try std.testing.expectEqual(want, got);
}

test "Card.tabulate 0" {
    const winning_numbers = [5]u8{ 1, 2, 3, 4, 5 };
    const winning_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    winning_numbers_slice[0] = winning_numbers[0];
    winning_numbers_slice[1] = winning_numbers[1];
    winning_numbers_slice[2] = winning_numbers[2];
    winning_numbers_slice[3] = winning_numbers[3];
    winning_numbers_slice[4] = winning_numbers[4];

    const my_numbers = [5]u8{ 6, 7, 8, 9, 10 };
    const my_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    my_numbers_slice[0] = my_numbers[0];
    my_numbers_slice[1] = my_numbers[1];
    my_numbers_slice[2] = my_numbers[2];
    my_numbers_slice[3] = my_numbers[3];
    my_numbers_slice[4] = my_numbers[4];

    const card = Card{
        .winning_numbers = winning_numbers_slice,
        .my_numbers = my_numbers_slice,
        .id = 0,
        .allocator = std.testing.allocator,
    };
    defer card.deinit();

    const got = card.tabulate();
    const want: u16 = 0;

    try std.testing.expectEqual(want, got);
}

test "Card.tabulate 1" {
    const winning_numbers = [5]u8{ 1, 2, 3, 4, 5 };
    const winning_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    winning_numbers_slice[0] = winning_numbers[0];
    winning_numbers_slice[1] = winning_numbers[1];
    winning_numbers_slice[2] = winning_numbers[2];
    winning_numbers_slice[3] = winning_numbers[3];
    winning_numbers_slice[4] = winning_numbers[4];

    const my_numbers = [5]u8{ 5, 6, 7, 8, 9 };
    const my_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    my_numbers_slice[0] = my_numbers[0];
    my_numbers_slice[1] = my_numbers[1];
    my_numbers_slice[2] = my_numbers[2];
    my_numbers_slice[3] = my_numbers[3];
    my_numbers_slice[4] = my_numbers[4];

    const card = Card{
        .winning_numbers = winning_numbers_slice,
        .my_numbers = my_numbers_slice,
        .id = 0,
        .allocator = std.testing.allocator,
    };
    defer card.deinit();

    const got = card.tabulate();
    const want: u16 = 1;

    try std.testing.expectEqual(want, got);
}

test "Card.tabulate 3" {
    const winning_numbers = [5]u8{ 1, 2, 3, 4, 5 };
    const winning_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    winning_numbers_slice[0] = winning_numbers[0];
    winning_numbers_slice[1] = winning_numbers[1];
    winning_numbers_slice[2] = winning_numbers[2];
    winning_numbers_slice[3] = winning_numbers[3];
    winning_numbers_slice[4] = winning_numbers[4];

    const my_numbers = [5]u8{ 3, 4, 5, 6, 7 };
    const my_numbers_slice = try std.testing.allocator.alloc(u8, 5);
    my_numbers_slice[0] = my_numbers[0];
    my_numbers_slice[1] = my_numbers[1];
    my_numbers_slice[2] = my_numbers[2];
    my_numbers_slice[3] = my_numbers[3];
    my_numbers_slice[4] = my_numbers[4];

    const card = Card{
        .winning_numbers = winning_numbers_slice,
        .my_numbers = my_numbers_slice,
        .id = 0,
        .allocator = std.testing.allocator,
    };
    defer card.deinit();

    const got = card.tabulate();
    const want: u16 = 3;

    try std.testing.expectEqual(want, got);
}
