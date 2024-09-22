const std = @import("std");

const Map = @import("pipe.zig").Map;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const map = try Map.parse(inputs, allocator);
    defer map.deinit();

    var tracer = try map.traversePath();
    defer tracer.deinit();

    std.debug.print("Max distance: {}\n", .{tracer.distance / 2});

    const potential_dens = try map.findPotentialDens(&tracer);

    std.debug.print("Total potential den positions: {}\n", .{potential_dens});
}
