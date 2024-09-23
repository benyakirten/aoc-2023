const std = @import("std");

pub const RecordError = error{UnrecognizedLandType};
pub const Record = enum(u8) {
    Operational = '.',
    Damaged = '#',
    Unknown = '?',

    fn fromChar(char: u8) !Record {
        switch (char) {
            '#' => return Record.Damaged,
            '.' => return Record.Operational,
            '?' => return Record.Unknown,
            else => return RecordError.UnrecognizedLandType,
        }
    }

    fn toInts(records: []Record, allocator: std.mem.Allocator) ![]u8 {
        const data = try allocator.alloc(u8, records.len);
        for (records, 0..) |record, i| {
            data[i] = @intFromEnum(record);
        }

        return data;
    }
};

pub const KnownRecord = enum(u8) {
    Operational = '.',
    Damaged = '#',
};

pub const PartialHotSprings = struct {
    records: []u8,
    positions: []u8,
};

const PartialHotSpringsContext = struct {
    pub fn hash(_: PartialHotSpringsContext, key: PartialHotSprings) u64 {
        var h = std.hash.Fnv1a_32.init();
        h.update(key.positions);
        h.update(key.records);
        return h.final();
    }

    pub fn eql(_: PartialHotSpringsContext, a: PartialHotSprings, b: PartialHotSprings) bool {
        return std.mem.eql(u8, a.positions, b.positions) and std.mem.eql(u8, a.records, b.records);
    }
};

pub const HotSprings = struct {
    records: []Record,
    positions: []u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: HotSprings) void {
        self.allocator.free(self.records);
        self.allocator.free(self.positions);
    }

    pub fn parse(raw_data: []u8, allocator: std.mem.Allocator) ![]HotSprings {
        var hot_spring_list = std.ArrayList(u8).init(allocator);
        defer hot_spring_list.deinit();

        var hot_springs_list = std.ArrayList(HotSprings).init(allocator);
        defer hot_springs_list.deinit();

        for (raw_data, 0..) |datum, i| {
            if (datum == '\n' or i == raw_data.len - 1) {
                if (i == raw_data.len - 1) {
                    try hot_spring_list.append(datum);
                }

                const raw_hot_spring = try hot_spring_list.toOwnedSlice();
                hot_spring_list.clearAndFree();

                const hot_spring = try HotSprings.new(raw_hot_spring, allocator);
                try hot_springs_list.append(hot_spring);
            } else {
                try hot_spring_list.append(datum);
            }
        }

        return try hot_springs_list.toOwnedSlice();
    }

    pub fn new(data: []u8, allocator: std.mem.Allocator) !HotSprings {
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

        var position: u8 = 0;
        for (data[positions_index..]) |datum| {
            if (datum >= '0' and datum <= '9') {
                position = position * 10 + datum - '0';
            } else {
                try positions_list.append(position);
                position = 0;
            }
        }

        try positions_list.append(position);

        const records = try records_list.toOwnedSlice();
        const positions = try positions_list.toOwnedSlice();

        return HotSprings{ .records = records, .positions = positions, .allocator = allocator };
    }

    pub fn bruteForcePermute(self: HotSprings) ![][]KnownRecord {
        var num_unknowns: u8 = 0;
        for (self.records) |record| {
            if (record == .Unknown) {
                num_unknowns += 1;
            }
        }

        const num_permutations = std.math.pow(usize, 2, num_unknowns);

        var proposed_solution_list = std.ArrayList([]KnownRecord).init(self.allocator);
        defer proposed_solution_list.deinit();

        var possible_solution = try std.ArrayList(KnownRecord).initCapacity(self.allocator, self.records.len);
        defer possible_solution.deinit();

        for (0..num_permutations) |i| {
            var num_unknowns_encountered: u6 = 0;
            for (self.records) |record| {
                if (record != .Unknown) {
                    const known_record: KnownRecord = if (record == .Damaged) .Damaged else .Operational;
                    try possible_solution.append(known_record);
                } else {
                    const permutation_bit = i >> num_unknowns_encountered;
                    const permutation: KnownRecord = if (permutation_bit & 1 == 0) .Operational else .Damaged;
                    try possible_solution.append(permutation);
                    num_unknowns_encountered += 1;
                }
            }

            const solution = try possible_solution.toOwnedSlice();
            possible_solution.clearAndFree();

            if (self.isPossibleSolution(solution)) {
                try proposed_solution_list.append(solution);
            }
        }

        const solutions = try proposed_solution_list.toOwnedSlice();
        return solutions;
    }

    pub fn unfoldPermute(self: HotSprings) !usize {
        var cache = std.HashMap(PartialHotSprings, usize, PartialHotSpringsContext, 80).init(self.allocator);

        var records_list = try std.ArrayList(Record).initCapacity(self.allocator, self.records.len * 5 + 4);
        try records_list.appendSlice(self.records);
        for (0..4) |_| {
            try records_list.append(.Unknown);
            try records_list.appendSlice(self.records);
        }
        const records = try records_list.toOwnedSlice();

        var positions_list = try std.ArrayList(u8).initCapacity(self.allocator, self.positions.len * 5);
        for (0..5) |_| {
            try positions_list.appendSlice(self.positions);
        }
        const positions = try positions_list.toOwnedSlice();

        return try dynamicPermute(records, positions, &cache, self.allocator);
    }

    fn dynamicPermute(
        records: []Record,
        positions: []u8,
        cache: *std.HashMap(PartialHotSprings, usize, PartialHotSpringsContext, 80),
        allocator: std.mem.Allocator,
    ) !usize {
        // Base case
        if (positions.len == 0) {
            for (records) |record| {
                if (record == .Damaged) {
                    // No groups left but have broken hot springs... something is wrong.
                    return 0;
                }
            }

            return 1;
        }

        // We've already cached this piece of the records/positions
        const records_key = try Record.toInts(records, allocator);
        defer allocator.free(records_key);

        const cache_hit = cache.get(PartialHotSprings{ .positions = positions, .records = records_key });
        if (cache_hit != null) {
            return cache_hit.?;
        }

        // Check that we have enough records available to fill
        // in all the remaining positions
        var min_remaining_len: usize = 0;
        for (positions) |position| {
            min_remaining_len += position;
        }

        // To check that we have enough empty spaces (operational hot springs)
        // to break up the damaged ones, we add how many positions there are
        min_remaining_len += positions.len - 1;
        if (records.len < min_remaining_len) {
            return 0;
        }

        // If we have an operational hot springs at the beginning, it does nothing so we can skip it
        if (records[0] == .Operational) {
            return dynamicPermute(records[1..], positions, cache, allocator);
        }

        const current_position = positions[0];
        var all_records_valid: bool = true;
        for (records[0..current_position]) |record| {
            if (record == .Operational) {
                all_records_valid = false;
                break;
            }
        }

        const last_record_valid = records.len == current_position and records[current_position] != .Damaged;

        var total: usize = 0;
        if (all_records_valid and last_record_valid) {
            const max_idx = if (records.len < current_position + 1) records.len else current_position + 1;
            total += try dynamicPermute(records[max_idx..], positions[1..], cache, allocator);
        }

        if (records[0] != .Damaged) {
            total += try dynamicPermute(records[1..], positions, cache, allocator);
        }

        // Insert thte data into the cache
        try cache.put(PartialHotSprings{ .positions = positions, .records = records_key }, total);
        return total;
    }

    fn isPossibleSolution(self: HotSprings, proposed: []KnownRecord) bool {
        if (self.records.len != proposed.len) {
            return false;
        }

        for (0..self.records.len) |i| {
            const record = self.records[i];
            const proposed_item = proposed[i];

            if (record != .Unknown and @intFromEnum(record) != @intFromEnum(proposed_item)) {
                return false;
            }
        }

        const groups = Groups.identify(proposed, self.allocator) catch {
            return false;
        };
        defer groups.deinit();

        return std.mem.eql(u8, self.positions, groups.positions);
    }
};

test "HotSprings.isPossibleSolution will identify a correctly solution" {
    var records = [7]Record{
        .Unknown,
        .Unknown,
        .Unknown,
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
    };

    var positions = [3]u8{ 1, 1, 3 };
    const hot_springs = HotSprings{
        .allocator = std.testing.allocator,
        .positions = positions[0..],
        .records = records[0..],
    };

    var proposed = [7]KnownRecord{ .Damaged, .Operational, .Damaged, .Operational, .Damaged, .Damaged, .Damaged };

    const is_valid_solution = hot_springs.isPossibleSolution(proposed[0..]);
    try std.testing.expect(is_valid_solution);
}

test "HotSprings.isPossibleSolution will identify a solution that does not have the correct groupings" {
    var records = [7]Record{
        .Unknown,
        .Unknown,
        .Unknown,
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
    };

    var positions = [3]u8{ 1, 1, 3 };
    const hot_springs = HotSprings{
        .allocator = std.testing.allocator,
        .positions = positions[0..],
        .records = records[0..],
    };

    var proposed = [7]KnownRecord{ .Operational, .Damaged, .Damaged, .Operational, .Damaged, .Damaged, .Damaged };

    const is_valid_solution = hot_springs.isPossibleSolution(proposed[0..]);
    try std.testing.expect(!is_valid_solution);
}

test "HotSprings.isPossibleSolution will identify a solution that has the incorrect known records" {
    var records = [8]Record{
        .Unknown,
        .Unknown,
        .Unknown,
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
    };

    var positions = [3]u8{ 1, 1, 3 };
    const hot_springs = HotSprings{
        .allocator = std.testing.allocator,
        .positions = positions[0..],
        .records = records[0..],
    };

    var proposed = [8]KnownRecord{ .Damaged, .Operational, .Damaged, .Operational, .Operational, .Damaged, .Damaged, .Damaged };

    const is_valid_solution = hot_springs.isPossibleSolution(proposed[0..]);
    try std.testing.expect(!is_valid_solution);
}

test "HotSprings.isPossibleSolution will identify a solution that has the incorrect amount of records" {
    var records = [8]Record{
        .Unknown,
        .Unknown,
        .Unknown,
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
    };

    var positions = [3]u8{ 1, 1, 3 };
    const hot_springs = HotSprings{
        .allocator = std.testing.allocator,
        .positions = positions[0..],
        .records = records[0..],
    };

    var proposed = [7]KnownRecord{ .Damaged, .Operational, .Damaged, .Operational, .Damaged, .Damaged, .Damaged };

    const is_valid_solution = hot_springs.isPossibleSolution(proposed[0..]);
    try std.testing.expect(!is_valid_solution);
}

test "HotSprings.isPossibleSolution will reecognize multiple possible solutions for a problem with multiple solutions" {
    // ?###???????? 3,2,1
    var records = [12]Record{
        .Unknown,
        .Damaged,
        .Damaged,
        .Damaged,
        .Unknown,
        .Unknown,
        .Unknown,
        .Unknown,
        .Unknown,
        .Unknown,
        .Unknown,
        .Unknown,
    };

    var positions = [3]u8{ 3, 2, 1 };
    const hot_springs = HotSprings{
        .allocator = std.testing.allocator,
        .positions = positions[0..],
        .records = records[0..],
    };

    var _proposed_1 = [12]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
        .Operational,
        .Operational,
        .Operational,
    };
    const proposed_1 = _proposed_1[0..];

    var _proposed_2 = [12]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Damaged,
        .Operational,
        .Operational,
    };
    const proposed_2 = _proposed_2[0..];

    var _proposed_3 = [12]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Operational,
        .Damaged,
        .Operational,
    };
    const proposed_3 = _proposed_3[0..];

    var _proposed_4 = [12]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Operational,
        .Operational,
        .Damaged,
    };
    const proposed_4 = _proposed_4[0..];

    var _proposed_5 = [12]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
        .Operational,
        .Operational,
    };
    const proposed_5 = _proposed_5[0..];

    var _proposed_6 = [12]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Damaged,
        .Operational,
    };
    const proposed_6 = _proposed_6[0..];

    var _proposed_7 = [12]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Operational,
        .Damaged,
    };
    const proposed_7 = _proposed_7[0..];

    var _proposed_8 = [12]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
        .Operational,
    };
    const proposed_8 = _proposed_8[0..];

    var _proposed_9 = [12]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Damaged,
    };
    const proposed_9 = _proposed_9[0..];

    var _proposed_10 = [12]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Damaged,
        .Operational,
        .Operational,
        .Operational,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
    };
    const proposed_10 = _proposed_10[0..];

    const proposed = [10][]KnownRecord{
        proposed_1,
        proposed_2,
        proposed_3,
        proposed_4,
        proposed_5,
        proposed_6,
        proposed_7,
        proposed_8,
        proposed_9,
        proposed_10,
    };

    for (proposed) |prop| {
        const is_valid_solution = hot_springs.isPossibleSolution(prop[0..]);
        try std.testing.expect(is_valid_solution);
    }
}

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

        var idx: u8 = 0;
        while (true) {
            const group = Group.identify(proposed, idx);

            // Ends with undamaged hot springs
            if (group.len == 0) {
                break;
            }

            try group_list.append(group);
            try position_list.append(group.len);

            const next_index = group.start + group.len;
            // We've gotten to the end - it ends with a damaged hot springs
            if (next_index >= proposed.len) {
                break;
            }

            if (proposed[next_index] != .Operational) {
                unreachable;
            }

            idx = next_index + 1;
        }

        const groups = try group_list.toOwnedSlice();
        const positions = try position_list.toOwnedSlice();

        return Groups{ .groups = groups, .positions = positions, .allocator = allocator };
    }
};

test "Groups.identify identify one group with trailing operational hot springs" {
    var known_records = [4]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
    };

    var want_groups = [1]Group{
        Group{
            .start = 1,
            .len = 2,
        },
    };

    var want_positions = [1]u8{2};
    const want = Groups{
        .allocator = std.testing.allocator,
        .groups = want_groups[0..],
        .positions = want_positions[0..],
    };

    const got = try Groups.identify(known_records[0..], std.testing.allocator);
    defer got.deinit();

    try std.testing.expectEqualDeep(want.positions, got.positions);
    try std.testing.expectEqualDeep(want.groups, got.groups);
}

test "Groups.identify identify one group with ends with damaged hot springs" {
    var known_records = [3]KnownRecord{
        .Operational,
        .Damaged,
        .Damaged,
    };

    var want_groups = [1]Group{
        Group{
            .start = 1,
            .len = 2,
        },
    };

    var want_positions = [1]u8{2};
    const want = Groups{
        .allocator = std.testing.allocator,
        .groups = want_groups[0..],
        .positions = want_positions[0..],
    };

    const got = try Groups.identify(known_records[0..], std.testing.allocator);
    defer got.deinit();

    try std.testing.expectEqualDeep(want.positions, got.positions);
    try std.testing.expectEqualDeep(want.groups, got.groups);
}

test "Groups.identify identify 2 groups starting with damaged hot springs" {
    var known_records = [4]KnownRecord{
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
    };

    var want_groups = [2]Group{
        Group{
            .start = 0,
            .len = 2,
        },
        Group{
            .start = 3,
            .len = 1,
        },
    };

    var want_positions = [2]u8{ 2, 1 };
    const want = Groups{
        .allocator = std.testing.allocator,
        .groups = want_groups[0..],
        .positions = want_positions[0..],
    };

    const got = try Groups.identify(known_records[0..], std.testing.allocator);
    defer got.deinit();

    try std.testing.expectEqualDeep(want.positions, got.positions);
    try std.testing.expectEqualDeep(want.groups, got.groups);
}

test "Groups.identify identify multiple groups" {
    var known_records = [8]KnownRecord{
        .Operational,
        .Damaged,
        .Operational,
        .Damaged,
        .Damaged,
        .Operational,
        .Damaged,
        .Operational,
    };

    var want_groups = [3]Group{
        Group{
            .start = 1,
            .len = 1,
        },
        Group{
            .start = 3,
            .len = 2,
        },
        Group{
            .start = 6,
            .len = 1,
        },
    };

    var want_positions = [3]u8{ 1, 2, 1 };
    const want = Groups{
        .allocator = std.testing.allocator,
        .groups = want_groups[0..],
        .positions = want_positions[0..],
    };

    const got = try Groups.identify(known_records[0..], std.testing.allocator);
    defer got.deinit();

    try std.testing.expectEqualDeep(want.positions, got.positions);
    try std.testing.expectEqualDeep(want.groups, got.groups);
}

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
