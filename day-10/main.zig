const std = @import("std");

const Map = @import("pipe.zig").Map;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const map = try Map.parse(inputs, allocator);
    const dist = try map.findMaxDistance();

    std.debug.print("Max distance: {}\n", .{dist});
}
