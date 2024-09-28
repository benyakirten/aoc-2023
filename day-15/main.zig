const std = @import("std");

const Instruction = @import("root.zig").Instruction;
const LensBoxes = @import("root.zig").LensBoxes;

const MAX_BUFFER_SIZE = 1_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const input = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer input.close();

    const content = try input.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
    defer allocator.free(content);

    const instructions = try Instruction.parse(allocator, content);

    var total: usize = 0;
    for (instructions) |instruction| {
        total += Instruction.hash(instruction.value);
    }
    std.debug.print("Total instruction hashes: {}\n", .{total});

    const lens_boxes = try LensBoxes.boxLenses(allocator, instructions);
    defer lens_boxes.deinit();

    std.debug.print("Total lens boxes: {}\n", .{lens_boxes.sum()});
}
