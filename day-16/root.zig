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

        const deltafied_y: isize = @as(isize, @intCast(self.coord.y)) + delta_y;
        const deltafied_x: isize = @as(isize, @intCast(self.coord.x)) + delta_x;

        if (deltafied_y < 0 or deltafied_y > area.len - 1 or deltafied_x < 0 or deltafied_x > area[0].len - 1) {
            return try light_ray_list.toOwnedSlice();
        }

        const final_y = @as(usize, @intCast(deltafied_y));
        const final_x = @as(usize, @intCast(deltafied_x));

        const next_tile = area[final_y][final_x];
        const next_coord = Coordinate{ .x = @as(usize, @intCast(final_x)), .y = @as(usize, @intCast(final_y)) };
        switch (next_tile) {
            .Empty => {
                const next_ray = LightRay.new(self.direction, next_coord.x, next_coord.y);
                try light_ray_list.append(next_ray);
            },
            .LeftMirror => {
                const next_direction: LightDirection = switch (self.direction) {
                    .Up => .Right,
                    .Down => .Left,
                    .Left => .Down,
                    .Right => .Up,
                };

                const next_ray = LightRay.new(next_direction, next_coord.x, next_coord.y);
                try light_ray_list.append(next_ray);
            },
            .RightMirror => {
                const next_direction: LightDirection = switch (self.direction) {
                    .Up => .Left,
                    .Down => .Right,
                    .Left => .Up,
                    .Right => .Down,
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
    lit_areas: std.AutoArrayHashMap(Coordinate, LightDirection),
    rays: []LightRay,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Contraption) void {
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
        var rays = try std.ArrayList(LightRay).initCapacity(allocator, 1);
        try rays.append(starting_light_ray);
        defer rays.deinit();

        const lit_areas = std.AutoArrayHashMap(Coordinate, LightDirection).init(allocator);

        return Contraption{ .area = area, .rays = try rays.toOwnedSlice(), .lit_areas = lit_areas, .allocator = allocator };
    }

    pub fn run(self: *Contraption) !void {
        while (try self.tick()) {}
    }

    fn tick(self: *Contraption) !bool {
        var new_rays = std.ArrayList(LightRay).init(self.allocator);
        defer new_rays.deinit();

        for (self.rays) |ray| {
            if (self.lit_areas.get(ray.coord)) |dir| {
                if (dir == ray.direction) {
                    continue;
                }
            }

            try self.lit_areas.put(ray.coord, ray.direction);
            const addl_rays = try ray.advance(self.allocator, self.area);
            try new_rays.appendSlice(addl_rays);
        }

        const rays = try new_rays.toOwnedSlice();

        self.allocator.free(self.rays);
        self.rays = rays;

        return self.rays.len > 0;
    }

    pub fn count_lit_areas(self: Contraption) usize {
        return self.lit_areas.keys().len;
    }
};
