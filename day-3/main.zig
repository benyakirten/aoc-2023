const std = @import("std");

const Island = @import("island.zig").Island;
const Coord = @import("coord.zig").Coord;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    const inputs = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });

    var islands = std.ArrayList(Island).init(allocator);
    defer islands.deinit();

    var coords = std.ArrayList([]Coord).init(allocator);
    defer coords.deinit();

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
            try coords.append(line_coords_slice);
            coords.clearAndFree();

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
                try islands.append(island);
                value = 0;
            }

            if (letter != '.') {
                const coord = Coord{ .x = x, .y = y };
                try line_coords.append(coord);
            }
        }

        x += 1;
    }

    // TODO: Find if islands are adjacent
}
