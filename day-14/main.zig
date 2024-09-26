const std = @import("std");

const Platform = @import("root.zig").Platform;

const MAX_BUFFER_SIZE = 1_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const input = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer input.close();

    const content = try input.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
    defer allocator.free(content);

    const platform = try Platform.parse(allocator, content);
    for (platform.area) |row| {
        for (row) |cell| {
            std.debug.print("{c}", .{@intFromEnum(cell)});
        }
        std.debug.print("\n", .{});
    }
}
