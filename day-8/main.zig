const std = @import("std");

const map = @import("map.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("puzzle_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    var map_state = try parseToMapState(inputs, allocator);
    defer map_state.deinit();

    try map_state.advanceToEnd();

    std.debug.print("It took {} steps to reach ZZZ\n", .{map_state.steps_taken});
}

pub fn parseToMapState(file: std.fs.File, allocator: std.mem.Allocator) !map.MapState {
    const buf = try allocator.alloc(u8, 1);
    defer allocator.free(buf);

    // All location lines are 16 characters long + \n (last line is 16 chars long)
    const location_buf = try allocator.alloc(u8, 17);
    defer allocator.free(location_buf);

    var location_name_list = std.ArrayList(map.MapItemName).init(allocator);
    defer location_name_list.deinit();

    var left_list = std.ArrayList(map.MapItemName).init(allocator);
    defer left_list.deinit();

    var right_list = std.ArrayList(map.MapItemName).init(allocator);
    defer right_list.deinit();

    var instructions_list = std.ArrayList(u8).init(allocator);
    defer instructions_list.deinit();

    while (try file.read(buf) != 0) {
        const letter = buf[0];
        if (letter == '\n') {
            break;
        }

        if (letter == 'R' or letter == 'L') {
            try instructions_list.append(letter);
        } else {
            return map.InstructionsError.ParsingError;
        }
    }

    _ = try file.read(buf);
    if (buf[0] != '\n') {
        return map.InstructionsError.ParsingError;
    }

    while (try file.read(location_buf) != 0) {
        const location_name = map.MapItemName{ location_buf[0], location_buf[1], location_buf[2] };
        try location_name_list.append(location_name);

        const left = map.MapItemName{ location_buf[7], location_buf[8], location_buf[9] };
        try left_list.append(left);

        const right = map.MapItemName{ location_buf[12], location_buf[13], location_buf[14] };
        try right_list.append(right);
    }

    const instructions = try instructions_list.toOwnedSlice();
    defer allocator.free(instructions);

    const location_names = try location_name_list.toOwnedSlice();
    defer allocator.free(location_names);

    const lefts = try left_list.toOwnedSlice();
    defer allocator.free(lefts);

    const rights = try right_list.toOwnedSlice();
    defer allocator.free(rights);

    return try map.MapState.new(instructions, location_names, lefts, rights, allocator);
}
