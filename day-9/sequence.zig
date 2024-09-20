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
        return last_item + try deriveNextItem(self.data, self.allocator);
    }

    fn deriveNextItem(sequence: []isize, allocator: std.mem.Allocator) SequenceError!isize {
        if (sequence.len == 0) {
            return SequenceError.DerivationError;
        }

        var derived_to_nothing = true;
        var derived_sequence = allocator.alloc(isize, sequence.len - 1) catch {
            return SequenceError.AllocationError;
        };

        for (0..sequence.len - 2) |i| {
            const delta: isize = sequence[i + 1] - sequence[i];
            derived_sequence[i] = delta;
            derived_to_nothing = derived_to_nothing and delta == 0;
        }

        if (derived_to_nothing) {
            return 0;
        }

        return derived_sequence[derived_sequence.len - 1] + try deriveNextItem(derived_sequence, allocator);
    }
};
