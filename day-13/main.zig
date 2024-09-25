const std = @import("std");

const Landscape = @import("land.zig").Landscape;

const MAX_BUFFER_SIZE = 1_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const input = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer input.close();

    const content = try input.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
    defer allocator.free(content);

    const landscapes = try Landscape.parse(content, allocator);
    for (landscapes) |landscape| {
        landscape.print();
        std.debug.print("\n", .{});
    }
}
