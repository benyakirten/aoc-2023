const std = @import("std");

const Coordinate = struct {
    x: usize,
    y: usize,
};

const Direction = enum {
    Up,
    Down,
    Left,
    Right,
};

// Memoize Dijkstra's algorithm
// NOTE: We want to use a min priority queue
// Can we use Zig's std.PriorityQueue?
// One caveat is that no direction can be followed more than 3 times in a row

const CoordinateQueue = struct {
    const Node = struct {
        coordinate: Coordinate,
        priority: u8,
    };

    heap: []Node,
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, first_coord: Coordinate, first_priority: u8, max_size: usize) !CoordinateQueue {
        const nodes = try allocator.alloc(Node, max_size);
        const node = Node{ .coordinate = first_coord, .priority = first_priority };
        nodes[0] = node;

        return CoordinateQueue{
            .heap = nodes,
            .allocator = allocator,
        };
    }
};

const MapError = error{
    InvalidCharacter,
};
pub const Map = struct {
    position: Coordinate,
    visited: std.AutoHashMap(Coordinate, bool),
    cache: std.AutoHashMap(Coordinate, usize),
    queue: CoordinateQueue,
    area: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Map) void {
        self.allocator.free(self.area);
    }

    pub fn parse(allocator: std.mem.Allocator, content: []const u8) !Map {
        var lines = std.mem.splitSequence(u8, content, "\n");

        var area_list = std.ArrayList([]const u8).init(allocator);
        defer area_list.deinit();

        var line_list = try std.ArrayList(u8).initCapacity(allocator, lines.peek().?.len);
        defer line_list.deinit();

        while (lines.next()) |line| {
            for (line) |char| {
                if (char < '0' or char > '9') {
                    return MapError.InvalidCharacter;
                }

                try line_list.append(char - '0');
            }

            const l = try line_list.toOwnedSlice();
            try area_list.append(l);
            line_list.clearAndFree();
        }

        const start_position = Coordinate{ .x = 0, .y = 0 };
        const area = try area_list.toOwnedSlice();
        const queue = try CoordinateQueue.new(allocator, start_position, area[0][0]);

        var visited = std.AutoHashMap(Coordinate, bool).init(allocator);
        try visited.put(start_position, true);

        return Map{
            .positions = start_position,
            .area = area,
            .cache = std.AutoHashMap(Coordinate, usize).init(allocator),
            .visited = visited,
            .queue = queue,
            .allocator = allocator,
        };
    }
};
