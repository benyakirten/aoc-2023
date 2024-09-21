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
            ',' => TileType.Ground,
            else => unreachable,
        };
    }
};

pub const TracerError = error{ImpossibleMovement};
pub const Tracer = struct {
    position: Position,
    distance: usize,
    last_movement_delta: Delta,

    fn new(position: Position, delta: Delta) Tracer {
        return Tracer{ .position = position, .last_movement_delta = delta, .distance = 1 };
    }

    fn moveToEnd(self: *Tracer, map: Map) !void {
        while (self.moveForward(map)) {}
    }

    fn moveForward(self: *Tracer, map: Map) !bool {
        const tile_type = try map.getTileByPosition(self.position);

        const new_delta: ?Delta = null;
        if (tile_type == TileType.BottomLeft) {
            if (self.delta.direction == .Horizontal and self.last_movement_delta.movement == .Negative) {
                //  ⬆
                //  L <-
                new_delta = Delta{
                    .direction = .Vertical,
                    .movement = .Positive,
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
                    .movement = .Positive,
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
                    .movement = .Negative,
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
                    .movement = .Negative,
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

        const new_position = Map.getNextPosition(self.position, new_delta);
        if (new_position == null) {
            return TracerError.ImpossibleMovement;
        }

        self.position = new_position.?;
        self.last_movement_delta = new_delta.?;
        self.distance += 1;

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

        const row_list = try std.ArrayList([]TileType).initCapacity(allocator, INITIAL_LINE_SIZE);
        defer row_list.deinit();

        const column_list = try std.ArrayList(TileType).initCapacity(allocator, INITIAL_LINE_SIZE);
        defer column_list.deinit();

        var x = 0;
        var y = 0;

        var origin: ?Position = null;

        for (content, 0..) |letter, i| {
            if (letter == '\n' or i == content.len - 1) {
                const col = try column_list.toOwnedSlice();
                column_list.clearAndFree();

                y += 1;
                x = 0;

                try row_list.append(col);
            } else {
                const tile_type = TileType.fromChar(letter);

                if (tile_type == TileType.Ground) {
                    origin = Position{
                        .x = x,
                        .y = x,
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

    pub fn findMaxDistance(self: Map) !usize {
        for (DELTA_PERMUTATIONS) |delta| {
            const position = self.getNextPosition(self.origin, delta);
            if (position != null and self.positionIsValid(position, delta)) {
                var tracer = Tracer.new(position.?, delta);
                try tracer.moveToEnd(self);

                return tracer.distance / 2;
            }
        }

        return MapError.NoViablePathFromOrigin;
    }

    fn positionIsValid(self: Map, position: Position, delta: Delta) bool {
        // TODO: What is an elegant way of not having to invoke this method twice?
        // The method has low overhead, but it's still inelegant that we invokve it twice
        const position_change = delta.toPositionChange();

        const tile_type = self.getTileByPosition(position) catch {
            return false;
        };

        if (tile_type == TileType.Ground) {
            return false;
        }

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
        if (tile_type == TileType.TopLeft and (position_change.x == -1 or position_change.y == 1)) {
            return false;
        }

        return true;
    }

    fn getTileByPosition(self: Map, position: Position) MapError!TileType {
        if (position.y >= self.map.len) {
            return MapError.ImpossibleYPosition;
        }

        const col = self.map[position.y];
        if (position.x >= col.len) {
            return MapError.ImpossibleXPosition;
        }

        return col[position.x];
    }

    fn getNextPosition(position: Position, delta: Delta) ?Position {
        const position_change = delta.toPositionChange();

        if (position.x + position_change.x < 0 or position.y + position_change.y < 0) {
            return null;
        }
        const pos = Position{
            .x = position.x + position_change.x,
            .y = position.y + position_change.y,
        };

        return pos;
    }
};
