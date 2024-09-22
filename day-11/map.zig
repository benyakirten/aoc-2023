const std = @import("std");

pub const Position = struct {
    x: usize,
    y: usize,
};

pub const Map = struct {
    galaxies: []Position,
    width: usize,
    height: usize,
    allocator: std.mem.Allocator,

    pub fn parse(data: []u8, allocator: std.mem.Allocator) !Map {
        var galaxies_list = std.ArrayList(Position).init(allocator);
        defer galaxies_list.deinit();

        var width: usize = 0;

        var x: usize = 0;
        var y: usize = 0;
        for (data) |char| {
            if (char == '\n') {
                if (width == 0) {
                    width = x;
                }
                x = 0;
                y += 1;
                continue;
            }

            if (char == '#') {
                const position = Position{ .x = x, .y = y };
                try galaxies_list.append(position);
            }
            x += 1;
        }

        if (width == 0) {
            width = data.len;
        }

        const height: usize = data.len / width;

        var rows_to_double = std.ArrayList(usize).init(allocator);
        defer rows_to_double.deinit();

        var columns_to_double = std.ArrayList(usize).init(allocator);
        defer columns_to_double.deinit();

        const galaxies = try galaxies_list.toOwnedSlice();

        for (0..height) |h| {
            var num_galaxies_with_y_coordinate: usize = 0;
            for (galaxies) |galaxy| {
                if (galaxy.y == h) {
                    num_galaxies_with_y_coordinate += 1;
                }
            }

            if (num_galaxies_with_y_coordinate == 0) {
                try columns_to_double.append(h);
            }
        }

        for (0..width) |w| {
            var num_galaxies_with_x_coordinate: usize = 0;
            for (galaxies) |galaxy| {
                if (galaxy.x == w) {
                    num_galaxies_with_x_coordinate += 1;
                }
            }

            if (num_galaxies_with_x_coordinate == 0) {
                try rows_to_double.append(w);
            }
        }

        const extra_rows = try rows_to_double.toOwnedSlice();
        const extra_columns = try columns_to_double.toOwnedSlice();

        for (extra_rows, 0..) |row_count, i| {
            for (galaxies) |*galaxy| {
                // This makes sure the adjustent is based on the original position
                // i.e. if row 4 and row 8 got expanded
                // then an item on row 7 will only get boosted from
                // row 4 being expanded and not row 8
                // This works because the eligible galaxy.x has already
                // been increased from previous iterations by however
                // many iterations have already happened.
                // If rows 4 and 8 got expanded, for a galaxy
                // on row 9, then it will be 10 by the time we look at 8
                // so 10 (galaxy.x) - 1(i) > 8 (row_count)
                // idem for columns below
                if (galaxy.x >= i and galaxy.x - i > row_count) {
                    galaxy.x += 1;
                }
            }
        }

        for (extra_columns, 0..) |column_count, i| {
            for (galaxies) |*galaxy| {
                if (galaxy.y >= i and galaxy.y - i > column_count) {
                    galaxy.y += 1;
                }
            }
        }

        return Map{
            .galaxies = galaxies,
            .width = width + extra_rows.len,
            .height = height + extra_columns.len,
            .allocator = allocator,
        };
    }

    fn distance(a: usize, b: usize) usize {
        return if (a > b) a - b else b - a;
    }

    pub fn galaxyDistances(self: Map) ![]usize {
        var distances = std.ArrayList(usize).init(self.allocator);
        for (0..self.galaxies.len) |i| {
            for (i..self.galaxies.len) |j| {
                const galaxy_a = self.galaxies[i];
                const galaxy_b = self.galaxies[j];

                const x_distance = distance(galaxy_a.x, galaxy_b.x);
                const y_distance = distance(galaxy_a.y, galaxy_b.y);

                const dist = x_distance + y_distance;
                try distances.append(dist);
            }
        }

        return try distances.toOwnedSlice();
    }
};
