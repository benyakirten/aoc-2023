const std = @import("std");

pub const MapError = error{ParsingError};

const CurrentlyParsing = enum {
    Destination,
    Source,
    Len,

    fn advance(self: CurrentlyParsing) CurrentlyParsing {
        const next_state = switch (self) {
            CurrentlyParsing.Destination => CurrentlyParsing.Source,
            CurrentlyParsing.Source => CurrentlyParsing.Len,
            CurrentlyParsing.Len => unreachable,
        };

        return next_state;
    }
};

test "CurrentlyParsing.advance modifies the internal state" {
    var currentlyParsing = CurrentlyParsing.Destination;

    currentlyParsing = currentlyParsing.advance();
    try std.testing.expectEqual(currentlyParsing, CurrentlyParsing.Source);

    currentlyParsing = currentlyParsing.advance();
    try std.testing.expectEqual(currentlyParsing, CurrentlyParsing.Len);
}

pub const Map = struct {
    destination: usize,
    source: usize,
    len: usize,

    pub fn fromString(src: []u8) !Map {
        var currentlyParsing = CurrentlyParsing.Destination;
        var destination: usize = 0;
        var source: usize = 0;
        var len: usize = 0;

        for (src) |letter| {
            if (letter == ' ') {
                currentlyParsing = currentlyParsing.advance();
                continue;
            }

            if (letter < '0' or letter > '9') {
                return MapError.ParsingError;
            }

            const val: u8 = letter - '0';

            switch (currentlyParsing) {
                CurrentlyParsing.Destination => {
                    destination = destination * 10 + val;
                },
                CurrentlyParsing.Source => {
                    source = source * 10 + val;
                },
                CurrentlyParsing.Len => {
                    len = len * 10 + val;
                },
            }
        }

        return Map{ .destination = destination, .source = source, .len = len };
    }
};

test "Map.fromString" {
    var src_list = std.ArrayList(u8).init(std.testing.allocator);
    defer src_list.deinit();
    try src_list.appendSlice("0 35 8"[0..]);

    const src = try src_list.toOwnedSlice();
    defer std.testing.allocator.free(src);

    const got = try Map.fromString(src);
    const want = Map{ .destination = 0, .source = 35, .len = 8 };
    try std.testing.expectEqual(want, got);
}
