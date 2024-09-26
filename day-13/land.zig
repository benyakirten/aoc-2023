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

pub const SymmetryType = enum { Horizontal, Vertical };

pub const Symmetry = struct {
    focal_point: u8,
    len: u8,
    type: SymmetryType,
};

pub const LandscapeError = error{NoSymmetryFound};
pub const Landscape = struct {
    land: [][]LandType,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Landscape) void {
        self.free_land(self.land);
    }

    fn free_land(self: Landscape, land: [][]LandType) void {
        for (land) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(land);
    }

    pub fn identifySymmetries(self: Landscape) !Symmetry {
        if (try Landscape.identifySymmetry(self.allocator, self.land, .Horizontal)) |sym| {
            return sym;
        }

        const rotated_land = try self.rotateLandLeft();
        defer self.free_land(rotated_land);

        // Rotate matrix -90 degrees
        if (try Landscape.identifySymmetry(self.allocator, rotated_land, .Vertical)) |sym| {
            return sym;
        }

        return LandscapeError.NoSymmetryFound;
    }

    fn rotateLandLeft(self: Landscape) ![][]LandType {
        const rows_len = self.land.len;
        const cols_len = self.land[0].len;

        var matrix = try self.allocator.alloc([]LandType, cols_len);
        for (0..cols_len) |i| {
            const row = try self.allocator.alloc(LandType, rows_len);
            matrix[i] = row;
        }

        // 1  2  3  4    4 5 9
        // 5  6  7  8 -> 3 6 10
        // 9 10 11 12    2 7 11
        //               1 8 12
        // Transpose the matrix and reverse columns
        for (0..self.land.len) |i| {
            const row = self.land[i];
            for (0..row.len) |j| {
                const val = row[j];
                matrix[cols_len - j - 1][i] = val;
            }
        }

        return matrix;
    }

    fn identifySymmetry(allocator: std.mem.Allocator, land: [][]LandType, direction: SymmetryType) !?Symmetry {
        // A single row could have more than 1 apparent symmetry point
        var candidates = std.ArrayList(Symmetry).init(allocator);
        defer candidates.deinit();

        for (1..land[0].len - 2) |i| {
            const symmetry_length = identifySymmetryLength(land[0], @intCast(i));
            if (symmetry_length > 0 and (symmetry_length + i == land[0].len or i - symmetry_length == 0)) {
                const symmetry = Symmetry{ .focal_point = @intCast(i), .len = symmetry_length, .type = direction };
                try candidates.append(symmetry);
            }
        }

        // Check that all candidates exist for every row.
        var candidate_idx: u8 = 0;
        outer_loop: while (candidate_idx < candidates.items.len) {
            const item = &candidates.items[candidate_idx];
            for (land) |row| {
                // If the symmetry len is 0 then it means that there's no actual symmetry for that row.
                const symmetry_len = identifySymmetryLength(row, item.focal_point);
                if (symmetry_len == 0) {
                    _ = candidates.swapRemove(candidate_idx);
                    continue :outer_loop;
                }

                // Some rows may have longer symmetry around a focal point.
                // We want the minimum length of symmetry that's valid for all rows.
                if (symmetry_len < item.len) {
                    item.len = symmetry_len;
                }
            }

            candidate_idx += 1;
        }

        if (candidates.items.len == 0) {
            return null;
        } else if (candidates.items.len == 1) {
            return candidates.items[0];
        }

        // Return the largest symmetry we find.
        var max_len: u8 = 0;
        var max_len_idx: u8 = 0;
        for (candidates.items, 0..) |item, i| {
            if (item.len > max_len) {
                max_len = item.len;
                max_len_idx = @intCast(i);
            }
        }

        return candidates.items[max_len_idx];
    }

    fn identifySymmetryLength(data: []LandType, focal_point: u8) u8 {
        if (focal_point == data.len - 1 or focal_point == 0) {
            return 0;
        }

        var len: u8 = 0;
        while (len + focal_point - 1 < data.len and len <= focal_point) : (len += 1) {
            const item = data[focal_point + len - 1];
            const mirrored = data[focal_point - len];
            if (item != mirrored) {
                break;
            }
        }

        if (len != 0) {
            len -= 1;
        }

        return len;
    }

    pub fn parse(allocator: std.mem.Allocator, data: []u8) ![]Landscape {
        var landscape_list = std.ArrayList(Landscape).init(allocator);
        defer landscape_list.deinit();

        var lines_list = std.ArrayList([]LandType).init(allocator);
        defer lines_list.deinit();

        var line_list = std.ArrayList(LandType).init(allocator);
        defer line_list.deinit();

        var saw_line_break: bool = false;
        for (data, 0..) |letter, i| {
            if (i == data.len - 1 or (saw_line_break and letter == '\n')) {
                if (i == data.len - 1) {
                    const lt = try LandType.fromChar(letter);
                    try line_list.append(lt);

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

test "Landscape.rotateLandLeft" {
    var col_1_arr = [4]LandType{ .Ash, .Rocks, .Ash, .Rocks };
    const col_1 = col_1_arr[0..];

    var col_2_arr = [4]LandType{ .Rocks, .Rocks, .Rocks, .Ash };
    const col_2 = col_2_arr[0..];

    var rows_arr = [2][]LandType{ col_1, col_2 };
    const rows = rows_arr[0..];

    const ls = Landscape{
        .land = rows,
        .allocator = std.testing.allocator,
    };

    var want_arr_1 = [2]LandType{ .Rocks, .Ash };
    var want_arr_2 = [2]LandType{ .Ash, .Rocks };
    var want_arr_3 = [2]LandType{ .Rocks, .Rocks };
    var want_arr_4 = [2]LandType{ .Ash, .Rocks };

    var want_rows = [4][]LandType{ want_arr_1[0..], want_arr_2[0..], want_arr_3[0..], want_arr_4[0..] };
    const want = want_rows[0..];

    const got = try ls.rotateLandLeft();

    defer ls.free_land(got);

    try std.testing.expectEqualDeep(want, got);
}
