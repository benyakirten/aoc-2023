const std = @import("std");

pub const LineRead = struct { done: bool, data: []u8 };

pub fn readLine(file: std.fs.File, allocator: std.mem.Allocator) !LineRead {
    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();

    var done: bool = false;

    while (true) {
        const characters_read = try file.read(buf);
        if (characters_read == 0 or buf[0] == '\n') {
            if (characters_read == 0) {
                done = true;
            }
            break;
        } else {
            try line.append(buf[0]);
        }
    }

    const data = try line.toOwnedSlice();
    return LineRead{ .done = done, .data = data };
}
