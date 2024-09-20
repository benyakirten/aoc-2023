const std = @import("std");

const Sequence = @import("sequence.zig").Sequence;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const sequences = try readSequences(inputs, allocator);
    defer allocator.free(sequences);

    var next_total: isize = 0;
    var previous_total: isize = 0;

    for (sequences) |sequence| {
        next_total += try sequence.getNext();
        previous_total += try sequence.getPrevious();
        sequence.deinit();
    }

    std.debug.print("Total for the next item: {}\n", .{next_total});
    std.debug.print("Total for the previous item: {}\n", .{previous_total});
}

fn readSequences(file: std.fs.File, allocator: std.mem.Allocator) ![]Sequence {
    var sequence_list = std.ArrayList(Sequence).init(allocator);
    defer sequence_list.deinit();

    var raw_sequence = std.ArrayList(u8).init(allocator);
    defer raw_sequence.deinit();

    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    while (true) {
        const letters_read = try file.read(buf);

        if (letters_read == 0 or buf[0] == '\n') {
            const data = try raw_sequence.toOwnedSlice();
            raw_sequence.clearAndFree();

            const seq = try processSequence(data, allocator);
            const sequence = Sequence{ .allocator = allocator, .data = seq };
            try sequence_list.append(sequence);

            if (letters_read == 0) {
                break;
            }
        } else {
            try raw_sequence.append(buf[0]);
        }
    }

    return try sequence_list.toOwnedSlice();
}

fn processSequence(data: []u8, allocator: std.mem.Allocator) ![]isize {
    var items = std.ArrayList(isize).init(allocator);
    defer items.deinit();

    var item: isize = 0;
    var is_negative: bool = false;
    for (data, 0..) |datum, i| {
        if (datum == ' ' or i == data.len - 1) {
            if (i == data.len - 1) {
                item = item * 10 + datum - '0';
            }

            if (is_negative) {
                item *= -1;
            }

            try items.append(item);
            item = 0;
            is_negative = false;
        } else if (datum == '-') {
            is_negative = true;
        } else {
            item = item * 10 + datum - '0';
        }
    }

    return try items.toOwnedSlice();
}
