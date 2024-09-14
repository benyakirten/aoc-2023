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

    const buf = try allocator.alloc(u8, 1);

    var sum: u16 = 0;
    var first: u16 = 0;
    var last: u16 = 0;
    var letters_read = try inputs.read(buf);

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
            const starting_position = try inputs.getPos();
            if (try readPossibleWord(letter, inputs, allocator)) |val| {
                letter = val + '0';
            }
            try inputs.seekTo(starting_position);
        }

        if (letter >= '0' and letter <= '9') {
            if (first == 0) {
                first = letter - '0';
            }

            last = letter - '0';
        }

        letters_read = try inputs.read(buf);
    }

    std.debug.print("Total: {}\n", .{sum});
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
