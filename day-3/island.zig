const std = @import("std");

const Coord = @import("coord.zig").Coord;

pub const Island = struct {
    value: u16,
    min_x: u16,
    max_x: u16,
    y: u16,

    pub fn isAdjacentTo(self: Island, coord: Coord) bool {
        if (coord.y > self.y + 1 or coord.y < self.y - 1) {
            return false;
        }

        if (coord.y == self.y) {
            return coord.x == self.min_x - 1 or coord.x == self.max_x + 1;
        }

        return coord.x >= self.min_x - 1 and coord.x <= self.max_x + 1;
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
};

test "Island.isAdjacentTo adjacent with the same y value" {
    const island = Island{ .max_x = 3, .value = 100, .min_x = 1, .y = 1 };
    const coords = [2]Coord{ Coord{ .x = 0, .y = 1 }, Coord{ .x = 4, .y = 1 } };

    for (coords) |coord| {
        const isAdjacent = island.isAdjacentTo(coord);
        try std.testing.expect(isAdjacent);
    }
}

test "Island.isAdjacentTo not adjacent with the same y value" {
    const island = Island{ .min_x = 5, .max_x = 7, .value = 100, .y = 1 };
    const coords = [2]Coord{ Coord{ .x = 3, .y = 1 }, Coord{ .x = 9, .y = 1 } };

    for (coords) |coord| {
        const isAdjacent = island.isAdjacentTo(coord);
        try std.testing.expect(!isAdjacent);
    }
}

test "Island.isAdjacentTo diagonal positions" {
    const island = Island{ .min_x = 5, .max_x = 7, .value = 100, .y = 1 };
    const coords = [4]Coord{
        Coord{ .x = 4, .y = 0 },
        Coord{ .x = 8, .y = 0 },
        Coord{ .x = 4, .y = 2 },
        Coord{ .x = 8, .y = 2 },
    };

    for (coords) |coord| {
        const isAdjacent = island.isAdjacentTo(coord);
        try std.testing.expect(isAdjacent);
    }
}

test "Island.isAdjacentTo diagonal positions offset too far" {
    const island = Island{ .min_x = 5, .max_x = 7, .value = 100, .y = 2 };
    const coords = [4]Coord{
        Coord{ .x = 3, .y = 1 },
        Coord{ .x = 9, .y = 1 },
        Coord{ .x = 4, .y = 4 },
        Coord{ .x = 4, .y = 0 },
    };

    for (coords) |coord| {
        const isAdjacent = island.isAdjacentTo(coord);
        try std.testing.expect(!isAdjacent);
    }
}

test "Island.isAdjacentTo within X range but Y offset" {
    const island = Island{ .min_x = 5, .max_x = 7, .value = 100, .y = 1 };
    const coords = [4]Coord{
        Coord{ .x = 5, .y = 0 },
        Coord{ .x = 6, .y = 0 },
        Coord{ .x = 7, .y = 2 },
        Coord{ .x = 5, .y = 2 },
    };

    for (coords) |coord| {
        const isAdjacent = island.isAdjacentTo(coord);
        try std.testing.expect(isAdjacent);
    }
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
