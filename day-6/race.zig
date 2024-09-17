const std = @import("std");

pub const RaceError = error{ ParsingError, ReadError };

pub const Race = struct {
    distance: u16,
    time: u16,

    pub fn getDistanceTraveled(time_held: u16, max_time: u16) u32 {
        const time_traveling: u16 = max_time - time_held;
        return time_traveling * time_held;
    }

    pub fn getHeldTimesSuperiorToDistance(self: Race, allocator: std.mem.Allocator) ![]usize {
        var held_time_list = std.ArrayList(usize).init(allocator);
        defer held_time_list.deinit();

        for (0..self.time) |time| {
            const got = getDistanceTraveled(time, self.time);
            if (got > self.distance) {
                try held_time_list.append(time);
            }
        }

        return held_time_list.toOwnedSlice();
    }
};

test "Race.getDistanceTraveled 0/7 seconds held" {
    const got = Race.getDistanceTraveled(0, 7);
    try std.testing.expectEqual(0, got);
}

test "Race.getDistanceTraveled 1/7 seconds held" {
    const got = Race.getDistanceTraveled(1, 7);
    try std.testing.expectEqual(6, got);
}

test "Race.getDistanceTraveled 4/7 seconds held" {
    const got = Race.getDistanceTraveled(4, 7);
    try std.testing.expectEqual(12, got);
}

test "Race.getDistanceTraveled 6/7 seconds held" {
    const got = Race.getDistanceTraveled(6, 7);
    try std.testing.expectEqual(6, got);
}

test "Race.getDistanceTraveled 7/7 seconds held" {
    const got = Race.getDistanceTraveled(7, 7);
    try std.testing.expectEqual(0, got);
}

const TIME_HEADER: []const u8 = "Time:"[0..];
const DISTANCE_HEADER: []const u8 = "Distance:"[0..];

pub const Races = struct {
    races: []Race,
    allocator: std.mem.Allocator,

    pub fn fromFile(file: std.fs.File, allocator: std.mem.Allocator) !Races {
        const time_list = std.ArrayList(u16).init(allocator);
        defer time_list.deinit();

        const buf = allocator.alloc(u8, 1);
        defer allocator.free(buf);

        const time_header_buf = try allocator.alloc(u8, TIME_HEADER.len);
        var data_read = try file.read(time_header_buf);
        if (data_read != TIME_HEADER.len or !std.mem.eql(u8, time_header_buf, TIME_HEADER)) {
            return RaceError.ReadError;
        }

        var time: u16 = 0;
        while (true) {
            data_read = try file.read(buf);
            if (buf[0] == ' ') {
                if (time != 0) {
                    try time_list.append(time);
                    time = 0;
                }

                continue;
            }

            if (buf[0] == '\n') {
                break;
            }

            if (data_read == 0 or buf[0] < '0' or buf[0] > '9') {
                return RaceError.ReadError;
            }

            time = time * 10 + buf[0] - '0';
        }

        const distance_list = std.ArrayList(u16).init(allocator);
        defer distance_list.deinit();

        const distance_header_buf = try allocator.alloc(u8, DISTANCE_HEADER.len);
        data_read = try file.read(distance_header_buf);
        if (data_read != DISTANCE_HEADER.len or !std.mem.eql(u8, time_header_buf, DISTANCE_HEADER)) {
            return RaceError.ReadError;
        }

        var distance: u16 = 0;
        while (true) {
            data_read = try file.read(buf);
            if (buf[0] == ' ') {
                if (time != 0) {
                    try distance_list.append(distance);
                    distance = 0;
                }

                continue;
            }

            if (data_read == 0) {
                break;
            }

            if (buf[0] < '0' or buf[0] > '9') {
                return RaceError.ReadError;
            }

            distance = distance * 10 + buf[0] - '0';
        }

        const distances = try distance_list.toOwnedSlice();
        const times = try time_list.toOwnedSlice();

        const races = try Races.fromData(distances, times, allocator);
        allocator.free(distances);
        allocator.free(times);

        return races;
    }

    fn fromData(distances: []u16, times: []u16, allocator: std.mem.Allocator) !Races {
        var race_list = std.ArrayList(Race).init(allocator);
        defer race_list.deinit();

        if (distances.len != times.len) {
            return RaceError.ParsingError;
        }

        for (0..distances.len) |i| {
            const race = Race{
                .distance = distances[i],
                .time = times[i],
            };

            race_list.append(race);
        }

        const races = try race_list.toOwnedSlice();

        return Races{ .races = races, .allocator = allocator };
    }
};
