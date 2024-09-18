const std = @import("std");

// OAK means of a Kind
pub const HandType = enum(u8) {
    HighCard = 1,
    OnePair = 2,
    TwoPair = 3,
    ThreeOAK = 4,
    FullHouse = 5,
    FourOAK = 6,
    FiveOAK = 7,
};

const HAND_SIZE = 5;

const HandCountError = error{HandSizeTooBig};
const HandCount = struct {
    values: [HAND_SIZE]u8,
    counts: [HAND_SIZE]u8,

    fn new(cards: *[HAND_SIZE]Card) !HandCount {
        const hand_count = HandCount{
            .values = .{ 0, 0, 0, 0, 0 },
            .counts = .{ 0, 0, 0, 0, 0 },
        };
        for (cards) |card| {
            try hand_count.insert(card.*.value);
        }

        hand_count.sortByCount();

        return hand_count;
    }

    fn insert(self: HandCount, value: u8) !void {
        for (0..HAND_SIZE) |i| {
            if (self.values[i] == 0) {
                self.values[i] = value;
                self.counts[i] = 1;
                return;
            }

            if (self.values[i] == value) {
                self.counts[i] += 1;
                return;
            }
        }

        return HandCountError.HandSizeTooBig;
    }

    fn sortByCount(self: HandCount) void {
        var highest_count = 0;
        var highest_count_index: u8 = 0;

        var second_highest_count = 0;
        var second_highest_count_index = 0;

        for (self.counts, 0..) |count, i| {
            if (count > highest_count) {
                if (highest_count > second_highest_count) {
                    second_highest_count = highest_count;
                    second_highest_count_index = highest_count_index;
                }

                highest_count = count;
                highest_count_index = i;
            }
        }

        const swap_value_1 = self.values[0];
        const swap_count_1 = self.counts[0];

        const swap_value_2 = self.values[1];
        const swap_count_2 = self.counts[1];

        self.values[0] = self.values[highest_count_index];
        self.values[highest_count_index] = swap_value_1;

        self.counts[0] = self.counts[highest_count_index];
        self.counts[highest_count_index] = swap_count_1;

        self.values[1] = self.values[highest_count_index];
        self.values[highest_count_index] = swap_value_2;

        self.counts[1] = self.counts[highest_count_index];
        self.counts[highest_count_index] = swap_count_2;
    }
};

pub const HandValue = struct {
    cards: *[HAND_SIZE]Card,
    hand_type: HandType,

    pub fn isGreater(self: HandValue, other: HandValue) bool {
        if (self.hand_type > other.hand_type) {
            return true;
        } else if (self.hand_type < other.hand_type) {
            return false;
        }

        for (0..HAND_SIZE) |i| {
            const my_card = self.cards.*[i];
            const other_card = other.cards.*[i];

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
    allocator: std.mem.Allocator,

    pub fn new(values: [HAND_SIZE]u8) !Hand {
        const hand = Hand{};
        for (0..HAND_SIZE) |i| {
            const value = values[i];
            hand.cards[i] = try Card.new(value);
        }

        return hand;
    }

    pub fn determineHandValue(self: Hand) !HandValue {
        const hand_count = try HandCount.new(&self.cards);

        var hand_type: HandType = undefined;
        if (hand_count.counts[0] == 5) {
            hand_type = HandType.FiveOAK;
        } else if (hand_count.counts[0] == 4) {
            hand_type = HandType.FourOAK;
        } else if (hand_count.counts[0] == 3 and hand_count.counts[1] == 2) {
            hand_type = HandType.FullHouse;
        } else if (hand_count.counts[0] == 3) {
            hand_type = HandType.ThreeOAK;
        } else if (hand_count.counts[0] == 2 and hand_count.counts[1] == 2) {
            hand_type = HandType.TwoPair;
        } else if (hand_count.counts[0] == 2) {
            hand_type = HandType.OnePair;
        } else {
            hand_type = HandType.HighCard;
        }

        return HandValue{ .hand_type = hand_type, .cards = &self.cards };
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
            'A' => return Card{ .value = 13 },
            'K' => return Card{ .value = 12 },
            'Q' => return Card{ .value = 11 },
            'J' => return Card{ .value = 10 },
            else => return CardError.InvalidValue,
        }
    }

    pub fn Compare(self: Card, other: Card) CardComparison {
        if (self.value > other.value) {
            return CardComparison.Greater;
        } else if (self.vlue < other.value) {
            return CardComparison.Lesser;
        } else {
            return CardComparison.Equal;
        }
    }
};
