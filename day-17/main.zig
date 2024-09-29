const std = @import("std");

const Map = @import("root.zig").Map;

const MAX_BUFFER_SIZE = 1_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const input = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer input.close();

    const content = try input.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
    defer allocator.free(content);

    _ = try Map.parse(allocator, content);
}

test "main does not leak memory" {
    const input = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer input.close();

    const content = try input.readToEndAlloc(std.testing.allocator, MAX_BUFFER_SIZE);
    defer std.testing.allocator.free(content);

    const map = try Map.parse(std.testing.allocator, content);
    defer map.deinit();
}
