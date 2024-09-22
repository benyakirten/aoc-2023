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
    defer allocator.free(distances);

    var total: usize = 0;

    for (distances) |distance| {
        total += distance;
    }

    std.debug.print("Total distance between galaxies: {}\n", .{total});
}

test "main functionality does not have memory leaks" {
    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const content = try inputs.readToEndAlloc(std.testing.allocator, MAX_BUFFER_SIZE);
    defer std.testing.allocator.free(content);

    const map = try Map.parse(content, std.testing.allocator, 1_000_000);
    defer map.deinit();

    const distances = try map.galaxyDistances();
    defer std.testing.allocator.free(distances);
}
