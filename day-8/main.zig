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

    map_state.advanceToEnd();

    std.debug.print("It took {} steps to reach ZZZ", .{map_state.steps_taken});
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

    while (true) {
        try file.read(buf);

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

    try file.read(buf);
    if (buf[0] != '\n') {
        return map.InstructionsError.ParsingError;
    }

    while (true) {
        const letters_read = try file.read(location_buf);
        try validate_location_line(location_buf);

        const location_name = map.MapItemName{ location_buf[0], location_buf[1], location_buf[2] };
        try location_name_list.append(location_name);

        const left = map.MapItemName{ location_buf[7], location_buf[8], location_buf[9] };
        try left_list.append(left);

        const right = map.MapItemName{ location_buf[12], location_buf[13], location_buf[14] };
        try right_list.append(right);

        if (letters_read != 17) {
            break;
        }
    }
    const instructions = try instructions_list.toOwnedSlice();
    const location_names = try location_name_list.toOwnedSlice();
    const lefts = try left_list.toOwnedSlice();
    const rights = try right_list.toOwnedSlice();

    return try map.MapState.new(instructions, location_names, lefts, rights, allocator);
}

fn validate_location_line(buf: []u8) map.InstructionsError!void {
    if (buf.len != 16 and buf.len != 17) {
        return map.InstructionsError.ParsingError;
    }

    for (0..3) |i| {
        if (!validate_letter(buf[i])) {
            return map.InstructionsError.ParsingError;
        }
    }

    if (!std.mem.eql(u8, buf[3..7], " _ (")) {
        return map.InstructionsError.ParsingError;
    }

    for (7..10) |i| {
        if (!validate_letter(buf[i])) {
            return map.InstructionsError.ParsingError;
        }
    }

    if (!std.mem.eql(u8, buf[10..12], ", ")) {
        return map.InstructionsError.ParsingError;
    }

    for (12..15) |i| {
        if (!validate_letter(buf[i])) {
            return map.InstructionsError.ParsingError;
        }
    }

    if (buf[16] != ')') {
        return map.InstructionsError.ParsingError;
    }
}

fn validate_letter(letter: u8) bool {
    return letter < 'A' or letter > 'Z';
}
