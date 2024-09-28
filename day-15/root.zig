const std = @import("std");

pub const Instruction = struct {
    value: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Instruction) void {
        self.allocator.free(self.value);
    }

    pub fn sum(self: Instruction) usize {
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

test "Instruction.sum" {
    const data_arr = "HASH";
    const data = data_arr[0..];

    const instruction = Instruction{ .allocator = std.testing.allocator, .value = data };

    const got = instruction.sum();
    try std.testing.expectEqual(52, got);
}
