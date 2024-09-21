const std = @import("std");

// Rather than using the terms of north/south/east/west,
// I'm stupid and would rather up down left and right.
pub const TileType = enum(u8) {
    Vertical = '|',
    Horizontal = '-',
    BottomLeft = 'L',
    BottomRight = 'J',
    TopLeft = 'F',
    TopRight = '7',
    Start = 'S',
    Ground = '.',

    pub fn fromChar(char: u8) TileType {
        return switch (char) {
            'S' => TileType.Start,
            '|' => TileType.Vertical,
            '-' => TileType.Horizontal,
            'L' => TileType.BottomLeft,
            'J' => TileType.BottomRight,
            '7' => TileType.TopRight,
            'F' => TileType.TopLeft,
            '.' => TileType.Ground,
            else => unreachable,
        };
    }
};

pub const TracerError = error{ImpossibleMovement};
pub const Tracer = struct {
    position: Position,
    distance: usize,
    last_movement_delta: Delta,
    traversed_positions: std.ArrayList(Position),

    fn new(position: Position, delta: Delta, traversed_positions: std.ArrayList(Position)) Tracer {
        return Tracer{ .position = position, .last_movement_delta = delta, .distance = 1, .traversed_positions = traversed_positions };
    }

    pub fn deinit(self: Tracer) void {
        self.traversed_positions.deinit();
    }

    fn moveToEnd(self: *Tracer, map: Map) !void {
        while (try self.moveForward(map)) {}
    }

    fn moveForward(self: *Tracer, map: Map) !bool {
        const tile_type = try map.getTileByPosition(self.position);

        var new_delta: ?Delta = null;
        if (tile_type == TileType.BottomLeft) {
            if (self.last_movement_delta.direction == .Horizontal and self.last_movement_delta.movement == .Negative) {
                //  ⬆
                //  L <-
                new_delta = Delta{
                    .direction = .Vertical,
                    .movement = .Negative,
                };
            } else if (self.last_movement_delta.direction == .Vertical and self.last_movement_delta.movement == .Positive) {
                // ⬇
                // L ->
                new_delta = Delta{
                    .direction = .Horizontal,
                    .movement = .Positive,
                };
            }
        } else if (tile_type == TileType.BottomRight) {
            if (self.last_movement_delta.direction == .Horizontal and self.last_movement_delta.movement == .Positive) {
                //     ⬆
                //  -> J
                new_delta = Delta{
                    .direction = .Vertical,
                    .movement = .Negative,
                };
            } else if (self.last_movement_delta.direction == .Vertical and self.last_movement_delta.movement == .Positive) {
                //     ⬇
                //  <- J
                new_delta = Delta{
                    .direction = .Horizontal,
                    .movement = .Negative,
                };
            }
        } else if (tile_type == TileType.TopLeft) {
            if (self.last_movement_delta.direction == .Vertical and self.last_movement_delta.movement == .Negative) {
                //     F ->
                //     ⬆
                new_delta = Delta{
                    .direction = .Horizontal,
                    .movement = .Positive,
                };
            } else if (self.last_movement_delta.direction == .Horizontal and self.last_movement_delta.movement == .Negative) {
                //     F <-
                //     ⬇
                new_delta = Delta{
                    .direction = .Vertical,
                    .movement = .Positive,
                };
            }
        } else if (tile_type == TileType.TopRight) {
            if (self.last_movement_delta.direction == .Vertical and self.last_movement_delta.movement == .Negative) {
                //  <- 7
                //     ⬆
                new_delta = Delta{
                    .direction = .Horizontal,
                    .movement = .Negative,
                };
            } else if (self.last_movement_delta.direction == .Horizontal and self.last_movement_delta.movement == .Positive) {
                //  -> F
                //     ⬇
                new_delta = Delta{
                    .direction = .Vertical,
                    .movement = .Positive,
                };
            }
        } else if (tile_type == TileType.Horizontal) {
            if (self.last_movement_delta.direction == .Horizontal and self.last_movement_delta.movement == .Positive) {
                //  -> | ->
                new_delta = Delta{
                    .direction = .Horizontal,
                    .movement = .Positive,
                };
            } else if (self.last_movement_delta.direction == .Horizontal and self.last_movement_delta.movement == .Negative) {
                //  <- | <-
                new_delta = Delta{
                    .direction = .Horizontal,
                    .movement = .Negative,
                };
            }
        } else if (tile_type == TileType.Vertical) {
            if (self.last_movement_delta.direction == .Vertical and self.last_movement_delta.movement == .Positive) {
                //  ⬆
                //  |
                //  ⬆
                new_delta = Delta{
                    .direction = .Vertical,
                    .movement = .Positive,
                };
            } else if (self.last_movement_delta.direction == .Vertical and self.last_movement_delta.movement == .Negative) {
                //  ⬇
                //  |
                //  ⬇
                new_delta = Delta{
                    .direction = .Vertical,
                    .movement = .Negative,
                };
            }
        }

        if (new_delta == null) {
            return TracerError.ImpossibleMovement;
        }

        const new_position = Map.getNextPosition(self.position, new_delta.?);
        if (new_position == null) {
            return TracerError.ImpossibleMovement;
        }

        self.position = new_position.?;
        self.last_movement_delta = new_delta.?;
        self.distance += 1;

        try self.traversed_positions.append(self.position);

        return try map.getTileByPosition(self.position) != TileType.Start;
    }
};

pub const Position = struct {
    x: usize,
    y: usize,
};

const PositionChange = struct {
    x: i8,
    y: i8,
};

// Use enums to prevent impossible representations of data - only left down up and right
// Even though this gets boiled down to a deltaY and deltaX
const DeltaBearing = enum { Vertical, Horizontal };
const DeltaMovement = enum {
    Positive,
    Negative,
};
const Delta = struct {
    direction: DeltaBearing,
    movement: DeltaMovement,

    fn toPositionChange(self: Delta) PositionChange {
        var deltaX: i8 = if (self.direction == DeltaBearing.Horizontal) 1 else 0;
        var deltaY: i8 = if (self.direction == DeltaBearing.Vertical) 1 else 0;

        // Up/left is negative movement, down/right is positive movement
        if (self.movement == DeltaMovement.Negative) {
            deltaX *= -1;
            deltaY *= -1;
        }

        return PositionChange{ .x = deltaX, .y = deltaY };
    }
};

const DELTA_PERMUTATIONS = [4]Delta{
    Delta{
        .direction = .Horizontal,
        .movement = .Negative,
    },
    Delta{
        .direction = .Horizontal,
        .movement = .Positive,
    },
    Delta{
        .direction = .Vertical,
        .movement = .Negative,
    },
    Delta{
        .direction = .Vertical,
        .movement = .Positive,
    },
};

const MapError = error{
    NoOrigin,
    OriginError,
    NoViablePathFromOrigin,
    ImpossibleYPosition,
    ImpossibleXPosition,
    ImpossibleMove,
};

// I know the file is 20kb so ~1mb should be fine
const MAX_BUFFER_SIZE = 1_000_000;
const INITIAL_LINE_SIZE = 200;
pub const Map = struct {
    map: [][]TileType,
    origin: Position,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Map) void {
        for (self.map) |row| {
            self.allocator.free(row);
        }

        self.allocator.free(self.map);
    }

    pub fn parse(file: std.fs.File, allocator: std.mem.Allocator) !Map {
        const content = try file.readToEndAlloc(allocator, MAX_BUFFER_SIZE);
        defer allocator.free(content);

        var row_list = try std.ArrayList([]TileType).initCapacity(allocator, INITIAL_LINE_SIZE);
        defer row_list.deinit();

        var column_list = try std.ArrayList(TileType).initCapacity(allocator, INITIAL_LINE_SIZE);
        defer column_list.deinit();

        var x: usize = 0;
        var y: usize = 0;

        var origin: ?Position = null;

        for (content, 0..) |letter, i| {
            if (letter == '\n' or i == content.len - 1) {
                if (i == content.len - 1) {
                    const tile_type = TileType.fromChar(letter);
                    try column_list.append(tile_type);
                }

                y += 1;
                x = 0;

                const col = try column_list.toOwnedSlice();
                column_list.clearAndFree();

                try row_list.append(col);
            } else {
                const tile_type = TileType.fromChar(letter);
                if (tile_type == TileType.Start) {
                    origin = Position{
                        .x = x,
                        .y = y,
                    };
                }
                x += 1;

                try column_list.append(tile_type);
            }
        }

        if (origin == null) {
            return MapError.NoOrigin;
        }

        const map = try row_list.toOwnedSlice();
        return Map{ .map = map, .origin = origin.?, .allocator = allocator };
    }

    pub fn traversePath(self: Map) !Tracer {
        for (DELTA_PERMUTATIONS) |delta| {
            const position = getNextPosition(self.origin, delta);
            if (position != null and self.movementIsValid(position.?, delta)) {
                var traversed_positions = std.ArrayList(Position).init(self.allocator);
                try traversed_positions.append(position.?);

                var tracer = Tracer.new(position.?, delta, traversed_positions);
                try tracer.moveToEnd(self);

                return tracer;
            }
        }

        return MapError.NoViablePathFromOrigin;
    }

    fn movementIsValid(self: Map, position: Position, delta: Delta) bool {
        const tile_type = self.getTileByPosition(position) catch {
            return false;
        };

        if (tile_type == TileType.Ground) {
            return false;
        }

        // TODO: Find a way to consolidate this and the Tracer.moveForward method
        const position_change = delta.toPositionChange();

        // Cannot move horizontally into a vertical pipe.
        // i.e. ->|
        if (tile_type == TileType.Vertical and position_change.x != 0) {
            return false;
        }

        // Cannot move vertically into a horizontal pipe.
        //  i.e. --
        //       ⬆
        if (tile_type == TileType.Horizontal and position_change.y != 0) {
            return false;
        }

        // Cannot move right or up to bottom left piece
        // i.e. ->L
        //        ⬆
        if (tile_type == TileType.BottomLeft and (position_change.x == 1 or position_change.y == -1)) {
            return false;
        }

        // Cannot move left or up to bottom right piece
        // i.e. J<-
        //      ⬆
        if (tile_type == TileType.BottomRight and (position_change.x == -1 or position_change.y == -1)) {
            return false;
        }

        // Cannot move right or down to top left piece
        // i.e.  ⬇
        //     ->F
        if (tile_type == TileType.TopLeft and (position_change.x == 1 or position_change.y == 1)) {
            return false;
        }

        // Cannot move left or down to top left piece
        // i.e.  ⬇
        //       7<-
        if (tile_type == TileType.TopRight and (position_change.x == -1 or position_change.y == 1)) {
            return false;
        }

        return true;
    }

    fn getTileByPosition(self: Map, position: Position) MapError!TileType {
        if (position.y < 0 or position.y >= self.map.len) {
            return MapError.ImpossibleYPosition;
        }

        const col = self.map[position.y];
        if (position.x < 0 or position.x >= col.len) {
            return MapError.ImpossibleXPosition;
        }

        return col[position.x];
    }

    fn getNextPosition(position: Position, delta: Delta) ?Position {
        const position_change = delta.toPositionChange();

        if (position.x < -1 * position_change.x or position.y < -1 * position_change.y) {
            return null;
        }

        const finalX = if (position_change.x < 0)
            position.x - @as(u8, @intCast(-1 * position_change.x))
        else
            position.x + @as(u8, @intCast(position_change.x));

        const finalY = if (position_change.y < 0)
            position.y - @as(u8, @intCast(-1 * position_change.y))
        else
            position.y + @as(u8, @intCast(position_change.y));

        const pos = Position{
            .x = finalX,
            .y = finalY,
        };

        return pos;
    }

    pub fn locatePotentialDens(self: Map, tracer: Tracer) ![]PotentialDen {
        const all_potential_dens = try self.findPotentialDens();

        const surrounded_dens_list = std.ArrayList(PotentialDen).init(self.allocator);
        defer surrounded_dens_list.deinit();
    }

    fn findPotentialDens(self: Map) ![]PotentialDen {
        var traversed_positions = std.AutoHashMap(Position, bool).init(self.allocator);
        defer traversed_positions.deinit();

        var potential_dens = std.ArrayList(PotentialDen).init(self.allocator);
        defer potential_dens.deinit();

        for (self.map, 0..) |row, i| {
            for (row, 0..) |tile, j| {
                const start_position = Position{ .x = j, .y = i };
                if (tile != TileType.Ground or traversed_positions.get(start_position) != null) {
                    continue;
                }

                std.debug.print("\nSearching from {any}\n", .{start_position});
                const potential_den = try PotentialDen.findFrom(start_position, self);
                for (potential_den.positions) |position| {
                    std.debug.print("Storing {any} to all den positions covered\n", .{position});
                    try traversed_positions.put(position, true);
                }

                if (potential_den.is_valid) {
                    try potential_dens.append(potential_den);
                }
            }
        }

        return potential_dens.toOwnedSlice();
    }
};

const PotentialDen = struct {
    positions: []Position,
    is_valid: bool,
    allocator: std.mem.Allocator,

    fn deinit(self: PotentialDen) void {
        self.allocator.free(self.positions);
    }

    fn findFrom(start: Position, map: Map) !PotentialDen {
        var position_map = std.AutoArrayHashMap(Position, bool).init(map.allocator);
        defer position_map.deinit();

        const is_valid = try findAdjacentGround(start, &position_map, map);

        var position_list = std.ArrayList(Position).init(map.allocator);
        defer position_list.deinit();

        for (position_map.keys()) |pos| {
            try position_list.append(pos);
        }

        return PotentialDen{
            .positions = try position_list.toOwnedSlice(),
            .is_valid = is_valid,
            .allocator = map.allocator,
        };
    }

    fn findAdjacentGround(position: Position, position_map: *std.AutoArrayHashMap(Position, bool), map: Map) !bool {
        std.debug.print("CHECKING {any}\n", .{position});
        if (position_map.get(position) != null) {
            std.debug.print("ALREADY HAVE {any}\n", .{position});
            return true;
        }

        const tile_type = map.getTileByPosition(position) catch {
            std.debug.print("{any} IS NOT A VALID POSITION\n", .{position});
            return false;
        };

        if (tile_type == TileType.Ground) {
            std.debug.print("PUTTING {any} in cache\n", .{position});
            try position_map.put(position, true);
            var is_valid = true;

            for (DELTA_PERMUTATIONS) |delta| {
                const pos = Map.getNextPosition(position, delta);

                if (pos == null) {
                    is_valid = false;
                    continue;
                }

                // Find all adjacent tiles whether or not we're no longer valid.
                const is_next_tile_valid = try PotentialDen.findAdjacentGround(pos.?, position_map, map);
                is_valid = is_valid and is_next_tile_valid;
            }

            return is_valid;
        } else {
            return true;
        }
    }

    fn isSurroundedByPipe(self: PotentialDen, tracer: Tracer) bool {
        //
    }
};
