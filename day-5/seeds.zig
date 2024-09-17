const std = @import("std");

const Map = @import("map.zig").Map;

const SEEDS_HEADER: []const u8 = "seeds: "[0..];

pub const SeedsError = error{ ParsingError, HeaderError };
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

    pub fn fromString(src: []u8, allocator: std.mem.Allocator) !Seeds {
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
                try seeds_list.append(latest_seed);
                latest_seed = 0;
                continue;
            }

            if (letter < '0' or letter > '9') {
                return SeedsError.ParsingError;
            }

            latest_seed = latest_seed * 10 + letter - '0';

            if (i == src.len - 1) {
                try seeds_list.append(latest_seed);
            }
        }

        const seeds = try seeds_list.toOwnedSlice();
        return Seeds{ .seeds = seeds, .allocator = allocator };
    }

    pub fn applyMaps(self: Seeds, maps: []Map) void {
        for (self.seeds, 0..) |seed, i| {
            for (maps) |map| {
                if (seed >= map.source and seed < map.source + map.len) {
                    const offset = seed - map.source;
                    self.seeds[i] = map.destination + offset;
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
