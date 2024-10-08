const std = @import("std");

pub const MapError = error{ UnableToFindLocation, LengthKeys };

pub const MapItemName = [3]u8;
pub const MapItem = struct {
    left: MapItemName,
    right: MapItemName,
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

pub const MapStateError = error{
    AllocationError,
    ValidationError,
    ParsingError,
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

    pub fn new(instructions: []u8, keys: []MapItemName, lefts: []MapItemName, rights: []MapItemName, allocator: std.mem.Allocator) MapStateError!MapState {
        if (keys.len != lefts.len and lefts.len != rights.len) {
            return MapStateError.ValidationError;
        }

        const parsed_instructions = Instructions.parse(instructions, allocator) catch {
            return MapStateError.ParsingError;
        };
        var map = Map.new(allocator);
        for (0..keys.len) |i| {
            map.insert(keys[i], lefts[i], rights[i]) catch {
                return MapStateError.AllocationError;
            };
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
    fn advance(self: *MapState) !bool {
        const instruction = try self.instructions.get(self.current_instruction_index);
        const next_location = try self.map.navigate(self.current_location, instruction);

        self.steps_taken += 1;
        self.current_instruction_index = (self.current_instruction_index + 1) % self.instructions.length();
        self.current_location = next_location;

        return !std.mem.eql(u8, &self.current_location, "ZZZ");
    }
};

pub const ParallelMapState = struct {
    current_location: MapItemName,
    current_instruction_index: usize,
    steps_taken: usize,

    pub fn advanceToEnd(self: *ParallelMapState, manager: ParallelMapStateManager) !void {
        while (try self.advance(manager)) {}
    }

    /// Returns whether the map state can continue or not
    fn advance(self: *ParallelMapState, manager: ParallelMapStateManager) !bool {
        const instruction = try manager.instructions.get(self.current_instruction_index);
        const next_location = try manager.map.navigate(self.current_location, instruction);

        self.current_location = next_location;
        self.steps_taken += 1;
        self.current_instruction_index = (self.current_instruction_index + 1) % manager.instructions.length();

        return self.current_location[2] != 'Z';
    }
};

pub const ParallelMapStateManager = struct {
    instructions: Instructions,
    map: Map,
    map_states: []ParallelMapState,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ParallelMapStateManager) void {
        self.allocator.free(self.instructions.instructions);
        self.allocator.free(self.map_states);
        self.map.map.deinit();
    }

    pub fn run(self: *ParallelMapStateManager) !usize {
        try self.map_states[0].advanceToEnd(self.*);
        var least_common_multiple: usize = self.map_states[0].steps_taken;

        for (self.map_states[1..]) |*state| {
            try state.advanceToEnd(self.*);
            const steps_taken = state.steps_taken;
            least_common_multiple = lcm(least_common_multiple, steps_taken);
        }

        return least_common_multiple;
    }

    fn gcd(a: usize, b: usize) usize {
        var x = a;
        var y = b;
        while (y != 0) {
            const temp = y;
            y = x % y;
            x = temp;
        }

        return x;
    }

    fn lcm(a: usize, b: usize) usize {
        return (a * b) / gcd(a, b);
    }

    pub fn new(
        instructions: []u8,
        keys: []MapItemName,
        lefts: []MapItemName,
        rights: []MapItemName,
        allocator: std.mem.Allocator,
    ) MapStateError!ParallelMapStateManager {
        if (keys.len != lefts.len and lefts.len != rights.len) {
            return MapStateError.ValidationError;
        }

        var parallel_map_states = std.ArrayList(ParallelMapState).init(allocator);
        defer parallel_map_states.deinit();

        const parsed_instructions = Instructions.parse(instructions, allocator) catch {
            return MapStateError.ParsingError;
        };
        var map = Map.new(allocator);
        for (0..keys.len) |i| {
            const key = keys[i];
            if (key[2] == 'A') {
                const parallel_map_state = ParallelMapState{
                    .current_location = key,
                    .steps_taken = 0,
                    .current_instruction_index = 0,
                };
                parallel_map_states.append(parallel_map_state) catch {
                    return MapStateError.AllocationError;
                };
            }
            map.insert(key, lefts[i], rights[i]) catch {
                return MapStateError.AllocationError;
            };
        }

        const map_states = parallel_map_states.toOwnedSlice() catch {
            return MapStateError.AllocationError;
        };

        return ParallelMapStateManager{
            .map = map,
            .instructions = parsed_instructions,
            .allocator = allocator,
            .map_states = map_states,
        };
    }
};
