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

    pub fn deinit(self: Map) void {
        self.allocator.free(self.galaxies);
    }

    pub fn parse(data: []u8, allocator: std.mem.Allocator, expansion_coefficient: usize) !Map {
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
        defer allocator.free(extra_rows);

        const extra_columns = try columns_to_double.toOwnedSlice();
        defer allocator.free(extra_columns);

        const coefficient = if (expansion_coefficient == 1) 1 else expansion_coefficient - 1;

        for (galaxies) |*galaxy| {
            var num_expansions: usize = 0;
            for (extra_rows) |row_count| {
                if (galaxy.x <= row_count) {
                    break;
                }
                num_expansions += 1;
            }
            galaxy.x += coefficient * num_expansions;
        }

        for (galaxies) |*galaxy| {
            var num_expansions: usize = 0;
            for (extra_columns) |column_count| {
                if (galaxy.y <= column_count) {
                    break;
                }
                num_expansions += 1;
            }
            galaxy.y += coefficient * num_expansions;
        }

        return Map{
            .galaxies = galaxies,
            .width = width + extra_rows.len * expansion_coefficient,
            .height = height + extra_columns.len * expansion_coefficient,
            .allocator = allocator,
        };
    }

    fn distance(a: usize, b: usize) usize {
        return if (a > b) a - b else b - a;
    }

    pub fn galaxyDistances(self: Map) ![]usize {
        var distances = std.ArrayList(usize).init(self.allocator);
        for (0..self.galaxies.len) |i| {
            for (i + 1..self.galaxies.len) |j| {
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
