const std = @import("std");

pub const TerrainError = error{InvalidChar};

pub const Terrain = enum(u8) {
    RoundedRock = 'O',
    CubeRock = '#',
    EmptySpace = '.',

    fn fromChar(value: u8) !Terrain {
        switch (value) {
            'O' => return Terrain.RoundedRock,
            '#' => return Terrain.CubeRock,
            '.' => return Terrain.EmptySpace,
            else => return TerrainError.InvalidChar,
        }
    }

    fn printRow(row: []Terrain) void {
        for (row) |cell| {
            std.debug.print("{c}", .{@intFromEnum(cell)});
        }
    }

    fn toHashable(allocator: std.mem.Allocator, area: [][]Terrain) ![][]const u8 {
        var rows = try std.ArrayList([]const u8).initCapacity(allocator, area.len);
        defer rows.deinit();

        var cols = try std.ArrayList(u8).initCapacity(allocator, area[0].len);
        defer cols.deinit();

        for (area) |row| {
            for (row) |cell| {
                try cols.append(@intFromEnum(cell));
            }

            const col_slice = try cols.toOwnedSlice();
            try rows.append(col_slice);
            cols.clearAndFree();
        }

        return try rows.toOwnedSlice();
    }
};

pub const Platform = struct {
    area: [][]Terrain,
    allocator: std.mem.Allocator,
    // For cycle detection
    cache: std.HashMap([][]const u8, CachedData, TerrainContext, std.hash_map.default_max_load_percentage),

    pub const Direction = enum {
        North,
        East,
        South,
        West,
    };

    pub const CachedData = struct {
        direction: Direction,
        num_reps: usize,
    };

    const TerrainContext = struct {
        pub fn hash(_: TerrainContext, area: [][]const u8) u64 {
            var h = std.hash.Fnv1a_64.init();
            for (area) |row| {
                h.update(row);
            }

            return h.final();
        }

        pub fn eql(_: TerrainContext, a: [][]const u8, b: [][]const u8) bool {
            if (a.len != b.len) {
                return false;
            }

            for (a, b) |row_a, row_b| {
                if (row_a.len != row_b.len) {
                    return false;
                }

                if (!std.mem.eql(Terrain, row_a, row_b)) {
                    return false;
                }
            }

            return true;
        }
    };

    pub fn deinit(self: Platform) void {
        self.freeArea();
        self.cache.deinit();
    }

    fn freeArea(self: Platform) void {
        for (self.area) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.area);
    }

    pub fn getNorthLoad(self: Platform) usize {
        var total: usize = 0;
        for (self.area, 0..) |row, i| {
            for (row) |cell| {
                if (cell == .RoundedRock) {
                    total += self.area.len - i;
                }
            }
        }
        return total;
    }

    pub fn parse(allocator: std.mem.Allocator, data: []u8) !Platform {
        var num_cols: usize = 0;
        while (data[num_cols] != '\n') : (num_cols += 1) {}

        var rows = try std.ArrayList([]Terrain).initCapacity(allocator, data.len / num_cols);
        defer rows.deinit();

        var cols = try std.ArrayList(Terrain).initCapacity(allocator, num_cols);
        defer cols.deinit();

        for (data, 0..) |char, i| {
            if (char == '\n' or i == data.len - 1) {
                if (i == data.len - 1) {
                    try cols.append(try Terrain.fromChar(char));
                }

                const col_slice = try cols.toOwnedSlice();
                try rows.append(col_slice);
                cols.clearAndFree();
            } else {
                try cols.append(try Terrain.fromChar(char));
            }
        }

        return Platform{
            .area = try rows.toOwnedSlice(),
            .allocator = allocator,
            .cache = std.HashMap([][]const u8, CachedData, TerrainContext, std.hash_map.default_max_load_percentage).init(allocator),
        };
    }

    pub fn print(self: Platform) void {
        for (self.area) |row| {
            Terrain.printRow(row);
            std.debug.print("\n", .{});
        }
        std.debug.print("\n", .{});
    }

    pub fn tilt(self: *Platform, num_reps: usize) !void {
        for (0..num_reps) |_| {
            for (0..4) |_| {
                for (self.area, 0..) |row, i| {
                    for (row, 0..) |cell, j| {
                        if (cell == .RoundedRock) {
                            self.moveRocksUp(i, j);
                        }
                    }
                }
            }
        }
    }

    fn moveRocksUp(self: *Platform, row_num: usize, col_num: usize) void {
        if (row_num == 0) {
            return;
        }

        for (0..row_num) |i| {
            const row_index = row_num - i;
            const row = &self.area[row_index];
            if (row.*[col_num] != .RoundedRock) {
                return;
            }

            const previous_row = &self.area[row_index - 1];

            if (previous_row.*[col_num] == .EmptySpace) {
                previous_row.*[col_num] = .RoundedRock;
                row.*[col_num] = .EmptySpace;
            } else {
                break;
            }
        }
    }
};
