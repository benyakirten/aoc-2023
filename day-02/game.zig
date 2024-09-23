const std = @import("std");

const Match = @import("match.zig").Match;

const GAME_INITIAL_WORD: []const u8 = "Game "[0..];

const GameError = error{
    ParseError,
};

pub const Game = struct {
    id: u8,
    matches: []Match,
    allocator: std.mem.Allocator,

    pub fn allGamesFromFile(file: std.fs.File, allocator: std.mem.Allocator) ![]Game {
        var games = std.ArrayList(Game).init(allocator);
        defer games.deinit();

        const buf = try allocator.alloc(u8, 1);
        defer allocator.free(buf);

        var potential_game = std.ArrayList(u8).init(allocator);
        defer potential_game.deinit();

        while (true) {
            const letters_read = try file.read(buf);

            if (letters_read == 0 or buf[0] == '\n') {
                const game = try Game.parseSingleGame(try potential_game.toOwnedSlice(), allocator);
                try games.append(game);
                potential_game.clearAndFree();

                if (letters_read == 0) {
                    break;
                }
            } else {
                try potential_game.append(buf[0]);
            }
        }

        return try games.toOwnedSlice();
    }

    fn parseSingleGame(data: []const u8, allocator: std.mem.Allocator) !Game {
        var matches = std.ArrayList(Match).init(allocator);
        defer matches.deinit();

        if (!std.mem.eql(u8, data[0..GAME_INITIAL_WORD.len], GAME_INITIAL_WORD)) {
            return GameError.ParseError;
        }

        var index: u8 = GAME_INITIAL_WORD.len;
        var id: u8 = 0;

        while (true) {
            const letter = data[index];
            index += 1;

            if (letter == ':') {
                break;
            }

            if (letter < '0' or letter > '9') {
                return GameError.ParseError;
            }

            id += id * 9 + (letter - '0');
        }

        var starting_index: usize = 0;
        var collecting_match = false;

        const raw_matches = data[index..];
        for (raw_matches, 0..) |letter, i| {
            if (letter == ';' or i == raw_matches.len - 1) {
                var pos = i;
                if (pos == raw_matches.len - 1) {
                    pos += 1;
                }

                const match = try Match.parseFromString(raw_matches[starting_index..pos]);
                try matches.append(match);

                collecting_match = false;
            } else if (!collecting_match) {
                collecting_match = true;
                starting_index = i;
            }
        }

        return Game{ .id = id, .matches = try matches.toOwnedSlice(), .allocator = allocator };
    }

    pub fn areMatchesValid(self: Game, control: Match) bool {
        for (self.matches) |match| {
            if (!match.isValid(control)) {
                return false;
            }
        }

        return true;
    }

    pub fn getMinimumViableCubes(self: Game) Match {
        var red: u8 = 0;
        var blue: u8 = 0;
        var green: u8 = 0;

        for (self.matches) |match| {
            if (match.red > red) {
                red = match.red;
            }

            if (match.green > green) {
                green = match.green;
            }

            if (match.blue > blue) {
                blue = match.blue;
            }
        }

        return Match{ .red = red, .green = green, .blue = blue };
    }

    pub fn deinitAll(games: []Game) void {
        for (games) |game| {
            game.deinit();
        }
    }

    pub fn deinit(self: Game) void {
        self.allocator.free(self.matches);
    }

    pub fn print(self: Game) void {
        std.debug.print("ID: {}\n", .{self.id});
        for (self.matches) |match| {
            match.print();
        }
    }
};

test "getMinimumViableCubes" {
    var game_matches = std.ArrayList(Match).init(std.testing.allocator);
    defer game_matches.deinit();

    const game_match_1 = Match{ .red = 5, .green = 0, .blue = 15 };
    try game_matches.append(game_match_1);

    const game_match_2 = Match{ .red = 11, .green = 0, .blue = 5 };
    try game_matches.append(game_match_2);

    const game = Game{ .id = 1, .allocator = std.testing.allocator, .matches = try game_matches.toOwnedSlice() };
    defer game.deinit();

    const got = game.getMinimumViableCubes();
    const want = Match{ .red = 11, .green = 0, .blue = 15 };
    try std.testing.expectEqual(want, got);
}

test "areMatchesValid true" {
    const control = Match{
        .red = 10,
        .green = 30,
        .blue = 20,
    };

    var game_matches = std.ArrayList(Match).init(std.testing.allocator);
    defer game_matches.deinit();

    const game_match_1 = Match{ .red = 5, .green = 30, .blue = 20 };
    try game_matches.append(game_match_1);

    const game_match_2 = Match{ .red = 10, .green = 20, .blue = 20 };
    try game_matches.append(game_match_2);

    const game = Game{ .id = 1, .allocator = std.testing.allocator, .matches = try game_matches.toOwnedSlice() };
    defer game.deinit();

    const isValid = game.areMatchesValid(control);
    try std.testing.expect(isValid);
}

test "areMatchesValid false" {
    const control = Match{
        .red = 10,
        .green = 30,
        .blue = 20,
    };

    var game_matches = std.ArrayList(Match).init(std.testing.allocator);
    defer game_matches.deinit();

    const game_match_1 = Match{ .red = 5, .green = 5, .blue = 5 };
    try game_matches.append(game_match_1);

    const game_match_2 = Match{ .red = 5, .green = 5, .blue = 200 };
    try game_matches.append(game_match_2);

    const game = Game{ .id = 1, .allocator = std.testing.allocator, .matches = try game_matches.toOwnedSlice() };
    defer game.deinit();

    const isValid = game.areMatchesValid(control);
    try std.testing.expect(!isValid);
}
