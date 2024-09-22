const std = @import("std");

pub const RecordError = error{UnrecognizedLandType};
pub const Record = enum {
    Operational,
    Damaged,
    Unknown,

    fn fromChar(char: u8) !Record {
        switch (char) {
            '#' => return Record.Damaged,
            '.' => return Record.Operational,
            '?' => return Record.Unknown,
            else => return RecordError.UnrecognizedLandType,
        }
    }
};

pub const HotSpring = struct {
    records: []Record,
    positions: []u16,
    allocator: std.mem.Allocator,

    pub fn deinit(self: HotSpring) void {
        self.allocator.free(self.records);
        self.allocator.free(self.positions);
    }

    // pub fn permute(self: HotSpring) usize {
    //     //
    // }

    pub fn parse(raw_data: []u8, allocator: std.mem.Allocator) ![]HotSpring {
        var hot_spring_list = std.ArrayList(u8).init(allocator);
        defer hot_spring_list.deinit();

        var hot_springs_list = std.ArrayList(HotSpring).init(allocator);
        defer hot_springs_list.deinit();

        for (raw_data, 0..) |datum, i| {
            if (datum == '\n' or i == raw_data.len - 1) {
                if (i == raw_data.len - 1) {
                    try hot_spring_list.append(datum);
                }

                const raw_hot_spring = try hot_spring_list.toOwnedSlice();
                hot_spring_list.clearAndFree();

                const hot_spring = try HotSpring.new(raw_hot_spring);
                try hot_springs_list.append(hot_spring);
            } else {
                try hot_spring_list.append(datum);
            }
        }

        return try hot_springs_list.deinit();
    }

    pub fn new(data: []u8, allocator: std.mem.Allocator) !HotSpring {
        var records_list = try std.ArrayList(Record).initCapacity(allocator, data.len);
        defer records_list.deinit();

        var positions_list = try std.ArrayList(u16).initCapacity(allocator, data.len / 2);
        defer positions_list.deinit();

        var positions_index: u16 = 0;
        for (data, 0..) |datum, i| {
            if (data == '\n') {
                positions_index = i + 1;
                break;
            }
            try records_list.append(try Record.fromChar(datum));
        }

        for (data[positions_index..]) |datum| {
            if (datum >= '0' and datum <= '9') {
                try positions_list.append(datum - '0');
            }
        }

        const records = try records_list.toOwnedSlice();
        const positions = try positions_list.toOwnedSlice();

        return HotSpring{ .records = records, .positions = positions, .allocator = allocator };
    }
};
