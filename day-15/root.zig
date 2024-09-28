const std = @import("std");

pub const Instruction = struct {
    value: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Instruction) void {
        self.allocator.free(self.value);
    }

    pub fn hash(self: Instruction) usize {
        var total: usize = 0;
        for (self.value) |byte| {
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
    boxes: []?std.ArrayListAligned(LensState),
    allocator: std.mem.Allocator,

    pub fn deinit(self: LensBoxes) void {
        for (0..self.boxes.len) |i| {
            if (self.boxes[i]) |box| {
                box.deinit();
            }
        }
        self.allocator.free(self.boxes);
    }

    const Insertion = struct { focal_length: u8, lens: []const u8, hash: u8 };
    const Removal = struct { lens: []const u8, hash: u8 };

    const OperationError = error{MissingInstructionType};
    const Operation = union(enum) {
        Remove: Removal,
        Insert: Insertion,

        fn parseRemove(lens: []const u8, instruction_hash: u8) Operation {
            return Operation.Remove{ .lens = lens, .hash = instruction_hash };
        }

        fn parseInsertion(lens: []const u8, focal_length: u8, instruction_hash: u8) Operation {
            return Operation.Insert{ .focal_length = focal_length, .lens = lens, .hash = instruction_hash };
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
                    const instruction_hash = @as(u8, @intCast(instruction.hash()));
                    return Operation.parseInsertion(lens, focal_length, instruction_hash);
                },
                '-' => {
                    const lens = try lens_name.toOwnedSlice();
                    const instruction_hash = @as(u8, @intCast(instruction.hash()));
                    return Operation.parseRemove(lens, instruction_hash);
                },

                else => try lens_name.append(byte),
            }

            return OperationError.MissingInstructionType;
        }
    }

    pub fn boxLenses(allocator: std.mem.Allocator, instructions: []Instruction) !LensBoxes {
        const boxes = try allocator.alloc(?std.ArrayList(LensState), 256);
        defer allocator.free(boxes);

        instruction_loop: for (instructions) |instruction| {
            const operation = try parseOperation(allocator, instruction);
            switch (operation) {
                .Insert => |op| {
                    if (boxes[op.hash]) |box| {
                        for (0..box.items.len) |i| {
                            if (std.mem.eql(box.items[i].lens, op.lens)) {
                                box.items[i].focal_length = op.focal_length;
                                continue :instruction_loop;
                            }
                        }

                        try box.append(LensState{ .lens = op.lens, .focal_length = op.focal_length });
                    } else {
                        const new_box = try std.ArrayList(LensState).init(allocator);
                        try new_box.append(LensState{ .lens = op.lens, .focal_length = op.focal_length });
                        boxes[op.hash] = new_box;
                    }
                },
                .Remove => |op| {
                    if (boxes[op.hash]) |box| {
                        for (box.items, 0..) |item, i| {
                            if (std.mem.eql(item.lens, op.lens)) {
                                box.swapRemove(i);
                                break;
                            }
                        }
                    }
                },
            }
        }

        return LensBoxes{ .boxes = boxes, .allocator = allocator };
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

    const got = instruction.hash();
    try std.testing.expectEqual(52, got);
}
