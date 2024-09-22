const std = @import("std");

const Map = @import("map.zig").Map;

const MAX_BUFFER_SIZE = 1_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const content = try inputs.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
    defer allocator.free(content);

    const map = try Map.parse(content, allocator, 1_000_000);
    defer map.deinit();

    const distances = try map.galaxyDistances();
    var total: usize = 0;

    for (distances) |distance| {
        total += distance;
    }

    std.debug.print("Total distance between galaxies: {}\n", .{total});
}
