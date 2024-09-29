const std = @import("std");

const Contraption = @import("root.zig").Contraption;

const Contraptions = @import("root.zig").Contraptions;

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
    const lit_area_count = try contraption.count_lit_areas();
    std.debug.print("Lit areas: {}\n", .{lit_area_count});

    var contraptions = try Contraptions.parseToPermutations(allocator, content);
    defer contraptions.deinit();
    try contraptions.run();

    std.debug.print("Max lit areas: {}\n", .{try contraptions.find_max_lit_areas()});
}

test "main functionality does not leak memory" {
    const input = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer input.close();

    const content = try input.readToEndAlloc(std.testing.allocator, MAX_BUFFER_SIZE);
    defer std.testing.allocator.free(content);

    var contraption = try Contraption.parse(std.testing.allocator, content);
    defer contraption.deinit();

    try contraption.run();
    _ = try contraption.count_lit_areas();

    var contraptions = try Contraptions.parseToPermutations(std.testing.allocator, content);
    defer contraptions.deinit();

    try contraptions.run();

    _ = try contraptions.find_max_lit_areas();
}
