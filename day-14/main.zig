const std = @import("std");

const Platform = @import("root.zig").Platform;

const MAX_BUFFER_SIZE = 1_000_000;
const NUM_CYCLES = 1_000_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const input = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer input.close();

    const content = try input.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
    defer allocator.free(content);

    var platform = try Platform.parse(allocator, content);
    try platform.tilt(1);

    std.debug.print("Total value: {}\n", .{platform.getLoad()});
}

// test "main functionality does not leak memory" {
//     const input = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
//     defer input.close();

//     const content = try input.readToEndAlloc(std.testing.allocator, MAX_BUFFER_SIZE);
//     defer std.testing.allocator.free(content);

//     var platform = try Platform.parse(std.testing.allocator, content);
//     platform.deinit();

//     try std.testing.expect(true);
// }
