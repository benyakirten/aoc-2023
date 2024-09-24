const std = @import("std");

pub const LandType = enum(u8) {
    Rocks = '#',
    Ash = '.',
};

pub const Landscape = struct {
    land: [][]LandType,
    allocator: std.mem.Allocator,
};
