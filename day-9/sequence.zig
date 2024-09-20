const std = @import("std");

pub const SequenceError = error{ AllocationError, DerivationError };

pub const Sequence = struct {
    data: []isize,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Sequence) void {
        self.allocator.free(self.data);
    }

    pub fn getNext(self: Sequence) SequenceError!isize {
        const last_item = self.data[self.data.len - 1];
        return last_item + try deriveNextItem(self.data, self.allocator, 0);
    }

    fn deriveNextItem(sequence: []isize, allocator: std.mem.Allocator, iter: usize) SequenceError!isize {
        if (sequence.len == 0) {
            return SequenceError.DerivationError;
        }

        var derived_sequence = allocator.alloc(isize, sequence.len - 1) catch {
            return SequenceError.AllocationError;
        };

        var derived_to_nothing = true;
        for (0..sequence.len - 1) |i| {
            const delta: isize = sequence[i + 1] - sequence[i];
            derived_sequence[i] = delta;
            derived_to_nothing = derived_to_nothing and delta == 0;
        }

        if (derived_to_nothing) {
            return 0;
        }

        return derived_sequence[derived_sequence.len - 1] + try deriveNextItem(derived_sequence, allocator, iter + 1);
    }

    pub fn getPrevious(self: Sequence) SequenceError!isize {
        const reversed_arr = self.allocator.alloc(isize, self.data.len) catch {
            return SequenceError.AllocationError;
        };
        for (0..self.data.len) |i| {
            reversed_arr[i] = self.data[self.data.len - 1 - i];
        }

        const last_item = reversed_arr[reversed_arr.len - 1];
        return last_item + try deriveNextItem(reversed_arr, self.allocator, 0);
    }
};
