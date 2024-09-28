const std = @import("std");

pub const Instruction = struct {
    value: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Instruction) void {
        self.allocator.free(self.value);
    }

    pub fn hash(data: []const u8) usize {
        var total: usize = 0;
        for (data) |byte| {
            total += byte;
            total *= 17;
            total %= 256;
        }
        return total;
    }

    pub fn parse(allocator: std.mem.Allocator, data: []u8) ![]Instruction {
        var commands = std.ArrayList(Instruction).init(allocator);
        defer commands.deinit();

        var command = std.ArrayList(u8).init(allocator);
        for (data, 0..) |byte, i| {
            if (byte == ',' or i == data.len - 1) {
                if (i == data.len - 1) {
                    try command.append(byte);
                }
                const cmd = try command.toOwnedSlice();
                try commands.append(Instruction{ .value = cmd, .allocator = allocator });
                command.clearAndFree();
            } else {
                try command.append(byte);
            }
        }

        return try commands.toOwnedSlice();
    }
};

pub const LensBoxes = struct {
    boxes: []?std.ArrayList(LensState),
    allocator: std.mem.Allocator,

    pub fn deinit(self: LensBoxes) void {
        for (0..self.boxes.len) |i| {
            if (self.boxes[i]) |box| {
                box.deinit();
            }
        }
        self.allocator.free(self.boxes);
    }

    const Insertion = struct { focal_length: u8, lens: []const u8 };
    const Removal = struct { lens: []const u8 };

    const OperationError = error{MissingInstructionType};
    const Operation = union(enum) {
        Remove: Removal,
        Insert: Insertion,

        fn parseFocalLength(focal_length: []const u8) u8 {
            var total: u8 = 0;
            for (focal_length) |byte| {
                total = total * 10 + byte - '0';
            }
            return total;
        }

        fn parseRemove(lens: []const u8) Operation {
            return Operation{ .Remove = Removal{ .lens = lens } };
        }

        fn parseInsertion(lens: []const u8, focal_length: []const u8) Operation {
            return Operation{ .Insert = Insertion{ .focal_length = Operation.parseFocalLength(focal_length), .lens = lens } };
        }
    };

    const LensState = struct { lens: []const u8, focal_length: u8 };

    fn parseOperation(allocator: std.mem.Allocator, instruction: Instruction) !Operation {
        var lens_name = std.ArrayList(u8).init(allocator);
        defer lens_name.deinit();

        for (instruction.value, 0..) |byte, i| {
            switch (byte) {
                '=' => {
                    const focal_length = instruction.value[i + 1 ..];
                    const lens = try lens_name.toOwnedSlice();
                    return Operation.parseInsertion(
                        lens,
                        focal_length,
                    );
                },
                '-' => {
                    const lens = try lens_name.toOwnedSlice();
                    return Operation.parseRemove(
                        lens,
                    );
                },

                else => try lens_name.append(byte),
            }
        }

        return OperationError.MissingInstructionType;
    }

    pub fn boxLenses(allocator: std.mem.Allocator, instructions: []Instruction) !LensBoxes {
        const boxes = try allocator.alloc(?std.ArrayList(LensState), 256);
        for (boxes) |*box| {
            box.* = null;
        }

        instruction_loop: for (instructions) |instruction| {
            const operation = try parseOperation(allocator, instruction);
            std.debug.print("After \"{s}\":\n", .{instruction.value});
            defer printBoxState(boxes);

            switch (operation) {
                .Insert => |op| {
                    const hash = Instruction.hash(op.lens);
                    var box = boxes[hash];
                    if (box == null) {
                        var new_box = std.ArrayList(LensState).init(allocator);
                        try new_box.append(LensState{ .lens = op.lens, .focal_length = op.focal_length });
                        boxes[hash] = new_box;

                        continue :instruction_loop;
                    }

                    for (0..box.?.items.len) |i| {
                        if (std.mem.eql(u8, box.?.items[i].lens, op.lens)) {
                            box.?.items[i].focal_length = op.focal_length;

                            continue :instruction_loop;
                        }
                    }

                    try boxes[hash].?.append(LensState{ .lens = op.lens, .focal_length = op.focal_length });
                },

                .Remove => |op| {
                    const hash = Instruction.hash(op.lens);
                    if (boxes[hash] != null) {
                        for (boxes[hash].?.items, 0..) |item, i| {
                            if (std.mem.eql(u8, item.lens, op.lens)) {
                                _ = boxes[hash].?.orderedRemove(i);
                                break;
                            }
                        }
                    }
                },
            }
        }

        return LensBoxes{ .boxes = boxes, .allocator = allocator };
    }

    fn printBoxState(boxes: []?std.ArrayList(LensState)) void {
        for (0..boxes.len) |i| {
            if (boxes[i]) |box| {
                if (box.items.len == 0) {
                    continue;
                }
                std.debug.print("Box {}: ", .{i});
                for (box.items) |item| {
                    std.debug.print("[{s} {}] ", .{ item.lens, item.focal_length });
                }
                std.debug.print("\n", .{});
            }
        }

        std.debug.print("\n", .{});
    }

    pub fn sum(self: LensBoxes) usize {
        var total: usize = 0;
        for (0..self.boxes.len) |i| {
            if (self.boxes[i]) |box| {
                for (box.items, 0..) |item, j| {
                    const amt = (i + 1) * (j + 1) * item.focal_length;
                    total += amt;
                }
            }
        }
        return total;
    }
};

test "Instruction.hash" {
    const data_arr = "HASH";
    const data = data_arr[0..];

    const instruction = Instruction{ .allocator = std.testing.allocator, .value = data };

    const got = Instruction.hash(instruction.value);
    try std.testing.expectEqual(52, got);
}
