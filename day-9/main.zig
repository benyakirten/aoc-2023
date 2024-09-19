const std = @import("std");

const Sequence = @import("sequence.zig").Sequence;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    _ = try readSequences(inputs, allocator);
}

fn readSequences(file: std.fs.File, allocator: std.mem.Allocator) ![]Sequence {
    var sequence_list = std.ArrayList([]usize).init(allocator);
    defer sequence_list.deinit();

    var sequence = std.ArrayList(u8).init(allocator);
    defer sequence.deinit();

    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    while (true) {
        const letters_read = try file.read(buf);

        if (letters_read == 0 or buf[0] == '\n') {
            const data = try sequence.toOwnedSlice();
            const seq = processSequence(data, allocator);

            try sequence_list.append(seq);
            sequence.clearAndFree();

            if (letters_read == 0) {
                break;
            }
        } else {
            try sequence.append(buf[0]);
        }
    }

    const seq_data = try sequence_list.toOwnedSlice();
    var sequences = try allocator.alloc(Sequence, seq_data.len);

    for (seq_data) |datum| {
        const data = try allocator.alloc([]usize, 1);
        data[0] = datum;
        const seq = Sequence{
            .allocator = allocator,
            .data = data,
        };
        sequences[0] = seq;
    }

    return sequences;
}

fn processSequence(data: []u8, allocator: std.mem.Allocator) []usize {
    const items = std.ArrayList(usize).init(allocator);
    defer items.deinit();

    var item: usize = 0;
    for (data, 0..) |datum, i| {
        if (i == data.len - 1 or datum == ' ') {
            try items.append(item);
            item = 0;
        } else {
            item = item * 10 + datum - '0';
        }
    }

    return try items.toOwnedSlice();
}
