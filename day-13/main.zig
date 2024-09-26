const std = @import("std");

const Landscape = @import("land.zig").Landscape;

const MAX_BUFFER_SIZE = 1_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const input = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer input.close();

    const content = try input.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
    defer allocator.free(content);

    const landscapes = try Landscape.parse(allocator, content);

    var total: usize = 0;
    for (landscapes) |landscape| {
        const symmetry = try landscape.identifySymmetries();
        total += if (symmetry.type == .Horizontal) symmetry.focal_point else @as(u16, symmetry.focal_point) * 100;
    }
    std.debug.print("Total: {}\n", .{total});
}
