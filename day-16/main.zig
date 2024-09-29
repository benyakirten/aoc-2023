const std = @import("std");

const Contraption = @import("root.zig").Contraption;

const MAX_BUFFER_SIZE = 1_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const input = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer input.close();

    const content = try input.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
    defer allocator.free(content);

    var contraption = try Contraption.parse(allocator, content);
    defer contraption.deinit();

    try contraption.run();
    std.debug.print("Lit areas: {}\n", .{contraption.count_lit_areas()});
}
