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

pub const Symmetry = union(SymmetryType) {
    focal_point: i8,
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
        if (try self.identifySymmetry(self.allocator, self.land, .Horizontal)) |sym| {
            return sym;
        }

        // Rotate matrix -90 degrees
        const rotated_land = try self.rotateLandLeft();
        defer self.free_land(rotated_land);
        if (try self.identifySymmetry(self.allocator, rotated_land, .Vertical)) |sym| {
            return sym;
        }

        return LandscapeError.NoSymmetryFound;
    }

    fn rotateLandLeft(self: Landscape) ![][]LandType {
        const rows_len = self.land.len;
        const cols_len = self.land[0].len;

        var rotated = try self.allocator.alloc([rows_len]LandType, cols_len);
        for (0..cols_len) |i| {
            const col = try self.allocator.alloc(LandType, rows_len);
            rotated[i] = col;
        }

        // Transpose the matrix and reverse columns
        for (self.land, 0..) |row, i| {
            for (row, 0..) |val, j| {
                rotated[cols_len - 1 - j][i] = val;
            }
        }

        return rotated;
    }

    fn identifySymmetry(allocator: std.mem.Allocator, land: [][]LandType, direction: SymmetryType) !?Symmetry {
        // A single row could have more than 1 apparent symmetry point
        var candidates = std.ArrayList(Symmetry).init(allocator);
        defer candidates.deinit();

        for (1..land[0].len - 2) |i| {
            const symmetry_length = identifySymmetryLength(land[0], i);
            if (symmetry_length > 0) {
                const symmetry = Symmetry{ .focal_point = i, .len = symmetry_length, .type = direction };
                try candidates.append(symmetry);
            }
        }

        // Check that all candidates exist for every row.
        var candidate_idx = 0;
        outer_loop: while (true) {
            const item = &candidates.items[candidate_idx];
            for (land) |row| {
                const symmetry_len = identifySymmetryLength(row, item.focal_point);
                if (symmetry_len == 0) {
                    candidates.swapRemove(candidate_idx);
                    continue :outer_loop;
                }

                // Some rows may have longer symmetry around a focal point.
                // We want the minimum length of symmetry that's valid for all rows.
                if (symmetry_len < item.len) {
                    item.len = symmetry_len;
                }
            }

            if (candidates.items.len == 0) {
                return null;
            }

            candidate_idx += 1;
        }

        if (candidates.items.len == 1) {
            return candidates.items[0];
        }

        // Return the largest symmetry we find.
        var max_len: u8 = 0;
        var max_len_idx: u8 = 0;
        for (candidates.items, 0..) |item, i| {
            if (item.len > max_len) {
                max_len = item.len;
                max_len_idx = i;
            }
        }

        return candidates[max_len_idx];
    }

    fn identifySymmetryLength(data: []LandType, focal_point: u8) u8 {
        if (focal_point == data.len - 1 or focal_point == 0) {
            return 0;
        }

        var len: u8 = 0;
        for (focal_point..data.len) |i| {
            if (focal_point - i < 0) {
                break;
            }
            const item = data[i];
            const mirrored = data[focal_point - i];

            if (item != mirrored) {
                break;
            }

            len += 1;
        }

        return len;
    }

    pub fn parse(data: []u8, allocator: std.mem.Allocator) ![]Landscape {
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
