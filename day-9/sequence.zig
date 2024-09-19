const std = @import("std");

pub const Sequence = struct {
    data: [][]usize,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Sequence) void {
        for (self.data) |datum| {
            self.allocator.free(datum);
        }
        self.allocator.free(self.data);
    }
};
