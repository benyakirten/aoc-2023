const std = @import("std");

const Map = @import("map.zig").Map;

const SEEDS_HEADER: []const u8 = "seeds: "[0..];

pub const SeedsError = error{ ParsingError, HeaderError, AllocationError };
pub const Seeds = struct {
    seeds: []usize,
    allocator: std.mem.Allocator,

    pub fn print(self: Seeds) void {
        std.debug.print("Seeds: ", .{});
        for (self.seeds) |seed| {
            std.debug.print("{d} ", .{seed});
        }
        std.debug.print("\n", .{});
    }

    pub fn deinit(self: Seeds) void {
        self.allocator.free(self.seeds);
    }

    pub fn fromString(src: []u8, allocator: std.mem.Allocator) SeedsError!Seeds {
        const header_length = SEEDS_HEADER.len;
        const header = src[0..header_length];
        if (!std.mem.eql(u8, header, SEEDS_HEADER)) {
            return SeedsError.HeaderError;
        }

        var seeds_list = std.ArrayList(usize).init(allocator);
        defer seeds_list.deinit();

        var latest_seed: usize = 0;
        for (src[header_length..], header_length..) |letter, i| {
            if (letter == ' ') {
                seeds_list.append(latest_seed) catch {
                    return SeedsError.AllocationError;
                };
                latest_seed = 0;
                continue;
            }

            if (letter < '0' or letter > '9') {
                return SeedsError.ParsingError;
            }

            latest_seed = latest_seed * 10 + letter - '0';

            if (i == src.len - 1) {
                seeds_list.append(latest_seed) catch {
                    return SeedsError.AllocationError;
                };
            }
        }

        const seeds = seeds_list.toOwnedSlice() catch {
            return SeedsError.AllocationError;
        };
        return Seeds{ .seeds = seeds, .allocator = allocator };
    }

    pub fn applyMaps(self: Seeds, maps: []Map) void {
        for (self.seeds, 0..) |seed, i| {
            map_loop: for (maps) |map| {
                if (seed >= map.source and seed < map.source + map.len) {
                    const offset = seed - map.source;
                    self.seeds[i] = map.destination + offset;
                    break :map_loop;
                }
            }
        }
    }
};

test "applyMaps mutates the seeds by the map if they are a part of the map" {
    var seed_data = [5]usize{ 0, 1, 2, 3, 4 };
    const seeds = Seeds{ .seeds = seed_data[0..], .allocator = std.testing.allocator };

    var maps_data = [1]Map{Map{ .source = 2, .destination = 15, .len = 2 }};
    const maps: []Map = maps_data[0..];

    seeds.applyMaps(maps);

    var want = [5]usize{ 0, 1, 15, 16, 4 };
    try std.testing.expectEqualDeep(seeds.seeds, want[0..]);
}

test "applyMaps will only transform the base value" {
    var seed_data = [5]usize{ 0, 1, 2, 3, 4 };
    const seeds = Seeds{ .seeds = seed_data[0..], .allocator = std.testing.allocator };

    var maps_data = [2]Map{
        Map{ .source = 2, .destination = 15, .len = 3 },
        Map{ .source = 15, .destination = 25, .len = 2 },
    };
    const maps: []Map = maps_data[0..];

    seeds.applyMaps(maps);

    var want = [5]usize{ 0, 1, 15, 16, 17 };
    try std.testing.expectEqualDeep(seeds.seeds, want[0..]);
}

pub const SeedRange = struct {
    start: usize,
    len: usize,
};

pub const SeedRanges = struct {
    seed_ranges: []SeedRange,
    allocator: std.mem.Allocator,

    pub fn deinit(self: SeedRanges) void {
        self.allocator.free(self.seed_ranges);
    }

    pub fn fromString(src: []u8, allocator: std.mem.Allocator) SeedsError!SeedRanges {
        const header_length = SEEDS_HEADER.len;
        const header = src[0..header_length];
        if (!std.mem.eql(u8, header, SEEDS_HEADER)) {
            return SeedsError.HeaderError;
        }

        var seed_range_list = std.ArrayList(SeedRange).init(allocator);
        defer seed_range_list.deinit();

        var latest_start: usize = 0;
        var latest_length: usize = 0;
        var parsing_seed_start = true;

        for (src[header_length..], header_length..) |letter, i| {
            if (letter == ' ') {
                if (!parsing_seed_start) {
                    const seed_range = SeedRange{
                        .len = latest_length,
                        .start = latest_start,
                    };
                    seed_range_list.append(seed_range) catch {
                        return SeedsError.AllocationError;
                    };

                    latest_start = 0;
                    latest_length = 0;
                }

                parsing_seed_start = !parsing_seed_start;
                continue;
            }

            if (letter < '0' or letter > '9') {
                return SeedsError.ParsingError;
            }

            const val = letter - '0';
            if (parsing_seed_start) {
                latest_start = latest_start * 10 + val;
            } else {
                latest_length = latest_length * 10 + val;
            }

            if (i == src.len - 1) {
                const seed_range = SeedRange{
                    .len = latest_length,
                    .start = latest_start,
                };
                seed_range_list.append(seed_range) catch {
                    return SeedsError.AllocationError;
                };
            }
        }

        const seed_ranges = seed_range_list.toOwnedSlice() catch {
            return SeedsError.AllocationError;
        };
        return SeedRanges{ .seed_ranges = seed_ranges, .allocator = allocator };
    }

    pub fn applyMaps(self: SeedRanges, maps: []Map) !SeedRanges {
        var seed_range_list = std.ArrayList(SeedRange).init(self.allocator);
        defer seed_range_list.deinit();

        for (self.seed_ranges, 0..) |seed_range, i| {
            var range_overwritten = false;
            std.debug.print("\nON RANGE {}\n", .{i + 1});

            map_loop: for (maps) |map| {
                const fragments = try RangeFragments.fragmentIntoRanges(seed_range, map, self.allocator);
                std.debug.print("Map applied: ", .{});
                if (fragments.ranges != null) {
                    std.debug.print("Yes, into:\n", .{});
                    for (fragments.ranges.?) |range| {
                        std.debug.print("Start: {}, Len: {}\n", .{ range.start, range.len });
                        try seed_range_list.append(range);
                    }
                    range_overwritten = true;
                    break :map_loop;
                } else {
                    std.debug.print("No\n\n", .{});
                }
            }

            std.debug.print("\n", .{});

            if (!range_overwritten) {
                const realloced_seed_range = SeedRange{ .len = seed_range.len, .start = seed_range.start };
                try seed_range_list.append(realloced_seed_range);
            }
        }

        const seed_ranges = try seed_range_list.toOwnedSlice();
        defer self.deinit();

        return SeedRanges{ .seed_ranges = seed_ranges, .allocator = self.allocator };
    }
};

const RangeFragments = struct {
    ranges: ?[]SeedRange,

    fn fragmentIntoRanges(seed_range: SeedRange, map: Map, allocator: std.mem.Allocator) !RangeFragments {
        std.debug.print("MAP: DEST {} SRC {} LEN {}\n", .{ map.destination, map.source, map.len });
        std.debug.print("RANGE: START {} LEN {}\n", .{ seed_range.start, seed_range.len });

        // Situation: No overlap in ranges
        // Range:   <--->
        // Map  :          <------>
        // Outcome: no change
        if ((seed_range.start > map.source + map.len - 1) or seed_range.start + seed_range.len - 1 < map.source) {
            std.debug.print("No overlap\n", .{});
            return RangeFragments{
                .ranges = null,
            };
        }

        // Situation: The map entirely contains the seed range or they overlap 1:1
        // Range:   <--->     / <--->
        // Map  : <---------> / <--->
        // Outcome: 1 range where the range.start is the map.destination but the range.len is unchanged
        if (map.source <= seed_range.start and map.len >= seed_range.len) {
            std.debug.print("Map contians range\n", .{});
            var ranges = try allocator.alloc(SeedRange, 1);
            ranges[0] = SeedRange{ .len = seed_range.len, .start = map.destination + seed_range.start - map.source };

            return RangeFragments{ .ranges = ranges };
        }

        // Situation: The seed range entirely contains the map
        // Range: <--------->
        // Map  :   <--->
        // Outcome: 3 ranges
        //  1. Seed range until the map (untransformed)
        //  2. Seed range transformed by the maps
        //  3. Seed range after the map (untransformed)
        if (seed_range.start < map.source and seed_range.start + seed_range.len > map.source + map.len) {
            std.debug.print("Range contains map\n", .{});
            var ranges = try allocator.alloc(SeedRange, 3);
            ranges[0] = SeedRange{ .start = seed_range.start, .len = map.source - seed_range.start };
            ranges[1] = SeedRange{ .start = map.destination, .len = map.len };
            ranges[2] = SeedRange{ .start = map.source + map.len, .len = (seed_range.start + seed_range.len) - (map.source + map.len) };

            return RangeFragments{ .ranges = ranges };
        }

        // Situation: range.start < map.source and (range.start + range.len) <= (map.source + map.len)
        // Range: <----->
        // Map  :    <---->
        // Outcome: 2 ranges
        //  1. Seed range until the map (untransfored)
        //  2. Seed range transformed by the map
        if (seed_range.start < map.source and (seed_range.start + seed_range.len) <= (map.source + map.len)) {
            std.debug.print("Range starts before map and ends before/same\n", .{});
            var ranges = try allocator.alloc(SeedRange, 2);
            const non_overlapping_len = map.source - seed_range.start;
            ranges[0] = SeedRange{ .start = seed_range.start, .len = non_overlapping_len };
            ranges[1] = SeedRange{ .start = map.destination, .len = seed_range.len - non_overlapping_len };

            return RangeFragments{ .ranges = ranges };
        }

        // Situation: range.start <= map.source and (range.start + range.len> > (map.source + map.len)
        // Range:    <----->
        // Map  :  <---->
        // Outcome: 2 ranges
        //  1. Seed range transformed by map
        //  2. Seed range after the map (untransformed)
        if (seed_range.start >= map.source and (seed_range.start + seed_range.len) > (map.source + map.len)) {
            std.debug.print("Range starts after map and ends before/same\n", .{});
            var ranges = try allocator.alloc(SeedRange, 2);
            const affected_len = map.len - (seed_range.start - map.source);
            ranges[0] = SeedRange{ .start = map.destination + seed_range.start - map.source, .len = affected_len };
            ranges[1] = SeedRange{ .start = map.source + map.len, .len = seed_range.len - affected_len };

            return RangeFragments{ .ranges = ranges };
        }

        // If my logic isn't sound, this should trigger.
        unreachable;
    }
};
