const std = @import("std");

pub const MapError = error{ UnableToFindLocation, LengthKeys };

pub const MapItemName = [3]u8;
pub const MapItem = struct {
    left: MapItemName,
    right: MapItemName,
};

pub const MapState = struct {
    current_location: MapItemName,
    current_instruction_index: usize,
    steps_taken: usize,
    instructions: Instructions,
    map: Map,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *MapState) void {
        self.allocator.free(self.instructions.instructions);
        self.map.map.deinit();
    }

    pub fn new(instructions: []u8, keys: []MapItemName, lefts: []MapItemName, rights: []MapItemName, allocator: std.mem.Allocator) !MapState {
        if (keys.len != lefts.len and lefts.len != rights.len) {
            return MapError.LengthKeys;
        }

        const parsed_instructions = try Instructions.parse(instructions, allocator);
        var map = Map.new(allocator);
        for (0..keys.len) |i| {
            try map.insert(keys[i], lefts[i], rights[i]);
        }

        return MapState{
            .map = map,
            .instructions = parsed_instructions,
            .current_location = MapItemName{ 'A', 'A', 'A' },
            .steps_taken = 0,
            .current_instruction_index = 0,
            .allocator = allocator,
        };
    }

    pub fn advanceToEnd(self: *MapState) !void {
        while (try self.advance()) {}
    }

    /// Returns whether the map state can continue or not
    pub fn advance(self: *MapState) !bool {
        if (std.mem.eql(u8, &self.current_location, "ZZZ")) {
            return false;
        }

        const instruction = try self.instructions.get(self.current_instruction_index);
        const next_location = try self.map.navigate(self.current_location, instruction);

        self.steps_taken += 1;
        self.current_instruction_index = (self.current_instruction_index + 1) % self.instructions.length();
        self.current_location = next_location;

        std.debug.print("{} steps - instruction {}: {any} to {s}\n", .{ self.steps_taken, self.current_instruction_index, instruction, next_location });

        return true;
    }
};

pub const InstructionsError = error{ AllocationError, ParsingError, IndexError };
pub const Instruction = enum { Right, Left };
pub const Instructions = struct {
    instructions: []Instruction,

    pub fn deinit(self: Instructions) void {
        self.allocator.free(self.instructions);
    }

    pub fn length(self: Instructions) usize {
        return self.instructions.len;
    }

    pub fn get(self: Instructions, idx: usize) InstructionsError!Instruction {
        if (idx >= self.instructions.len) {
            return InstructionsError.IndexError;
        }
        return self.instructions[idx];
    }

    pub fn parse(input: []u8, allocator: std.mem.Allocator) InstructionsError!Instructions {
        var instructions_list = std.ArrayList(Instruction).initCapacity(allocator, input.len) catch {
            return InstructionsError.AllocationError;
        };
        defer instructions_list.deinit();

        for (input) |letter| {
            if (letter == 'R') {
                instructions_list.append(Instruction.Right) catch {
                    return InstructionsError.AllocationError;
                };
            } else if (letter == 'L') {
                instructions_list.append(Instruction.Left) catch {
                    return InstructionsError.AllocationError;
                };
            } else {
                return InstructionsError.ParsingError;
            }
        }

        const instructions = instructions_list.toOwnedSlice() catch {
            return InstructionsError.AllocationError;
        };
        return Instructions{ .instructions = instructions };
    }
};

pub const Map = struct {
    map: std.AutoHashMap(MapItemName, MapItem),

    pub fn new(allocator: std.mem.Allocator) Map {
        return Map{ .map = std.AutoHashMap(MapItemName, MapItem).init(allocator) };
    }

    pub fn insert(self: *Map, key: MapItemName, left: MapItemName, right: MapItemName) !void {
        const map_item = MapItem{ .left = left, .right = right };
        try self.map.put(key, map_item);
    }

    pub fn navigate(self: Map, location: MapItemName, instruction: Instruction) MapError!MapItemName {
        const options = self.map.get(location);
        if (options == null) {
            return MapError.UnableToFindLocation;
        }

        if (instruction == .Left) {
            return options.?.left;
        } else {
            return options.?.right;
        }
    }
};
