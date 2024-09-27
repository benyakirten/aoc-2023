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
        };
    }

    pub fn tiltUp(self: *Platform) void {
        for (1..self.area.len) |i| {
            const row = &self.area[i];
            for (0..row.len) |j| {
                self.moveRocksUp(i, j);
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
