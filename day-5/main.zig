const std = @import("std");

const root = @import("root.zig");
const Seeds = @import("seeds.zig").Seeds;
const Map = @import("map.zig").Map;

const SEED_TO_SOIL_HEADER: []const u8 = "seed-to-soil map:"[0..];
const SOIL_TO_FERTILIZER_HEADER: []const u8 = "soil-to-fertilizer map:"[0..];
const FERTILIZER_TO_WATER_HEADER: []const u8 = "fertilizer-to-water map:"[0..];
const WATER_TO_LIGHT_HEADER: []const u8 = "water-to-light map:"[0..];
const LIGHT_TO_TEMPERATURE_HEADER: []const u8 = "light-to-temperature map:"[0..];
const TEMPERATURE_TO_HUMIDITY_HEADER: []const u8 = "temperature-to-humidity map:"[0..];
const HUMIDITY_TO_LOCATION_HEADER: []const u8 = "humidity-to-location map:"[0..];
const HEADERS = [7][]const u8{
    SEED_TO_SOIL_HEADER,
    SOIL_TO_FERTILIZER_HEADER,
    FERTILIZER_TO_WATER_HEADER,
    WATER_TO_LIGHT_HEADER,
    LIGHT_TO_TEMPERATURE_HEADER,
    TEMPERATURE_TO_HUMIDITY_HEADER,
    HUMIDITY_TO_LOCATION_HEADER,
};

const LocationDeterminationError = error{FileFormatError};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inputs = try std.fs.cwd().openFile("test_input.txt", .{ .mode = .read_only });
    defer inputs.close();

    const seeds = try determineLocationNumber(inputs, allocator);
    defer seeds.deinit();

    seeds.print();
}

fn determineLocationNumber(file: std.fs.File, allocator: std.mem.Allocator) !Seeds {
    const seed_data = try root.readLine(file, allocator);
    if (seed_data.done) {
        return LocationDeterminationError.FileFormatError;
    }

    var seeds = try Seeds.fromString(seed_data.data, allocator);

    const empty_line = try root.readLine(file, allocator);
    if (empty_line.done or !std.mem.eql(u8, empty_line.data, "")) {
        return LocationDeterminationError.FileFormatError;
    }

    for (HEADERS) |header| {
        std.debug.print("{s}\n", .{header});
        const maps = try readMaps(file, allocator, header);
        seeds.applyMaps(maps);
        std.debug.print("\n", .{});
    }

    return seeds;
}

fn readMaps(file: std.fs.File, allocator: std.mem.Allocator, header: []const u8) ![]Map {
    const header_line = try root.readLine(file, allocator);
    if (header_line.done or !std.mem.eql(u8, header_line.data, header)) {
        return LocationDeterminationError.FileFormatError;
    }

    var map_list = std.ArrayList(Map).init(allocator);
    defer map_list.deinit();

    while (true) {
        const content_line = try root.readLine(file, allocator);
        if (content_line.done or std.mem.eql(u8, content_line.data, "")) {
            break;
        }

        const map = try Map.fromString(content_line.data);
        try map_list.append(map);
    }

    return try map_list.toOwnedSlice();
}
