const std = @import("std");

const Card = @import("card.zig").Card;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_inputs.txt", .{ .mode = .read_only });
    const cards = try parseCards(inputs, allocator);
    defer for (cards) |card| {
        card.deinit();
    };

    var total_score: u32 = 0;
    for (cards) |card| {
        total_score += card.tabulate();
    }

    std.debug.print("Total score: {}\n", .{total_score});
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
            }

            if (letters_read == 0) {
                break;
            }
        } else {
            try card_list.append(buf[0]);
        }
    }

    return try cards.toOwnedSlice();
}
