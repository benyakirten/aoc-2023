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

    pub fn printRow(row: []Terrain) void {
        for (row) |cell| {
            std.debug.print("{c}", .{@intFromEnum(cell)});
        }
    }

    fn toHashable(allocator: std.mem.Allocator, area: [][]Terrain) ![]const u8 {
        const buffer = try allocator.alloc(u8, area.len * area[0].len);
        for (area, 0..) |row, i| {
            for (row, 0..) |cell, j| {
                buffer[j + i * row.len] = @intFromEnum(cell);
            }
        }

        return buffer;
    }

    const TerrainContext = struct {
        pub fn hash(_: TerrainContext, area: []const u8) u64 {
            var h = std.hash.Fnv1a_64.init();
            h.update(area);
            return h.final();
        }

        pub fn eql(_: TerrainContext, a: []const u8, b: []const u8) bool {
            return std.mem.eql(u8, a, b);
        }
    };
};

test "Terrain.toHashable" {
    var row_1_arr = [_]Terrain{
        .EmptySpace,
        .EmptySpace,
        .RoundedRock,
        .RoundedRock,
        .CubeRock,
        .EmptySpace,
        .RoundedRock,
    };
    const row_1 = row_1_arr[0..];

    var row_2_arr = [_]Terrain{
        .RoundedRock,
        .RoundedRock,
        .EmptySpace,
        .CubeRock,
        .EmptySpace,
        .RoundedRock,
        .EmptySpace,
    };
    const row_2 = row_2_arr[0..];

    var area_arr = [_][]Terrain{
        row_1,
        row_2,
    };
    const area = area_arr[0..];

    const buffer = try Terrain.toHashable(std.testing.allocator, area);
    defer std.testing.allocator.free(buffer);

    const expected_arr = "..OO#.OOO.#.O.";
    const expected: []const u8 = expected_arr[0..];
    try std.testing.expectEqualDeep(buffer, expected);
}

pub const Platform = struct {
    area: [][]Terrain,
    allocator: std.mem.Allocator,
    // For cycle detection - we store the score since it's unlikely to be the same for different setups
    cache: std.HashMap([]const u8, usize, Terrain.TerrainContext, std.hash_map.default_max_load_percentage),

    const DIRECTIONS = [4]Platform.Direction{
        .North,
        .West,
        .South,
        .East,
    };

    pub const Direction = enum {
        North,
        East,
        South,
        West,
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

    pub fn getLoad(self: Platform) usize {
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
            .cache = std.HashMap([]const u8, usize, Terrain.TerrainContext, std.hash_map.default_max_load_percentage).init(allocator),
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
        for (0..num_reps) |cycle| {
            for (DIRECTIONS) |direction| {
                for (self.area, 0..) |row, i| {
                    for (0..row.len) |j| {
                        switch (direction) {
                            .North => self.moveRocksNorth(i, j),
                            .West => self.moveRocksWest(i, j),
                            .South => self.moveRocksSouth(i, j),
                            .East => self.moveRocksEast(i, j),
                        }
                    }
                }
            }

            const hashed_area = try Terrain.toHashable(self.allocator, self.area);
            if (self.cache.get(hashed_area)) |last_detected| {
                // Cycle detected
                std.debug.print("Cycle detected at iteration {}, last detected at {}, total load {}\n", .{ cycle, last_detected, self.getLoad() });
            } else {
                try self.cache.put(hashed_area, cycle);
            }
        }
    }

    fn moveRocksEast(self: *Platform, row_num: usize, col_num: usize) void {
        if (col_num == 0) {
            return;
        }

        const row = &self.area[row_num];
        const col_len = self.area[row_num].len;
        for (0..col_num) |i| {
            const col_index = col_len - (col_num - i);

            if (row.*[col_index - 1] != .RoundedRock) {
                return;
            }

            if (row.*[col_index] == .EmptySpace) {
                row.*[col_index] = .RoundedRock;
                row.*[col_index - 1] = .EmptySpace;
            } else {
                break;
            }
        }
    }

    fn moveRocksWest(self: *Platform, row_num: usize, col_num: usize) void {
        if (col_num == 0) {
            return;
        }

        const row = &self.area[row_num];
        for (0..col_num) |i| {
            const col_index = col_num - i;
            if (row.*[col_index] != .RoundedRock) {
                return;
            }

            if (row.*[col_index - 1] == .EmptySpace) {
                row.*[col_index - 1] = .RoundedRock;
                row.*[col_index] = .EmptySpace;
            } else {
                break;
            }
        }
    }

    fn moveRocksSouth(self: *Platform, row_num: usize, col_num: usize) void {
        if (row_num == 0) {
            return;
        }

        const row_count = self.area.len;
        for (0..row_num) |i| {
            const row_index = row_count - (row_num - i);
            const row = &self.area[row_index - 1];
            if (row.*[col_num] != .RoundedRock) {
                return;
            }

            const previous_row = &self.area[row_index];

            if (previous_row.*[col_num] == .EmptySpace) {
                previous_row.*[col_num] = .RoundedRock;
                row.*[col_num] = .EmptySpace;
            } else {
                break;
            }
        }
    }

    fn moveRocksNorth(self: *Platform, row_num: usize, col_num: usize) void {
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

test "Platform.moveRocksWest move one rock left from the start of the row" {
    var row_arr = [_]Terrain{
        .EmptySpace,
        .EmptySpace,
        .RoundedRock,
        .RoundedRock,
        .CubeRock,
        .EmptySpace,
        .RoundedRock,
    };
    const row = row_arr[0..];
    var area_arr = [_][]Terrain{
        row,
    };
    const area = area_arr[0..];

    var platform = Platform{
        .area = area,
        .allocator = std.testing.allocator,
        .cache = std.HashMap([]const u8, usize, Terrain.TerrainContext, std.hash_map.default_max_load_percentage).init(std.testing.allocator),
    };

    platform.moveRocksWest(0, 2);

    var expected_arr = [_]Terrain{
        .RoundedRock,
        .EmptySpace,
        .EmptySpace,
        .RoundedRock,
        .CubeRock,
        .EmptySpace,
        .RoundedRock,
    };
    const expected = expected_arr[0..];

    try std.testing.expectEqualDeep(platform.area[0], expected);
}

test "Platform.moveRocksWest move all rocks left" {
    var row_arr = [_]Terrain{
        .EmptySpace,
        .EmptySpace,
        .RoundedRock,
        .RoundedRock,
        .CubeRock,
        .RoundedRock,
        .EmptySpace,
        .RoundedRock,
        .CubeRock,
        .EmptySpace,
        .RoundedRock,
    };
    const row = row_arr[0..];
    var area_arr = [_][]Terrain{
        row,
    };
    const area = area_arr[0..];

    var platform = Platform{
        .area = area,
        .allocator = std.testing.allocator,
        .cache = std.HashMap([]const u8, usize, Terrain.TerrainContext, std.hash_map.default_max_load_percentage).init(std.testing.allocator),
    };

    for (0..row_arr.len) |i| {
        platform.moveRocksWest(0, i);
    }

    var expected_arr = [_]Terrain{
        .RoundedRock,
        .RoundedRock,
        .EmptySpace,
        .EmptySpace,
        .CubeRock,
        .RoundedRock,
        .RoundedRock,
        .EmptySpace,
        .CubeRock,
        .RoundedRock,
        .EmptySpace,
    };
    const expected = expected_arr[0..];

    try std.testing.expectEqualDeep(platform.area[0], expected);
}

test "Platform.moveRocksEast move one rock right from the end of the row" {
    var row_arr = [_]Terrain{
        .RoundedRock,
        .RoundedRock,
        .EmptySpace,
        .EmptySpace,
        .CubeRock,
        .RoundedRock,
        .EmptySpace,
    };
    const row = row_arr[0..];
    var area_arr = [_][]Terrain{
        row,
    };
    const area = area_arr[0..];

    var platform = Platform{
        .area = area,
        .allocator = std.testing.allocator,
        .cache = std.HashMap([]const u8, usize, Terrain.TerrainContext, std.hash_map.default_max_load_percentage).init(std.testing.allocator),
    };

    platform.moveRocksEast(0, 1);

    var expected_arr = [_]Terrain{
        .RoundedRock,
        .RoundedRock,
        .EmptySpace,
        .EmptySpace,
        .CubeRock,
        .EmptySpace,
        .RoundedRock,
    };
    const expected = expected_arr[0..];

    try std.testing.expectEqualDeep(platform.area[0], expected);
}

test "Platform.moveRocksEast move all rocks right" {
    var row_arr = [_]Terrain{
        .RoundedRock,
        .RoundedRock,
        .EmptySpace,
        .EmptySpace,
        .CubeRock,
        .RoundedRock,
        .RoundedRock,
        .EmptySpace,
        .CubeRock,
        .RoundedRock,
        .EmptySpace,
    };
    const row = row_arr[0..];
    var area_arr = [_][]Terrain{
        row,
    };
    const area = area_arr[0..];

    var platform = Platform{
        .area = area,
        .allocator = std.testing.allocator,
        .cache = std.HashMap([]const u8, usize, Terrain.TerrainContext, std.hash_map.default_max_load_percentage).init(std.testing.allocator),
    };

    for (0..row_arr.len) |i| {
        platform.moveRocksEast(0, i);
    }

    var expected_arr = [_]Terrain{
        .EmptySpace,
        .EmptySpace,
        .RoundedRock,
        .RoundedRock,
        .CubeRock,
        .EmptySpace,
        .RoundedRock,
        .RoundedRock,
        .CubeRock,
        .EmptySpace,
        .RoundedRock,
    };
    const expected = expected_arr[0..];

    try std.testing.expectEqualDeep(platform.area[0], expected);
}
