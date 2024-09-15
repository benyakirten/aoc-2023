const std = @import("std");

const WordValue = struct {
    word: []const u8,
    value: u8,

    fn new(word: []const u8, value: u8) WordValue {
        return WordValue{ .word = word, .value = value };
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const cwd = std.fs.cwd();
    const inputs = try cwd.openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const sum = try sumNumbers(inputs, allocator);
    std.debug.print("Total: {}\n", .{sum});
}

fn sumNumbers(file: std.fs.File, allocator: std.mem.Allocator) !u32 {
    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    var sum: u32 = 0;
    var first: u16 = 0;
    var last: u16 = 0;
    var letters_read = try file.read(buf);

    while (true) {
        var letter = buf[0];

        if (letter == '\n' or letters_read == 0) {
            sum += (first * 10) + last;
            first = 0;
            last = 0;

            if (letters_read == 0) {
                break;
            }
        }

        if ((letter >= 'a' and letter <= 'z')) {
            if (try readPossibleWord(letter, file, allocator)) |val| {
                letter = val + '0';
            }
        }

        if (letter >= '0' and letter <= '9') {
            if (first == 0) {
                first = letter - '0';
            }

            last = letter - '0';
        }

        letters_read = try file.read(buf);
    }

    return sum;
}

const TWords = [2]WordValue{
    WordValue.new("two"[0..], 2),
    WordValue.new("three"[0..], 3),
};

const FWords = [2]WordValue{
    WordValue.new("four"[0..], 4),
    WordValue.new("five"[0..], 5),
};

const SWords = [2]WordValue{
    WordValue.new("six"[0..], 6),
    WordValue.new("seven"[0..], 7),
};

fn readPossibleWord(first_letter: u8, file: std.fs.File, allocator: std.mem.Allocator) !?u8 {
    const starting_position = try file.getPos();
    defer file.seekTo(starting_position) catch {};

    switch (first_letter) {
        'o' => return convertPossibleWordToInt(file, "one"[0..], 1, allocator),
        't' => return findPossibleWordValueAmongMany(file, TWords, allocator),
        'f' => return findPossibleWordValueAmongMany(file, FWords, allocator),
        's' => return findPossibleWordValueAmongMany(file, SWords, allocator),
        'e' => return convertPossibleWordToInt(file, "eight"[0..], 8, allocator),
        'n' => return convertPossibleWordToInt(file, "nine"[0..], 9, allocator),
        else => {
            return null;
        },
    }
}

fn findPossibleWordValueAmongMany(file: std.fs.File, word_values: [2]WordValue, allocator: std.mem.Allocator) !?u8 {
    const pos = try file.getPos();
    for (word_values) |word_value| {
        if (try convertPossibleWordToInt(file, word_value.word, word_value.value, allocator)) |val| {
            return val;
        }
        try file.seekTo(pos);
    }

    return null;
}

fn convertPossibleWordToInt(file: std.fs.File, word: []const u8, value: u8, allocator: std.mem.Allocator) !?u8 {
    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    for (word[1..]) |letter| {
        const letters_read = try file.read(buf);
        if (letters_read == 0) {
            return null;
        }

        if (buf[0] != letter) {
            return null;
        }
    }
    return value;
}

test "sumNumbers" {
    const file = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer file.close();

    const got = try sumNumbers(file, std.testing.allocator);
    try std.testing.expectEqual(281, got);
    try std.testing.expectEqual(try file.getPos(), try file.getEndPos());
}

test "readPossibleWord success" {
    const file = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer file.close();

    try file.seekTo(10);

    const got = readPossibleWord('e', file, std.testing.allocator);
    try std.testing.expectEqual(8, got);
    try std.testing.expectEqual(10, try file.getPos());
}

test "readPossibleWord failure" {
    const file = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer file.close();

    try file.seekTo(9);

    const got = readPossibleWord('e', file, std.testing.allocator);
    try std.testing.expectEqual(null, got);
    try std.testing.expectEqual(9, try file.getPos());
}

test "findPossibleWordValueAmongMany success on first attempt" {
    const file = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer file.close();

    try file.seekTo(14);

    const got = try findPossibleWordValueAmongMany(file, TWords, std.testing.allocator);
    try std.testing.expectEqual(2, got);
    try std.testing.expectEqual(16, try file.getPos());
}

test "findPossibleWordValueAmongMany success on second attempt" {
    const file = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer file.close();

    try file.seekTo(17);

    const got = try findPossibleWordValueAmongMany(file, TWords, std.testing.allocator);
    try std.testing.expectEqual(3, got);
    try std.testing.expectEqual(21, try file.getPos());
}

test "findPossibleWordValueAmongMany failure" {
    const file = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer file.close();

    const got = try findPossibleWordValueAmongMany(file, TWords, std.testing.allocator);
    try std.testing.expectEqual(null, got);
    try std.testing.expectEqual(0, try file.getPos());
}

test "convertPossibleWordToInt success" {
    const file = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer file.close();

    try file.seekTo(1);

    const got = try convertPossibleWordToInt(file, "two", 2, std.testing.allocator);
    try std.testing.expectEqual(2, got);
    try std.testing.expectEqual(3, try file.getPos());
}

test "convertPossibleWordtoInt failure" {
    const file = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer file.close();

    const got = try convertPossibleWordToInt(file, "two", 2, std.testing.allocator);
    try std.testing.expectEqual(null, got);
    try std.testing.expectEqual(1, try file.getPos());
}
