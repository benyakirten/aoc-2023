const std = @import("std");

pub const TileError = error{Unrecognizedtile};
pub const Tile = enum(u8) {
    Empty = '.',
    LeftMirror = '/',
    RightMirror = '\\',
    VerticalSplitter = '|',
    HorizontalSplitter = '-',

    fn fromChar(c: u8) !Tile {
        switch (c) {
            '.' => return .Empty,
            '/' => return .LeftMirror,
            '\\' => return .RightMirror,
            '|' => return .VerticalSplitter,
            '-' => return .HorizontalSplitter,
            else => return TileError.Unrecognizedtile,
        }
    }
};

pub const Contraption = struct {
    area: [][]Tile,
    allocator: std.mem.Allocator,

    pub fn parse(allocator: std.mem.Allocator, data: []const u8) !Contraption {
        var lines_list = std.ArrayList([]Tile).init(allocator);
        defer lines_list.deinit();

        var line_list = std.ArrayList(Tile).init(allocator);
        defer line_list.deinit();

        for (data, 0..) |ch, i| {
            if (ch == '\n' or i == data.len - 1) {
                if (i == data.len - 1) {
                    const tile = try Tile.fromChar(ch);
                    try line_list.append(tile);
                }

                const line = try line_list.toOwnedSlice();
                try lines_list.append(line);
                line_list.clearAndFree();
            } else {
                const tile = try Tile.fromChar(ch);
                try line_list.append(tile);
            }
        }

        const area = try lines_list.toOwnedSlice();
        return Contraption{ .area = area, .allocator = allocator };
    }
};
