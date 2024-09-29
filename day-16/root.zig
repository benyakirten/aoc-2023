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

    fn advance(self: LightRay, allocator: std.mem.Allocator, area: [][]Tile) ![]LightRay {
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

        const final_y: i16 = @as(i16, self.coord.y) + delta_y;
        const final_x: i16 = @as(i16, self.coord.x) + delta_x;

        if (final_y < 0 or final_y > area.len - 1 or final_x < 0 or final_x > area[0].len - 1) {
            return try light_ray_list.toOwnedSlice();
        }

        const next_tile = area[final_y][final_x];
        const next_coord = Coordinate{ .x = @as(usize, @intCast(final_x)), .y = @as(usize, @intCast(final_y)) };
        switch (next_tile) {
            .Empty => {
                const next_ray = LightRay.new(self.direction, next_coord.x, next_coord.y);
                try light_ray_list.append(next_ray);
            },
            .LeftMirror => {
                const next_direction = switch (self.direction) {
                    .Up => .Right,
                    .Down => .Left,
                    .Left => .Up,
                    .Right => .Down,
                };

                const next_ray = LightRay.new(next_direction, next_coord.x, next_coord.y);
                try light_ray_list.append(next_ray);
            },
            .RightMirror => {
                const next_direction = switch (self.direction) {
                    .Up => .Left,
                    .Down => .Right,
                    .Left => .Down,
                    .Right => .Up,
                };

                const next_ray = LightRay.new(next_direction, next_coord.x, next_coord.y);
                try light_ray_list.append(next_ray);
            },
            .VerticalSplitter => {
                if (self.direction == .Up or self.direction == .Down) {
                    const next_ray = LightRay.new(self.direction, next_coord.x, next_coord.y);
                    try light_ray_list.append(next_ray);
                } else {
                    const next_ray1 = LightRay.new(.Up, next_coord.x, next_coord.y);
                    try light_ray_list.append(next_ray1);

                    const next_ray2 = LightRay.new(.Down, next_coord.x, next_coord.y);
                    try light_ray_list.append(next_ray2);
                }
            },
            .HorizontalSplitter => {
                if (self.direction == .Left or self.direction == .Right) {
                    const next_ray = LightRay.new(self.direction, next_coord.x, next_coord.y);
                    try light_ray_list.append(next_ray);
                } else {
                    const next_ray1 = LightRay.new(.Left, next_coord.x, next_coord.y);
                    try light_ray_list.append(next_ray1);

                    const next_ray2 = LightRay.new(.Right, next_coord.x, next_coord.y);
                    try light_ray_list.append(next_ray2);
                }
            },
        }

        return try light_ray_list.toOwnedSlice();
    }
};

pub const Contraption = struct {
    area: [][]Tile,
    lit_areas: std.AutoArrayHashMap(Coordinate, bool),
    rays: []LightRay,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Contraption) void {
        for (self.area) |line| {
            self.allocator.free(line);
        }
        self.allocator.free(self.area);
        self.allocator.free(self.rays);
        self.lit_areas.deinit();
    }

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

        const starting_light_ray = LightRay.new(LightDirection.Right, 0, 0);
        var rays = .{starting_light_ray};

        const lit_areas = std.AutoArrayHashMap(Coordinate, bool).init(allocator);

        return Contraption{ .area = area, .rays = rays[0..], .lit_areas = lit_areas, .allocator = allocator };
    }

    pub fn run(self: *Contraption) !void {
        while (self.tick()) {}
    }

    fn tick(self: *Contraption) !bool {
        var new_rays = std.ArrayList(LightRay).init(self.allocator);
        defer new_rays.deinit();

        for (self.rays) |ray| {
            try self.lit_areas.put(ray.coord, true);
            const addl_rays = try ray.advance(self.allocator, self.area);
            try new_rays.appendSlice(addl_rays);
        }

        const rays = try new_rays.toOwnedSlice();

        self.allocator.free(self.rays);
        self.rays = rays;

        if (self.rays.len == 0) {
            return false;
        }
    }

    pub fn count_lit_areas(self: Contraption) usize {
        return self.lit_areas.keys().len;
    }
};
