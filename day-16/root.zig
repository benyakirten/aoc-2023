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

pub const Coordinate = struct { x: usize, y: usize };
pub const LightDirection = enum { Up, Down, Left, Right };

pub const LightRay = struct {
    direction: LightDirection,
    coord: Coordinate,

    fn new(direction: LightDirection, x: usize, y: usize) LightRay {
        const coord = Coordinate{ .x = x, .y = y };
        return LightRay{ .direction = direction, .coord = coord };
    }

    fn advance(self: LightRay, allocator: std.mem.Allocator, area: [][]Tile, cache: *std.AutoArrayHashMap(Contraption.CacheKey, bool)) ![]LightRay {
        var light_ray_list = try std.ArrayList(LightRay).initCapacity(allocator, 2);
        defer light_ray_list.deinit();

        var delta_y: i8 = 0;
        if (self.direction == .Down) {
            delta_y = 1;
        } else if (self.direction == .Up) {
            delta_y = -1;
        }

        var delta_x: i8 = 0;
        if (self.direction == .Right) {
            delta_x = 1;
        } else if (self.direction == .Left) {
            delta_x = -1;
        }

        const deltafied_y: isize = @as(isize, @intCast(self.coord.y)) + delta_y;
        const deltafied_x: isize = @as(isize, @intCast(self.coord.x)) + delta_x;

        if (deltafied_y < 0 or deltafied_y > area.len - 1 or deltafied_x < 0 or deltafied_x > area[0].len - 1) {
            return try light_ray_list.toOwnedSlice();
        }

        const final_y = @as(usize, @intCast(deltafied_y));
        const final_x = @as(usize, @intCast(deltafied_x));

        const next_tile = area[final_y][final_x];
        const next_coord = Coordinate{ .x = @as(usize, @intCast(final_x)), .y = @as(usize, @intCast(final_y)) };
        const directions = try Contraption.determineNextDirection(allocator, next_tile, self.direction);

        for (directions) |dir| {
            const cache_key = Contraption.CacheKey{ .coord = next_coord, .direction = dir };
            if (cache.get(cache_key)) |_| {
                continue;
            }

            try light_ray_list.append(LightRay.new(dir, final_x, final_y));
        }

        return try light_ray_list.toOwnedSlice();
    }
};

pub const Contraption = struct {
    area: [][]Tile,
    lit_areas: std.AutoArrayHashMap(CacheKey, bool),
    rays: []LightRay,
    allocator: std.mem.Allocator,

    const CacheKey = struct {
        coord: Coordinate,
        direction: LightDirection,
    };

    pub fn deinit(self: *Contraption) void {
        for (self.area) |line| {
            self.allocator.free(line);
        }
        self.allocator.free(self.area);
        self.allocator.free(self.rays);
        self.lit_areas.deinit();
    }

    fn parseArea(allocator: std.mem.Allocator, data: []const u8) ![][]Tile {
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

        return try lines_list.toOwnedSlice();
    }

    pub fn parse(allocator: std.mem.Allocator, data: []const u8) !Contraption {
        const area = try parseArea(allocator, data);

        const starting_tile = area[0][0];

        const directions = try determineNextDirection(allocator, starting_tile, .Right);
        defer allocator.free(directions);

        var rays = try std.ArrayList(LightRay).initCapacity(allocator, 2);
        defer rays.deinit();

        for (directions) |dir| {
            try rays.append(LightRay.new(dir, 0, 0));
        }

        const lit_areas = std.AutoArrayHashMap(CacheKey, bool).init(allocator);

        return Contraption{ .area = area, .rays = try rays.toOwnedSlice(), .lit_areas = lit_areas, .allocator = allocator };
    }

    // pub fn parseToPermutations(allocator: std.mem.Allocator, data: []const u8) ![]Contraption {
    //     var contraptions = std.ArrayList(Contraption).init(allocator);
    //     defer contraptions.deinit();

    //     const area = try parseArea(allocator, data);

    //     for (area, 0..) |line, i| {
    //         for (line, 0..) |tile, j| {
    //             if (i == 0 and j == 0) {
    //                 //
    //             } else if (i == 0 and j == line.len - 1) {
    //                 //
    //             } else if (i == area.len - 1 and j == 0) {
    //                 //
    //             } else if (i == area.len - 1 and j == line.len - 1) {
    //                 //
    //             } else {
    //                 //
    //             }
    //         }
    //     }

    //     return try contraptions.toOwnedSlice();
    // }

    fn determineNextDirection(allocator: std.mem.Allocator, tile: Tile, direction: LightDirection) ![]LightDirection {
        var directions = try std.ArrayList(LightDirection).initCapacity(allocator, 2);
        defer directions.deinit();

        switch (direction) {
            .Right => {
                switch (tile) {
                    .VerticalSplitter => {
                        try directions.append(.Up);
                        try directions.append(.Down);
                    },
                    .RightMirror => {
                        try directions.append(.Down);
                    },
                    .LeftMirror => {
                        try directions.append(.Up);
                    },
                    else => {
                        try directions.append(.Right);
                    },
                }
            },
            .Left => {
                switch (tile) {
                    .VerticalSplitter => {
                        try directions.append(.Up);
                        try directions.append(.Down);
                    },
                    .RightMirror => {
                        try directions.append(.Up);
                    },
                    .LeftMirror => {
                        try directions.append(.Down);
                    },
                    else => {
                        try directions.append(.Left);
                    },
                }
            },
            .Up => {
                switch (tile) {
                    .HorizontalSplitter => {
                        try directions.append(.Left);
                        try directions.append(.Right);
                    },
                    .RightMirror => {
                        try directions.append(.Left);
                    },
                    .LeftMirror => {
                        try directions.append(.Right);
                    },
                    else => {
                        try directions.append(.Up);
                    },
                }
            },
            .Down => {
                switch (tile) {
                    .HorizontalSplitter => {
                        try directions.append(.Left);
                        try directions.append(.Right);
                    },
                    .RightMirror => {
                        try directions.append(.Right);
                    },
                    .LeftMirror => {
                        try directions.append(.Left);
                    },
                    else => {
                        try directions.append(.Down);
                    },
                }
            },
        }

        return try directions.toOwnedSlice();
    }

    pub fn run(self: *Contraption) !void {
        while (try self.tick()) {}
    }

    fn tick(self: *Contraption) !bool {
        var new_rays = std.ArrayList(LightRay).init(self.allocator);
        defer new_rays.deinit();

        for (self.rays) |ray| {
            const cache_key = CacheKey{ .coord = ray.coord, .direction = ray.direction };
            if (self.lit_areas.get(cache_key)) |_| {
                continue;
            }

            try self.lit_areas.put(cache_key, true);
            const addl_rays = try ray.advance(self.allocator, self.area, &self.lit_areas);
            try new_rays.appendSlice(addl_rays);
        }

        const rays = try new_rays.toOwnedSlice();

        self.allocator.free(self.rays);
        self.rays = rays;

        return self.rays.len > 0;
    }

    pub fn count_lit_areas(self: Contraption) !usize {
        var map = std.AutoArrayHashMap(Coordinate, bool).init(self.allocator);
        defer map.deinit();

        for (self.lit_areas.keys()) |key| {
            try map.put(key.coord, true);
        }

        return map.keys().len;
    }
};
