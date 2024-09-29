const std = @import("std");

const Coordinate = struct {
    x: usize,
    y: usize,
};

pub const Map = struct {
    position: Coordinate,
    area: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Map) void {
        self.allocator.free(self.area);
    }

    pub fn parse(allocator: std.mem.Allocator, content: []const u8) !Map {
        var lines = std.mem.splitSequence(u8, content, "\n");

        var area_list = std.ArrayList([]const u8).init(allocator);
        defer area_list.deinit();

        while (lines.next()) |line| {
            try area_list.append(line);
        }

        const start_position = Coordinate{ .x = 0, .y = 0 };

        return Map{
            .position = start_position,
            .area = try area_list.toOwnedSlice(),
            .allocator = allocator,
        };
    }
};
