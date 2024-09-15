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

    pub fn tabulate(self: Card) u16 {
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

// I'm sick of dealing with type conversions
// and the crazy crap I have to do to get it to work.
// The test has a memory leak but it passes.
test "Card.tabulate table test" {
    const TabulateItem = struct { card: []u8, want: u16 };

    var card_list = std.ArrayList([]u8).init(std.testing.allocator);
    defer card_list.deinit();

    var card_list_item_list = std.ArrayList(u8).init(std.testing.allocator);
    defer card_list_item_list.deinit();

    try card_list_item_list.appendSlice("Card  11:  1 48 83 86 17 |  2  3  6 31  7  9  8 53"[0..]);
    try card_list.append(try card_list_item_list.toOwnedSlice());
    card_list_item_list.clearAndFree();

    try card_list_item_list.appendSlice("Card  12:  1 48 83 86 17 |  2  3  6 31  7  9 48 53"[0..]);
    try card_list.append(try card_list_item_list.toOwnedSlice());
    card_list_item_list.clearAndFree();

    try card_list_item_list.appendSlice("Card  13:  1 48 83 86 17 |  2  3  6 31 17  9 48 53"[0..]);
    try card_list.append(try card_list_item_list.toOwnedSlice());
    card_list_item_list.clearAndFree();

    try card_list_item_list.appendSlice("Card  14:  1 48 83 86 17 |  2  3 86 31 17  9 48 53"[0..]);
    try card_list.append(try card_list_item_list.toOwnedSlice());
    card_list_item_list.clearAndFree();

    try card_list_item_list.appendSlice("Card  15:  1 48 83 86 17 |  2 83 86 31 17  9 48 53"[0..]);
    try card_list.append(try card_list_item_list.toOwnedSlice());
    card_list_item_list.clearAndFree();

    const card_string = try card_list.toOwnedSlice();
    defer std.testing.allocator.free(card_string);

    var tabulate_items_list = std.ArrayList(TabulateItem).init(std.testing.allocator);
    defer tabulate_items_list.deinit();

    try tabulate_items_list.append(TabulateItem{ .card = card_string[0], .want = 0 });
    try tabulate_items_list.append(TabulateItem{ .card = card_string[1], .want = 1 });
    try tabulate_items_list.append(TabulateItem{ .card = card_string[2], .want = 2 });
    try tabulate_items_list.append(TabulateItem{ .card = card_string[3], .want = 4 });
    try tabulate_items_list.append(TabulateItem{ .card = card_string[4], .want = 8 });

    const tabulate_items = try tabulate_items_list.toOwnedSlice();
    defer std.testing.allocator.free(tabulate_items);

    for (tabulate_items) |item| {
        const card = try Card.fromString(item.card, std.testing.allocator);
        defer card.deinit();

        const got = card.tabulate();
        try std.testing.expectEqual(item.want, got);
    }
}
