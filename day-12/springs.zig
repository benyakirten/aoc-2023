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

pub const KnownRecord = enum {
    Operational,
    Damaged,
};

pub const HotSpring = struct {
    records: []Record,
    positions: []u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: HotSpring) void {
        self.allocator.free(self.records);
        self.allocator.free(self.positions);
    }

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

                const hot_spring = try HotSpring.new(raw_hot_spring, allocator);
                try hot_springs_list.append(hot_spring);
            } else {
                try hot_spring_list.append(datum);
            }
        }

        return try hot_springs_list.toOwnedSlice();
    }

    pub fn new(data: []u8, allocator: std.mem.Allocator) !HotSpring {
        var records_list = try std.ArrayList(Record).initCapacity(allocator, data.len);
        defer records_list.deinit();

        var positions_list = try std.ArrayList(u8).initCapacity(allocator, data.len / 2);
        defer positions_list.deinit();

        var positions_index: usize = 0;
        for (data, 0..) |datum, i| {
            if (datum == ' ') {
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

    // pub fn permute(self: HotSpring) void {
    //     var index: u8 = 0;
    //     for (self.positions) |position| {}
    // }

    fn isValidSolution(self: HotSpring, proposed: []KnownRecord) bool {
        if (self.records.len != proposed.len) {
            return false;
        }

        const groups = Groups.identify(proposed, self.allocator) catch {
            return false;
        };
        defer groups.deinit();

        return std.mem.eql(u8, self.positions, groups.positions);
    }
};

const GroupError = error{NeedsOperationalBetweenGroup};
pub const Groups = struct {
    groups: []Group,
    positions: []u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Groups) void {
        self.allocator.free(self.groups);
        self.allocator.free(self.positions);
    }

    fn identify(proposed: []KnownRecord, allocator: std.mem.Allocator) !Groups {
        var group_list = try std.ArrayList(Group).initCapacity(allocator, proposed.len / 2);
        defer group_list.deinit();

        var position_list = try std.ArrayList(u8).initCapacity(allocator, proposed.len / 2);

        var idx = 0;
        while (true) {
            const group = Group.identify(proposed, idx);
            if (group.len == 0) {
                break;
            }

            const next_index = group.start + group.len + 1;
            if (next_index >= proposed.len) {
                break;
            }

            if (proposed[next_index] != .Operational) {
                return GroupError.NeedsOperationalBetweenGroup;
            }

            try group_list.append(group);
            try position_list.append(group.len);

            idx = next_index + 1;
        }

        const groups = try group_list.toOwnedSlice();
        const positions = try position_list.toOwnedSlice();

        return Groups{ .groups = groups, .positions = positions, .allocator = allocator };
    }
};

pub const Group = struct {
    start: u8,
    len: u8,

    fn identify(proposed: []KnownRecord, idx: u8) Group {
        var damaged_has_started: bool = false;
        var start_index: u8 = 0;
        var len: u8 = 0;

        for (proposed[idx..], idx..) |idea, i| {
            if (idea == .Operational) {
                if (damaged_has_started) {
                    break;
                }

                continue;
            }

            if (!damaged_has_started) {
                damaged_has_started = true;
                len = 1;
                start_index = @as(u8, @intCast(i));
            } else {
                len += 1;
            }
        }

        return Group{ .start = start_index, .len = len };
    }
};

test "Group.identify start of record begin operational" {
    var known_records = [4]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
    };

    const got = Group.identify(known_records[0..], 0);
    const want = Group{ .start = 1, .len = 2 };
    try std.testing.expectEqual(want, got);
}

test "Group.identify start of record begin damaged" {
    var known_records = [4]KnownRecord{
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
    };

    const got = Group.identify(known_records[0..], 0);
    const want = Group{ .start = 0, .len = 3 };
    try std.testing.expectEqual(want, got);
}

test "Group.identify start of record begin damaged read to end" {
    var known_records = [3]KnownRecord{
        .Damaged,
        .Damaged,
        .Damaged,
    };

    const got = Group.identify(known_records[0..], 0);
    const want = Group{ .start = 0, .len = 3 };
    try std.testing.expectEqual(want, got);
}

test "Group.identify start of record begin operational read to end" {
    var known_records = [3]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
    };

    const got = Group.identify(known_records[0..], 0);
    const want = Group{ .start = 1, .len = 2 };
    try std.testing.expectEqual(want, got);
}

test "Group.identify middle of record begin operational" {
    var known_records = [7]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
    };

    const got = Group.identify(known_records[0..], 3);
    const want = Group{ .start = 4, .len = 2 };
    try std.testing.expectEqual(want, got);
}

test "Group.identify middle of record begin damaged" {
    var known_records = [7]KnownRecord{
        .Operational,
        .Damaged,
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
    };

    const got = Group.identify(known_records[0..], 3);
    const want = Group{ .start = 3, .len = 3 };
    try std.testing.expectEqual(want, got);
}

test "Group.identify end of record begin damaged" {
    var known_records = [6]KnownRecord{
        .Operational,
        .Damaged,
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
    };

    const got = Group.identify(known_records[0..], 3);
    const want = Group{ .start = 3, .len = 3 };
    try std.testing.expectEqual(want, got);
}

test "Group.identify end of record begin operational" {
    var known_records = [6]KnownRecord{
        .Operational,
        .Damaged,
        .Operational,
        .Operational,
        .Damaged,
        .Damaged,
    };

    const got = Group.identify(known_records[0..], 3);
    const want = Group{ .start = 4, .len = 2 };
    try std.testing.expectEqual(want, got);
}
