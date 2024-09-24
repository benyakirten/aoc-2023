const std = @import("std");

pub const Position = struct { y: u8, x: u8 };

pub const LandTypeError = error{UnrecognizedLandType};
pub const LandType = enum(u8) {
    Rocks = '#',
    Ash = '.',

    fn fromChar(char: u8) !LandType {
        return switch (char) {
            '#' => .Rocks,
            '.' => .Ash,
            else => LandTypeError.UnrecognizedLandType,
        };
    }
};

pub const Landscape = struct {
    land: [][]LandType,
    allocator: std.mem.Allocator,

    pub fn parse(data: []u8, allocator: std.mem.Allocator) ![]Landscape {
        var landscape_list = std.ArrayList(Landscape).init(allocator);
        defer landscape_list.deinit();

        var lines_list = std.ArrayList([]LandType).init(allocator);
        defer lines_list.deinit();

        var line_list = std.ArrayList(LandType).init(allocator);
        defer line_list.deinit();

        var saw_line_break: bool = false;
        for (data, 0..) |letter, i| {
            if (saw_line_break and (letter == '\n' or i == data.len - 1)) {
                if (i == data.len - 1) {
                    const line = try line_list.toOwnedSlice();
                    try lines_list.append(line);
                }
                const land = try lines_list.toOwnedSlice();
                const landscape = Landscape{ .land = land, .allocator = allocator };
                try landscape_list.append(landscape);

                saw_line_break = false;
                continue;
            }

            if (!saw_line_break and letter == '\n') {
                saw_line_break = true;
                const line = try line_list.toOwnedSlice();
                try lines_list.append(line);
            } else {
                saw_line_break = false;
                const lt = try LandType.fromChar(letter);
                try line_list.append(lt);
            }
        }

        return try landscape_list.toOwnedSlice();
    }

    pub fn print(self: Landscape) void {
        for (self.land) |line| {
            for (line) |lt| {
                std.debug.print("{c}", .{@intFromEnum(lt)});
            }
            std.debug.print("\n", .{});
        }
    }
};
