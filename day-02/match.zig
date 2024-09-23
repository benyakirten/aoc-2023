const std = @import("std");

pub const Match = struct {
    red: u8,
    blue: u8,
    green: u8,

    pub fn parseFromString(data: []const u8) !Match {
        var red: u8 = 0;
        var green: u8 = 0;
        var blue: u8 = 0;

        var num: u8 = 0;
        var name_starting_index: u8 = 0;
        var gathering_name: bool = false;

        for (data, 0..) |letter, i| {
            if (gathering_name and (letter == ',' or i == data.len - 1)) {
                var pos: usize = i;
                if (pos == data.len - 1) {
                    pos = pos + 1;
                }

                gathering_name = false;

                const name = data[name_starting_index..pos];
                if (std.mem.eql(u8, name, "red"[0..])) {
                    red = num;
                } else if (std.mem.eql(u8, name, "green"[0..])) {
                    green = num;
                } else if (std.mem.eql(u8, name, "blue"[0..])) {
                    blue = num;
                }

                num = 0;
            }

            if (letter >= 'a' and letter <= 'z') {
                if (!gathering_name) {
                    name_starting_index = @truncate(i);
                    gathering_name = true;
                }

                continue;
            }

            if (letter >= '0' and letter <= '9') {
                num = num * 10 + letter - '0';
            }
        }

        return Match{ .red = red, .green = green, .blue = blue };
    }

    pub fn isValid(self: Match, control: Match) bool {
        return self.blue <= control.blue and
            self.red <= control.red and
            self.green <= control.green;
    }

    pub fn power(self: Match) u32 {
        var total_power: u32 = 1;
        if (self.blue > 0) {
            total_power *= self.blue;
        }

        if (self.green > 0) {
            total_power *= self.green;
        }

        if (self.red > 0) {
            total_power *= self.red;
        }

        if (total_power == 1) {
            total_power = 0;
        }

        return total_power;
    }

    pub fn print(self: Match) void {
        std.debug.print("Match values: red {}, green {}, blue {}\n", .{ self.red, self.green, self.blue });
    }
};

test "Match.isValid true" {
    const control = Match{
        .red = 10,
        .blue = 20,
        .green = 30,
    };

    const match = Match{
        .red = 5,
        .blue = 10,
        .green = 20,
    };

    const isValid = match.isValid(control);
    try std.testing.expect(isValid);
}

test "Match.isValid false" {
    const control = Match{
        .red = 10,
        .blue = 20,
        .green = 30,
    };

    const match = Match{
        .red = 5,
        .blue = 10,
        .green = 200,
    };

    const isValid = match.isValid(control);
    try std.testing.expect(!isValid);
}

test "Match.power all > 1" {
    const match = Match{
        .red = 5,
        .blue = 10,
        .green = 20,
    };

    const got = match.power();
    const want: u32 = @as(u32, match.red) * @as(u32, match.blue) * @as(u32, match.green);
    try std.testing.expectEqual(want, got);
}

test "Match.power all not all > 1" {
    const match = Match{
        .red = 0,
        .blue = 10,
        .green = 20,
    };

    const got = match.power();
    const want: u32 = @as(u32, match.blue) * @as(u32, match.green);
    try std.testing.expectEqual(want, got);
}

test "Match.power all 0" {
    const match = Match{
        .red = 0,
        .blue = 0,
        .green = 0,
    };

    const got = match.power();
    try std.testing.expectEqual(0, got);
}
