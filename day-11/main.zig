const std = @import("std");

const Map = @import("map.zig").Map;

const MAX_BUFFER_SIZE = 1_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const content = try inputs.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
    defer allocator.free(content);

    const map = try Map.parse(content, allocator);
    std.debug.print("POST TRANSFORMATION: {}x{}\n", .{ map.width, map.height });
    for (map.galaxies) |galaxy| {
        std.debug.print("Galaxy {},{}\n", .{ galaxy.x, galaxy.y });
    }
}
