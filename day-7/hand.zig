const std = @import("std");

// OAK means of a Kind
pub const HandType = enum(u8) {
    FiveOAK = 7,
    FourOAK = 6,
    FullHouse = 5,
    ThreeOAK = 4,
    TwoPair = 3,
    OnePair = 2,
    HighCard = 1,
};

const HAND_SIZE = 5;

const HandCountValues = struct {
    highest_count: usize,
    second_highest_count: usize,
};

const HandCountError = error{HandSizeTooBig};
const HandCount = struct {
    values: [HAND_SIZE]u8,
    counts: [HAND_SIZE]u8,

    fn getTopTwo(cards: [HAND_SIZE]Card) HandCountValues {
        var hand_count = HandCount{
            .values = .{ 0, 0, 0, 0, 0 },
            .counts = .{ 0, 0, 0, 0, 0 },
        };
        for (cards) |card| {
            hand_count.insert(card.value);
        }

        return hand_count.getHighestCounts();
    }

    fn insert(self: *HandCount, value: u8) void {
        for (0..HAND_SIZE) |i| {
            if (self.*.values[i] == 0) {
                self.*.values[i] = value;
                self.*.counts[i] = 1;
                return;
            }

            if (self.*.values[i] == value) {
                self.*.counts[i] += 1;
                return;
            }
        }
    }

    fn getHighestCounts(self: HandCount) HandCountValues {
        var highest_count: usize = 0;
        var second_highest_count: usize = 0;

        for (self.counts) |count| {
            if (count > highest_count) {
                second_highest_count = highest_count;
                highest_count = count;
            } else if (count > second_highest_count) {
                second_highest_count = count;
            }
        }

        return HandCountValues{ .highest_count = highest_count, .second_highest_count = second_highest_count };
    }
};

pub const HandValue = struct {
    cards: [HAND_SIZE]Card,
    hand_type: HandType,

    pub fn isGreater(self: HandValue, other: HandValue) bool {
        if (@intFromEnum(self.hand_type) > @intFromEnum(other.hand_type)) {
            return true;
        } else if (@intFromEnum(self.hand_type) < @intFromEnum(other.hand_type)) {
            return false;
        }

        for (0..HAND_SIZE) |i| {
            const my_card = self.cards[i];
            const other_card = other.cards[i];

            switch (my_card.Compare(other_card)) {
                CardComparison.Greater => return true,
                CardComparison.Lesser => return false,
                else => continue,
            }
        }

        return false;
    }
};

pub const Hand = struct {
    cards: [HAND_SIZE]Card,
    bid: u32,
    value: ?HandValue,

    pub fn print(self: Hand) void {
        std.debug.print("('", .{});
        for (self.cards) |c| {
            var val: u8 = undefined;
            if (c.value >= 2 and c.value <= 9) {
                val = c.value + '0';
            } else {
                switch (c.value) {
                    14 => {
                        val = 'A';
                    },
                    13 => {
                        val = 'K';
                    },
                    12 => {
                        val = 'Q';
                    },
                    11 => {
                        val = 'J';
                    },
                    10 => {
                        val = 'T';
                    },
                    else => {
                        val = c.value;
                    },
                }
            }

            std.debug.print("{c}", .{val});
        }

        std.debug.print("', '{}')\n", .{self.bid});
        if (self.value != null) {
            std.debug.print(", T: {}\n", .{self.value.?.hand_type});
        } else {
            std.debug.print("\n", .{});
        }
    }

    pub fn new(values: [HAND_SIZE]u8, bid: u32) !Hand {
        var cards: [HAND_SIZE]Card = undefined;

        for (0..HAND_SIZE) |i| {
            const value = values[i];
            cards[i] = try Card.new(value);
        }

        const hand = Hand{ .bid = bid, .cards = cards, .value = null };

        return hand;
    }

    pub fn newWithJokers(values: [HAND_SIZE]u8, bid: u32) !Hand {
        var cards: [HAND_SIZE]Card = undefined;

        for (0..HAND_SIZE) |i| {
            const value = values[i];
            cards[i] = try Card.newWithJokers(value);
        }

        const hand = Hand{ .bid = bid, .cards = cards, .value = null };

        return hand;
    }

    fn determineHandValue(self: *Hand) HandValue {
        if (self.*.value != null) {
            return self.*.value.?;
        }

        const hand_count = HandCount.getTopTwo(self.cards);

        var hand_type: HandType = undefined;
        if (hand_count.highest_count == 5) {
            hand_type = HandType.FiveOAK;
        } else if (hand_count.highest_count == 4) {
            hand_type = HandType.FourOAK;
        } else if (hand_count.highest_count == 3 and hand_count.second_highest_count == 2) {
            hand_type = HandType.FullHouse;
        } else if (hand_count.highest_count == 3) {
            hand_type = HandType.ThreeOAK;
        } else if (hand_count.highest_count == 2 and hand_count.second_highest_count == 2) {
            hand_type = HandType.TwoPair;
        } else if (hand_count.highest_count == 2) {
            hand_type = HandType.OnePair;
        } else {
            hand_type = HandType.HighCard;
        }

        const value = HandValue{ .hand_type = hand_type, .cards = self.cards };
        self.*.value = value;

        return value;
    }

    pub fn isBetter(self: *Hand, other: *Hand) bool {
        const my_hand_value = self.determineHandValue();
        const other_hand_value = other.determineHandValue();
        return my_hand_value.isGreater(other_hand_value);
    }
};

pub const CardError = error{InvalidValue};

pub const CardComparison = enum {
    Greater,
    Equal,
    Lesser,
};

pub const Card = struct {
    value: u8,

    pub fn new(value: u8) !Card {
        if (value >= '2' and value <= '9') {
            return Card{ .value = value - '0' };
        }

        switch (value) {
            'A' => return Card{ .value = 14 },
            'K' => return Card{ .value = 13 },
            'Q' => return Card{ .value = 12 },
            'J' => return Card{ .value = 11 },
            'T' => return Card{ .value = 10 },
            else => return CardError.InvalidValue,
        }
    }

    pub fn newWithJokers(value: u8) !Card {
        if (value >= '2' and value <= '9') {
            return Card{ .value = value - '0' };
        }

        switch (value) {
            'A' => return Card{ .value = 14 },
            'K' => return Card{ .value = 13 },
            'Q' => return Card{ .value = 12 },
            'J' => return Card{ .value = 1 },
            'T' => return Card{ .value = 10 },
            else => return CardError.InvalidValue,
        }
    }

    pub fn Compare(self: Card, other: Card) CardComparison {
        if (self.value > other.value) {
            return CardComparison.Greater;
        } else if (self.value < other.value) {
            return CardComparison.Lesser;
        } else {
            return CardComparison.Equal;
        }
    }
};
