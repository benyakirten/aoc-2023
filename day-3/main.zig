const std = @import("std");

const root = @import("root.zig");

const Island = root.Island;
const Coord = root.Coord;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    const inputs = try std.fs.cwd().openFile("puzzle_inputs.txt", .{ .mode = .read_only });

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

    while (try inputs.read(buf) != 0) {
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
                const coord = Coord{ .x = x, .y = y };
                try line_coords.append(coord);
            }
        }

        x += 1;
    }

    const islands = try islands_list.toOwnedSlice();
    const coords = try coords_list.toOwnedSlice();

    var sum: u32 = 0;

    for (islands) |island| {
        const val = getIslandValue(coords, island);
        std.debug.print("Adding {} to {}\n\n", .{ val, sum });
        sum += val;
    }

    std.debug.print("Total: {}\n", .{sum});
}

fn getIslandValue(coords: [][]Coord, island: Island) u16 {
    const y_range = island.getYRange(coords.len);
    std.debug.print("Examining range from {} to {} for {}\n", .{ y_range.min, y_range.max, island.value });

    for (y_range.min..y_range.max) |i| {
        std.debug.print("line {}\n", .{i});
        const potential_coords = coords[i];

        for (potential_coords) |coord| {
            if (island.isAdjacentTo(coord)) {
                return island.value;
            }
        }
    }

    return 0;
}
