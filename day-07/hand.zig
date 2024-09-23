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

pub const JOKER_SPECIAL_VALUE: u8 = 1;
pub const JOKER_NORMAL_VALUE = 11;
pub const ACE_VALUE: u8 = 14;
pub const KING_VALUE: u8 = 13;
pub const QUEEN_VALUE: u8 = 12;
pub const TEN_VALUE: u8 = 10;

pub const HAND_SIZE = 5;

const HandCountValues = struct {
    highest_count: usize,
    second_highest_count: usize,
};

const HandCountValuesWithJokers = struct {
    highest_count: usize,
    second_highest_count: usize,
    num_jokers: usize,
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

    fn getTopTwoWithJokers(cards: [HAND_SIZE]Card) HandCountValuesWithJokers {
        var hand_count = HandCount{
            .values = .{ 0, 0, 0, 0, 0 },
            .counts = .{ 0, 0, 0, 0, 0 },
        };
        for (cards) |card| {
            hand_count.insert(card.value);
        }

        return hand_count.getHighestCountsWithJokers(cards);
    }

    fn getHighestCountsWithJokers(self: HandCount, cards: [HAND_SIZE]Card) HandCountValuesWithJokers {
        var num_jokers: u8 = 0;
        for (cards) |card| {
            if (card.value == JOKER_SPECIAL_VALUE) {
                num_jokers += 1;
            }
        }
        // std.debug.print("{}: ", .{num_jokers});
        // for (cards) |card| {
        //     std.debug.print("{} ", .{card.value});
        // }
        // std.debug.print("\n", .{});

        var highest_count: usize = 0;
        var highest_count_index: usize = 0;

        var second_highest_count: usize = 0;
        var second_highest_count_index: usize = 0;

        for (self.counts, 0..) |count, i| {
            if (count > highest_count) {
                second_highest_count = highest_count;
                second_highest_count_index = highest_count_index;

                highest_count = count;
                highest_count_index = i;
            } else if (count > second_highest_count) {
                second_highest_count = count;
                second_highest_count_index = i;
            }
        }

        const hcv_with_jokers = HandCountValuesWithJokers{
            .highest_count = highest_count,
            .second_highest_count = second_highest_count,
            .num_jokers = num_jokers,
        };
        return hcv_with_jokers;
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

pub const HandError = error{CardError};
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
                    1 => {
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

        std.debug.print("', '{}')", .{self.bid});
        if (self.value != null) {
            std.debug.print(", T: {}\n", .{self.value.?.hand_type});
        } else {
            std.debug.print("\n", .{});
        }
    }

    pub fn new(values: [HAND_SIZE]u8, bid: u32) HandError!Hand {
        var cards: [HAND_SIZE]Card = undefined;

        for (0..HAND_SIZE) |i| {
            const value = values[i];
            cards[i] = Card.new(value) catch {
                return HandError.CardError;
            };
        }

        const hand = Hand{ .bid = bid, .cards = cards, .value = null };

        return hand;
    }

    pub fn newWithJokers(values: [HAND_SIZE]u8, bid: u32) HandError!Hand {
        var cards: [HAND_SIZE]Card = undefined;

        for (0..HAND_SIZE) |i| {
            const value = values[i];
            cards[i] = Card.newWithJokers(value) catch {
                return HandError.CardError;
            };
        }
        const hand = Hand{ .bid = bid, .cards = cards, .value = null };

        return hand;
    }

    fn determineHandValue(self: *Hand) HandValue {
        if (self.*.value != null) {
            return self.*.value.?;
        }

        const hand_count = HandCount.getTopTwo(self.cards);
        const hand_type = determineHandType(hand_count);

        const value = HandValue{ .hand_type = hand_type, .cards = self.cards };
        self.*.value = value;

        return value;
    }

    fn determineHandType(hcv: HandCountValues) HandType {
        if (hcv.highest_count == 5) {
            return HandType.FiveOAK;
        } else if (hcv.highest_count == 4) {
            return HandType.FourOAK;
        } else if (hcv.highest_count == 3 and hcv.second_highest_count == 2) {
            return HandType.FullHouse;
        } else if (hcv.highest_count == 3) {
            return HandType.ThreeOAK;
        } else if (hcv.highest_count == 2 and hcv.second_highest_count == 2) {
            return HandType.TwoPair;
        } else if (hcv.highest_count == 2) {
            return HandType.OnePair;
        } else {
            return HandType.HighCard;
        }
    }

    fn determineHandValueWithJokers(self: *Hand) HandValue {
        if (self.*.value != null) {
            return self.*.value.?;
        }

        const hand_count = HandCount.getTopTwoWithJokers(self.cards);
        const hand_type: HandType = determineHandTypeWithJokers(hand_count);

        const value = HandValue{ .hand_type = hand_type, .cards = self.cards };
        self.*.value = value;

        return value;
    }

    fn determineHandTypeWithJokers(hcv: HandCountValuesWithJokers) HandType {
        //  Five of a kind
        if (hcv.highest_count == 5) {
            return HandType.FiveOAK;
        }

        // Four of a kind
        if (hcv.highest_count == 4) {
            // AAAAJ
            if (hcv.num_jokers > 0) {
                return HandType.FiveOAK;
            } else {
                return HandType.FourOAK;
            }
        }

        // Full house
        if (hcv.highest_count == 3 and hcv.second_highest_count == 2) {
            // If we have any jokers they must be either highest or second count
            // So they can all wildcard into the other slot
            if (hcv.num_jokers > 0) {
                return HandType.FiveOAK;
            } else {
                return HandType.FullHouse;
            }
        }

        // Three of a kind
        if (hcv.highest_count == 3) {
            if (hcv.num_jokers == 0) {
                // 777AQ
                return HandType.ThreeOAK;
            } else {
                // We cannot have two jokers because that would get caught by full house above
                // Therefore we either have JJJQA (three jokers) or QQQJA (one joker), which
                // both result in four of a kind.
                return HandType.FourOAK;
            }
        }

        // Two pair
        if (hcv.highest_count == 2 and hcv.second_highest_count == 2) {
            if (hcv.num_jokers == 0) {
                return HandType.TwoPair;
            } else if (hcv.num_jokers == 1) {
                return HandType.FullHouse;
            } else {
                return HandType.FourOAK;
            }
        }

        // One pair
        if (hcv.highest_count == 2) {
            if (hcv.num_jokers == 0) {
                // AAQ7K
                return HandType.OnePair;
            } else {
                // AAQ7J
                return HandType.ThreeOAK;
            }
        }

        if (hcv.num_jokers > 0) {
            // 1234J
            return HandType.OnePair;
        }

        return HandType.HighCard;
    }

    pub fn isBetter(self: *Hand, other: *Hand) bool {
        const my_hand_value = self.determineHandValue();
        const other_hand_value = other.determineHandValue();
        return my_hand_value.isGreater(other_hand_value);
    }

    pub fn isBetterWithJokers(self: *Hand, other: *Hand) bool {
        const my_hand_value = self.determineHandValueWithJokers();
        const other_hand_value = other.determineHandValueWithJokers();
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
            'A' => return Card{ .value = ACE_VALUE },
            'K' => return Card{ .value = KING_VALUE },
            'Q' => return Card{ .value = QUEEN_VALUE },
            'J' => return Card{ .value = JOKER_NORMAL_VALUE },
            'T' => return Card{ .value = TEN_VALUE },
            else => return CardError.InvalidValue,
        }
    }

    pub fn newWithJokers(value: u8) !Card {
        if (value >= '2' and value <= '9') {
            return Card{ .value = value - '0' };
        }

        switch (value) {
            'A' => return Card{ .value = ACE_VALUE },
            'K' => return Card{ .value = KING_VALUE },
            'Q' => return Card{ .value = QUEEN_VALUE },
            'J' => return Card{ .value = JOKER_SPECIAL_VALUE },
            'T' => return Card{ .value = TEN_VALUE },
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
