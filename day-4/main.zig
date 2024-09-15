const std = @import("std");

const Card = @import("card.zig").Card;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_inputs.txt", .{ .mode = .read_only });
    defer inputs.close();

    const multiplicative_score = try getCardsMultiplicativeScore(inputs, allocator);
    std.debug.print("Total Multiplicative Score: {}\n", .{multiplicative_score});

    try inputs.seekTo(0);
    const card_count = try getTotalCardCount(inputs, allocator);
    std.debug.print("Total Card Count: {}\n", .{card_count});
}

fn getCardsMultiplicativeScore(file: std.fs.File, allocator: std.mem.Allocator) !u32 {
    var total_score: u32 = 0;
    const cards = try parseCards(file, allocator);

    for (cards) |card| {
        total_score += card.tabulateMultiplicative();
        card.deinit();
    }

    allocator.free(cards);

    return total_score;
}

const BUFFER_SIZE: u16 = 1024;

fn getTotalCardCount(file: std.fs.File, allocator: std.mem.Allocator) !u32 {
    var total_card_count: u32 = 0;

    const CardDetails = struct {
        count: u32,
        card: Card,
    };

    var cardDetails = try allocator.alloc(CardDetails, BUFFER_SIZE);

    const first_card = try getNextCard(file, allocator);
    if (!first_card.has_next) {
        return 1;
    }

    var index: u16 = 0;
    var num_cards: u16 = 0;
    var last_card_index: u32 = 0;

    const cardDetail = CardDetails{ .count = 1, .card = first_card.card };
    cardDetails[0] = cardDetail;
    defer for (0..num_cards) |i| {
        cardDetails[i].card.deinit();
    };

    if (!first_card.has_next) {
        return 1;
    }

    while (true) {
        if (last_card_index != 0 and index > last_card_index) {
            break;
        }

        if (index > num_cards) {
            const next_card = try getNextCard(file, allocator);
            const new_card_detail = CardDetails{ .count = 1, .card = next_card.card };
            cardDetails[index] = new_card_detail;

            num_cards += 1;

            if (!next_card.has_next) {
                total_card_count += 1;
                break;
            }
        }

        const detail = cardDetails[index];
        total_card_count += detail.count;
        index += 1;

        const additional_cards = detail.card.tabulate();
        for (index..index + additional_cards) |i| {
            if (i > num_cards) {
                const next_card = try getNextCard(file, allocator);
                const new_card_detail = CardDetails{ .count = detail.count + 1, .card = next_card.card };
                cardDetails[i] = new_card_detail;
                num_cards += 1;

                if (!next_card.has_next) {
                    last_card_index = @truncate(i);
                    break;
                }
            } else {
                cardDetails[i].count += detail.count;
            }
        }
    }

    return total_card_count;
}

const NextCard = struct {
    card: Card,
    has_next: bool,
};
fn getNextCard(file: std.fs.File, allocator: std.mem.Allocator) !NextCard {
    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    var card_list = std.ArrayList(u8).init(allocator);
    defer card_list.deinit();

    while (true) {
        const letters_read = try file.read(buf);

        if (buf[0] == '\n' or letters_read == 0) {
            const card_data = try card_list.toOwnedSlice();
            defer allocator.free(card_data);

            const card = try Card.fromString(card_data, allocator);
            return NextCard{ .card = card, .has_next = letters_read > 0 };
        } else {
            try card_list.append(buf[0]);
        }
    }
}

fn parseCards(file: std.fs.File, allocator: std.mem.Allocator) ![]Card {
    var cards = std.ArrayList(Card).init(allocator);
    defer cards.deinit();

    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    var card_list = std.ArrayList(u8).init(allocator);
    defer card_list.deinit();

    while (true) {
        const letters_read = try file.read(buf);

        if (buf[0] == '\n' or letters_read == 0) {
            if (card_list.items.len > 0) {
                const card_data = try card_list.toOwnedSlice();

                const card = try Card.fromString(card_data, allocator);
                try cards.append(card);

                card_list.clearAndFree();
                allocator.free(card_data);
            }

            if (letters_read == 0) {
                break;
            }
        } else {
            try card_list.append(buf[0]);
        }
    }

    const all_cards = try cards.toOwnedSlice();
    cards.clearAndFree();

    return all_cards;
}

test "getTotalCardCount memory does not leak" {
    const inputs = try std.fs.cwd().openFile("puzzle_inputs.txt", .{ .mode = .read_only });
    defer inputs.close();

    _ = try getCardsMultiplicativeScore(inputs, std.testing.allocator);
}
