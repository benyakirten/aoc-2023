const std = @import("std");

const root = @import("root.zig");

const Island = root.Island;
const Coord = root.Coord;

const IslandsAndCoords = struct {
    islands: []Island,
    coords: [][]Coord,
    allocator: std.mem.Allocator,

    fn deinit(self: IslandsAndCoords) void {
        self.allocator.free(self.islands);
        for (self.coords) |coords| {
            self.allocator.free(coords);
        }
        self.allocator.free(self.coords);
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_inputs.txt", .{ .mode = .read_only });
    defer inputs.close();

    const islandsAndCoords = try getIslandsAndCoords(inputs, allocator);
    defer islandsAndCoords.deinit();

    const islands = islandsAndCoords.islands;
    const coords = islandsAndCoords.coords;

    const island_values = getAllIslandValues(islands, coords);
    std.debug.print("Island values: {}\n", .{island_values});

    const gear_ratio_total = getGearRatioTotal(islands, coords);
    std.debug.print("Gear ratio total: {}\n", .{gear_ratio_total});
}

// TODO: Make islands indexable by line ratio so we can avoid iterating over all islands
fn getGearRatioTotal(islands: []Island, coords: [][]Coord) usize {
    var gear_ratio: usize = 0;

    for (coords) |coord_line| {
        for (coord_line) |coord| {
            gear_ratio += coord.getGearRatio(islands);
        }
    }

    return gear_ratio;
}

fn getIslandsAndCoords(file: std.fs.File, allocator: std.mem.Allocator) !IslandsAndCoords {
    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    var islands_list = std.ArrayList(Island).init(allocator);
    defer islands_list.deinit();

    var coords_list = std.ArrayList([]Coord).init(allocator);
    defer coords_list.deinit();

    var line_coords = std.ArrayList(Coord).init(allocator);
    defer line_coords.deinit();

    var value: u16 = 0;
    var value_start_x: u16 = 0;

    var x: u16 = 0;
    var y: u16 = 0;

    while (try file.read(buf) != 0) {
        const letter = buf[0];

        if (letter == '\n') {
            x = 0;
            y += 1;

            const line_coords_slice = try line_coords.toOwnedSlice();
            try coords_list.append(line_coords_slice);
            line_coords.clearAndFree();

            continue;
        }

        if (letter >= '0' and letter <= '9') {
            if (value == 0) {
                value_start_x = x;
            }

            value = value * 10 + letter - '0';
        } else {
            if (value > 0) {
                const island = Island.fromValue(value_start_x, value, y);
                try islands_list.append(island);
                value = 0;
            }

            if (letter != '.') {
                const coord = Coord{ .x = x, .y = y, .val = letter };
                try line_coords.append(coord);
            }
        }

        x += 1;
    }

    const islands = try islands_list.toOwnedSlice();
    const coords = try coords_list.toOwnedSlice();

    return IslandsAndCoords{ .islands = islands, .coords = coords, .allocator = allocator };
}

test "main has no memory leaks" {
    try main();
}

test "getIslandsAndCoords has no memory leaks" {
    const inputs = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    const islandsAndCoords = try getIslandsAndCoords(inputs, std.testing.allocator);
    islandsAndCoords.deinit();
}

fn getAllIslandValues(islands: []Island, coords: [][]Coord) u32 {
    var sum: u32 = 0;

    for (islands) |island| {
        const val = island.getValue(coords);
        sum += val;
    }

    return sum;
}
