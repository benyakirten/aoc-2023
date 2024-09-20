const std = @import("std");

const Sequence = @import("sequence.zig").Sequence;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const sequences = try readSequences(inputs, allocator);
    var total: isize = 0;

    for (sequences) |sequence| {
        total += try sequence.getNext();
    }

    std.debug.print("Total: {}\n", .{total});
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
    for (data, 0..) |datum, i| {
        if (i == data.len - 1 or datum == ' ') {
            try items.append(item);
            item = 0;
        } else if (datum == '-') {
            item *= -1;
        } else {
            item = item * 10 + datum - '0';
        }
    }

    return try items.toOwnedSlice();
}
