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
};

pub const Platform = struct {
    area: [][]Terrain,
    allocator: std.mem.Allocator,
    // For cycle detection - we store the score since it's unlikely to be the same for different setups
    cache: std.AutoHashMap(usize, usize),

    const DIRECTIONS = [4]Platform.Direction{ .North, .East, .South, .West };

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
            .cache = std.AutoHashMap(usize, usize).init(allocator),
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
                    for (row, 0..) |cell, j| {
                        if (cell == .RoundedRock) {
                            switch (direction) {
                                .North => self.moveRocksUp(i, j),
                                .East => self.moveRocksRight(i, j),
                                .South => self.moveRocksDown(i, j),
                                .West => self.moveRocksLeft(i, j),
                            }
                        }
                    }
                }
            }

            const score = self.getLoad();
            if (self.cache.get(score)) |last_detected| {
                // Cycle detected
                std.debug.print("Cycle detected at iteration {}, last detected at {}\n", .{ cycle, last_detected });
            } else {
                try self.cache.put(score, cycle);
            }
        }
    }

    fn moveRocksDown(self: *Platform, row_num: usize, col_num: usize) void {
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

    fn moveRocksRight(self: *Platform, row_num: usize, col_num: usize) void {
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

    fn moveRocksLeft(self: *Platform, row_num: usize, col_num: usize) void {
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

test "Platform.moveRocksLeft move one rock left from the start of the row" {
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
        .cache = std.AutoHashMap(usize, usize).init(std.testing.allocator),
    };

    platform.moveRocksLeft(0, 2);

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

test "Platform.moveRocksLeft move all rocks left" {
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
        .cache = std.AutoHashMap(usize, usize).init(std.testing.allocator),
    };

    for (0..row_arr.len) |i| {
        platform.moveRocksLeft(0, i);
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

test "Platform.moveRocksRight move one rock right from the end of the row" {
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
        .cache = std.AutoHashMap(usize, usize).init(std.testing.allocator),
    };

    platform.moveRocksRight(0, 1);

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

test "Platform.moveRocksRight move all rocks right" {
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
        .cache = std.AutoHashMap(usize, usize).init(std.testing.allocator),
    };

    for (0..row_arr.len) |i| {
        platform.moveRocksRight(0, i);
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
