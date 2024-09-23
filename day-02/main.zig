const std = @import("std");

const Match = @import("match.zig").Match;
const Game = @import("game.zig").Game;

const VALID_MATCH = Match{
    .red = 12,
    .green = 13,
    .blue = 14,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_inputs.txt", .{ .mode = .read_only });
    defer inputs.close();

    const games = try Game.allGamesFromFile(inputs, allocator);
    defer Game.deinitAll(games);

    const total_valid_game_ids = sumValidGameIds(VALID_MATCH, games);
    std.debug.print("Total Valid IDs: {}\n", .{total_valid_game_ids});

    const total_game_power = sumGamePower(games);
    std.debug.print("Total power of games: {}\n", .{total_game_power});
}

fn sumGamePower(games: []Game) u32 {
    var sum: u32 = 0;
    for (games) |game| {
        const min = game.getMinimumViableCubes();
        sum += min.power();
    }

    return sum;
}

test "sumGamePower" {
    var game_1_matches = std.ArrayList(Match).init(std.testing.allocator);
    defer game_1_matches.deinit();

    const game_1_match_1 = Match{ .red = 5, .green = 0, .blue = 15 };
    try game_1_matches.append(game_1_match_1);

    const game_1_match_2 = Match{ .red = 11, .green = 0, .blue = 5 };
    try game_1_matches.append(game_1_match_2);

    const game_1 = Game{ .id = 1, .allocator = std.testing.allocator, .matches = try game_1_matches.toOwnedSlice() };
    defer game_1.deinit();

    var game_2_matches = std.ArrayList(Match).init(std.testing.allocator);
    defer game_2_matches.deinit();

    const game_2_match_1 = Match{ .red = 0, .green = 0, .blue = 0 };
    try game_2_matches.append(game_2_match_1);

    const game_2_match_2 = Match{ .red = 0, .green = 0, .blue = 0 };
    try game_2_matches.append(game_2_match_2);

    const game_2 = Game{ .id = 2, .allocator = std.testing.allocator, .matches = try game_2_matches.toOwnedSlice() };
    defer game_2.deinit();

    var games = std.ArrayList(Game).init(std.testing.allocator);
    defer games.deinit();

    try games.append(game_1);
    try games.append(game_2);

    const games_slice = try games.toOwnedSlice();
    defer std.testing.allocator.free(games_slice);

    const got = sumGamePower(games_slice);
    // In game 1, greens don't count, so the power should be red * blue
    // and in game 2, nothing counts so the power should be 0
    const want: u32 = 11 * 15;
    try std.testing.expectEqual(want, got);
}

fn sumValidGameIds(control: Match, games: []Game) u16 {
    var sum: u16 = 0;
    for (games) |game| {
        if (game.areMatchesValid(control)) {
            sum += game.id;
        }
    }

    return sum;
}

test "sumValidGameIds" {
    const control = Match{
        .red = 10,
        .blue = 20,
        .green = 30,
    };

    var game_1_matches = std.ArrayList(Match).init(std.testing.allocator);
    defer game_1_matches.deinit();

    const game_1_match_1 = Match{ .red = 5, .green = 2, .blue = 5 };
    try game_1_matches.append(game_1_match_1);

    const game_1_match_2 = Match{ .red = 11, .green = 2, .blue = 5 };
    try game_1_matches.append(game_1_match_2);

    const game_1 = Game{ .id = 1, .allocator = std.testing.allocator, .matches = try game_1_matches.toOwnedSlice() };
    defer game_1.deinit();

    var game_2_matches = std.ArrayList(Match).init(std.testing.allocator);
    defer game_2_matches.deinit();

    const game_2_match_1 = Match{ .red = 5, .green = 2, .blue = 5 };
    try game_2_matches.append(game_2_match_1);

    const game_2_match_2 = Match{ .red = 1, .green = 2, .blue = 5 };
    try game_2_matches.append(game_2_match_2);

    const game_2 = Game{ .id = 2, .allocator = std.testing.allocator, .matches = try game_2_matches.toOwnedSlice() };
    defer game_2.deinit();

    var games = std.ArrayList(Game).init(std.testing.allocator);
    defer games.deinit();

    try games.append(game_1);
    try games.append(game_2);

    const games_slice = try games.toOwnedSlice();
    defer std.testing.allocator.free(games_slice);

    const got = sumValidGameIds(control, games_slice);
    try std.testing.expectEqual(2, got);
}
