const std = @import("std");

const GAME_INITIAL_WORD: []const u8 = "Game "[0..];

const GameError = error{
    ParseError,
};
const Match = struct {
    red: u8,
    blue: u8,
    green: u8,

    fn parseFromString(data: []const u8) !Match {
        var red: u8 = 0;
        var green: u8 = 0;
        var blue: u8 = 0;

        var num: u8 = 0;
        var name_starting_index: u8 = 0;
        var gathering_name: bool = false;

        for (data, 0..) |letter, i| {
            if (gathering_name and (letter == ',' or i == data.len - 1)) {
                var pos: usize = i;
                if (pos == data.len - 1) {
                    pos = pos + 1;
                }

                gathering_name = false;

                const name = data[name_starting_index..pos];
                if (std.mem.eql(u8, name, "red"[0..])) {
                    red = num;
                } else if (std.mem.eql(u8, name, "green"[0..])) {
                    green = num;
                } else if (std.mem.eql(u8, name, "blue"[0..])) {
                    blue = num;
                }

                num = 0;
            }

            if (letter >= 'a' and letter <= 'z') {
                if (!gathering_name) {
                    name_starting_index = @truncate(i);
                    gathering_name = true;
                }

                continue;
            }

            if (letter >= '0' and letter <= '9') {
                num = num * 10 + letter - '0';
            }
        }

        return Match{ .red = red, .green = green, .blue = blue };
    }

    fn isValid(self: Match, control: Match) bool {
        return self.blue <= control.blue and
            self.red <= control.red and
            self.green <= control.green;
    }

    fn print(self: Match) void {
        std.debug.print("Match values: red {}, green {}, blue {}\n", .{ self.red, self.green, self.blue });
    }
};

const Game = struct {
    id: u8,
    matches: []Match,
    allocator: std.mem.Allocator,

    fn allGamesFromFile(file: std.fs.File, allocator: std.mem.Allocator) ![]Game {
        var games = std.ArrayList(Game).init(allocator);
        defer games.deinit();

        const buf = try allocator.alloc(u8, 1);
        defer allocator.free(buf);

        var potential_game = std.ArrayList(u8).init(allocator);
        defer potential_game.deinit();

        while (true) {
            const letters_read = try file.read(buf);

            if (letters_read == 0 or buf[0] == '\n') {
                const game = try Game.singleGameFromFile(try potential_game.toOwnedSlice(), allocator);
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

    fn singleGameFromFile(data: []const u8, allocator: std.mem.Allocator) !Game {
        var matches = std.ArrayList(Match).init(allocator);
        defer matches.deinit();

        var id: u8 = 0;

        var potential_match = std.ArrayList(u8).init(allocator);
        defer potential_match.deinit();

        if (!std.mem.eql(u8, data[0..GAME_INITIAL_WORD.len], GAME_INITIAL_WORD)) {
            return GameError.ParseError;
        }

        var index: u8 = GAME_INITIAL_WORD.len;

        while (true) {
            const letter = data[index];
            index += 1;

            if (letter == ':') {
                break;
            }

            if (letter < '0' or letter > '9') {
                return GameError.ParseError;
            }

            id += letter - '0';
        }

        const raw_matches = data[index..];
        for (raw_matches, 0..) |letter, i| {
            if (letter == ';' or i == raw_matches.len - 1) {
                if (i == raw_matches.len - 1) {
                    try potential_match.append(letter);
                }

                const match = try Match.parseFromString(try potential_match.toOwnedSlice());
                try matches.append(match);
                potential_match.clearAndFree();
            } else {
                try potential_match.append(letter);
            }
        }

        return Game{ .id = id, .matches = try matches.toOwnedSlice(), .allocator = allocator };
    }

    fn areMatchesValid(self: Game, control: Match) bool {
        for (self.matches) |match| {
            if (!match.isValid(control)) {
                return false;
            }
        }

        return true;
    }

    fn deinitAll(games: []Game) void {
        for (games) |game| {
            game.deinit();
        }
    }

    fn deinit(self: Game) void {
        self.allocator.free(self.matches);
    }

    fn print(self: Game) void {
        std.debug.print("ID: {}\n", .{self.id});
        for (self.matches) |match| {
            match.print();
        }

        std.debug.print("\n", .{});
    }
};

const VALID_MATCH = Match{ .blue = 14, .red = 12, .green = 13 };

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });

    const games = try Game.allGamesFromFile(inputs, allocator);
    defer Game.deinitAll(games);

    const sum = sumValidGameIds(VALID_MATCH, games);

    std.debug.print("Total: {}\n", .{sum});
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
