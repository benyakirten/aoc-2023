const std = @import("std");

pub const Coord = struct {
    x: u32,
    y: u32,
    val: u8,
};

pub const YRange = struct {
    min: usize,
    max: usize,
};

pub const Island = struct {
    value: u16,
    min_x: u16,
    max_x: u16,
    y: u16,

    pub fn isAdjacentTo(self: Island, coord: Coord) bool {
        const min_y: u16 = if (self.y == 0) 0 else self.y - 1;
        const min_x: u16 = if (self.min_x == 0) 0 else self.min_x - 1;

        if (coord.y == self.y) {
            return coord.x == min_x or coord.x == self.max_x + 1;
        }

        if (coord.y > self.y + 1 or coord.y < min_y) {
            return false;
        }

        return coord.x >= min_x and coord.x <= self.max_x + 1;
    }

    pub fn fromValue(start_x: u16, value: u16, y: u16) Island {
        var num_digits: u8 = 0;
        var val = value;
        while (val >= 10) {
            num_digits += 1;
            val /= 10;
        }

        return Island{
            .min_x = start_x,
            .max_x = start_x + num_digits,
            .value = value,
            .y = y,
        };
    }

    pub fn getYRange(self: Island, max_y: usize) YRange {
        const island_y = self.y;
        const min_coord_y: usize = if (island_y > 0) island_y - 1 else 0;
        const max_coord_y: usize = if (island_y < max_y - 1) island_y + 2 else max_y;

        return YRange{ .min = min_coord_y, .max = max_coord_y };
    }

    pub fn getValue(self: Island, coords: [][]Coord) u16 {
        const y_range = self.getYRange(coords.len);

        for (y_range.min..y_range.max) |i| {
            const potential_coords = coords[i];

            for (potential_coords) |coord| {
                if (self.isAdjacentTo(coord)) {
                    return self.value;
                }
            }
        }

        return 0;
    }
};

test "Island.isAdjacentTo adjacent with the same y value" {
    const island = Island{ .max_x = 3, .value = 100, .min_x = 1, .y = 1 };
    const coords = [2]Coord{
        Coord{ .x = 0, .y = 1, .val = '+' },
        Coord{ .x = 4, .y = 1, .val = '+' },
    };

    for (coords) |coord| {
        const isAdjacent = island.isAdjacentTo(coord);
        try std.testing.expect(isAdjacent);
    }
}

test "Island.isAdjacentTo not adjacent with the same y value" {
    const island = Island{ .min_x = 5, .max_x = 7, .value = 100, .y = 1 };
    const coords = [2]Coord{
        Coord{ .x = 3, .y = 1, .val = '+' },
        Coord{ .x = 9, .y = 1, .val = '+' },
    };

    for (coords) |coord| {
        const isAdjacent = island.isAdjacentTo(coord);
        try std.testing.expect(!isAdjacent);
    }
}

test "Island.isAdjacentTo diagonal positions" {
    const island = Island{ .min_x = 5, .max_x = 7, .value = 100, .y = 1 };
    const coords = [4]Coord{
        Coord{ .x = 4, .y = 0, .val = '+' },
        Coord{ .x = 8, .y = 0, .val = '+' },
        Coord{ .x = 4, .y = 2, .val = '+' },
        Coord{ .x = 8, .y = 2, .val = '+' },
    };

    for (coords) |coord| {
        const isAdjacent = island.isAdjacentTo(coord);
        try std.testing.expect(isAdjacent);
    }
}

test "Island.isAdjacentTo diagonal positions offset too far" {
    const island = Island{ .min_x = 5, .max_x = 7, .value = 100, .y = 2 };
    const coords = [4]Coord{
        Coord{ .x = 3, .y = 1, .val = '+' },
        Coord{ .x = 9, .y = 1, .val = '+' },
        Coord{ .x = 4, .y = 4, .val = '+' },
        Coord{ .x = 4, .y = 0, .val = '+' },
    };

    for (coords) |coord| {
        const isAdjacent = island.isAdjacentTo(coord);
        try std.testing.expect(!isAdjacent);
    }
}

test "Island.isAdjacentTo within X range but Y offset" {
    const island = Island{ .min_x = 5, .max_x = 7, .value = 100, .y = 1 };
    const coords = [4]Coord{
        Coord{ .x = 5, .y = 0, .val = '+' },
        Coord{ .x = 6, .y = 0, .val = '+' },
        Coord{ .x = 7, .y = 2, .val = '+' },
        Coord{ .x = 5, .y = 2, .val = '+' },
    };

    for (coords) |coord| {
        const isAdjacent = island.isAdjacentTo(coord);
        try std.testing.expect(isAdjacent);
    }
}

test "Island.asAdjacentTo will not overflow negative numbers" {
    const island = Island{ .min_x = 0, .max_x = 2, .value = 100, .y = 0 };
    const coord = Coord{ .x = 3, .y = 1, .val = '+' };

    const isAdjacent = island.isAdjacentTo(coord);
    try std.testing.expect(isAdjacent);
}

test "Island.fromValue value has 3 digits" {
    const got = Island.fromValue(4, 100, 2);
    const want = Island{ .min_x = 4, .max_x = 6, .value = 100, .y = 2 };
    try std.testing.expectEqual(want, got);
}

test "Island.fromValue value has 2 digits" {
    const got = Island.fromValue(4, 27, 2);
    const want = Island{ .min_x = 4, .max_x = 5, .value = 27, .y = 2 };
    try std.testing.expectEqual(want, got);
}

test "Island.fromValue value has 1 digits" {
    const got = Island.fromValue(4, 8, 2);
    const want = Island{ .min_x = 4, .max_x = 4, .value = 8, .y = 2 };
    try std.testing.expectEqual(want, got);
}

test "Island.getYRange full range" {
    const island = Island{ .min_x = 2, .max_x = 4, .value = 100, .y = 1 };
    const got = island.getYRange(4);
    try std.testing.expectEqual(0, got.min);
    try std.testing.expectEqual(3, got.max);
}

test "Island.getYRange range min limited" {
    const island = Island{ .min_x = 2, .max_x = 4, .value = 100, .y = 0 };
    const got = island.getYRange(4);

    try std.testing.expectEqual(0, got.min);
    try std.testing.expectEqual(2, got.max);
}

test "Island.getYRange range max limited" {
    const island = Island{ .min_x = 2, .max_x = 4, .value = 100, .y = 4 };
    const got = island.getYRange(4);

    try std.testing.expectEqual(3, got.min);
    try std.testing.expectEqual(4, got.max);
}

test "Island.getYRange range max limited at max - 1" {
    const island = Island{ .min_x = 2, .max_x = 4, .value = 100, .y = 3 };
    const got = island.getYRange(4);

    try std.testing.expectEqual(2, got.min);
    try std.testing.expectEqual(4, got.max);
}

test "Island.getValue is near one symbol" {
    const island = Island{ .min_x = 2, .max_x = 4, .value = 100, .y = 1 };

    var coord_line_0 = std.ArrayList(Coord).init(std.testing.allocator);
    defer coord_line_0.deinit();
    try coord_line_0.append(Coord{ .x = 3, .y = 0, .val = '+' });

    var coord_line_1 = std.ArrayList(Coord).init(std.testing.allocator);
    defer coord_line_1.deinit();

    var coords_list = std.ArrayList([]Coord).init(std.testing.allocator);
    defer coords_list.deinit();

    const coord_line_0_slice = try coord_line_0.toOwnedSlice();
    defer std.testing.allocator.free(coord_line_0_slice);
    try coords_list.append(coord_line_0_slice);

    const coord_line_1_slice = try coord_line_1.toOwnedSlice();
    defer std.testing.allocator.free(coord_line_1_slice);
    try coords_list.append(coord_line_1_slice);

    try coords_list.append(try coord_line_0.toOwnedSlice());
    try coords_list.append(try coord_line_1.toOwnedSlice());

    const coords = try coords_list.toOwnedSlice();
    defer std.testing.allocator.free(coords);

    const got = island.getValue(coords);
    try std.testing.expectEqual(100, got);
}

test "Island.getValue is near multiple symbols" {
    const island = Island{ .min_x = 2, .max_x = 4, .value = 100, .y = 1 };

    var coord_line_0 = std.ArrayList(Coord).init(std.testing.allocator);
    defer coord_line_0.deinit();
    try coord_line_0.append(Coord{ .x = 3, .y = 0, .val = '+' });

    var coord_line_1 = std.ArrayList(Coord).init(std.testing.allocator);
    defer coord_line_1.deinit();
    try coord_line_1.append(Coord{ .x = 1, .y = 1, .val = '+' });

    var coords_list = std.ArrayList([]Coord).init(std.testing.allocator);
    defer coords_list.deinit();

    const coord_line_0_slice = try coord_line_0.toOwnedSlice();
    defer std.testing.allocator.free(coord_line_0_slice);
    try coords_list.append(coord_line_0_slice);

    const coord_line_1_slice = try coord_line_1.toOwnedSlice();
    defer std.testing.allocator.free(coord_line_1_slice);
    try coords_list.append(coord_line_1_slice);

    try coords_list.append(try coord_line_0.toOwnedSlice());
    try coords_list.append(try coord_line_1.toOwnedSlice());

    const coords = try coords_list.toOwnedSlice();
    defer std.testing.allocator.free(coords);

    const got = island.getValue(coords);
    try std.testing.expectEqual(100, got);
}

test "Island.getValue is near no symbols" {
    const island = Island{ .min_x = 2, .max_x = 4, .value = 100, .y = 1 };

    var coord_line_0 = std.ArrayList(Coord).init(std.testing.allocator);
    defer coord_line_0.deinit();

    var coord_line_1 = std.ArrayList(Coord).init(std.testing.allocator);
    defer coord_line_1.deinit();

    var coords_list = std.ArrayList([]Coord).init(std.testing.allocator);
    defer coords_list.deinit();

    const coord_line_0_slice = try coord_line_0.toOwnedSlice();
    defer std.testing.allocator.free(coord_line_0_slice);
    try coords_list.append(coord_line_0_slice);

    const coord_line_1_slice = try coord_line_1.toOwnedSlice();
    defer std.testing.allocator.free(coord_line_1_slice);
    try coords_list.append(coord_line_1_slice);

    try coords_list.append(try coord_line_0.toOwnedSlice());
    try coords_list.append(try coord_line_1.toOwnedSlice());

    const coords = try coords_list.toOwnedSlice();
    defer std.testing.allocator.free(coords);

    const got = island.getValue(coords);
    try std.testing.expectEqual(0, got);
}
