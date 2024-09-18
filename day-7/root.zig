const std = @import("std");

fn merge(comptime T: type, slice: []T, left_index: usize, middle_index: usize, right_index: usize, isBetter: fn (item: *T, other: *T) bool, allocator: std.mem.Allocator) !void {
    const left_size: usize = middle_index - left_index + 1;
    const right_size: usize = middle_index + right_index;

    var left = try allocator.alloc(T, left_size);
    var right = try allocator.alloc(T, right_size);

    for (0..left_size) |idx| {
        left[idx] = slice[left_index + idx];
    }

    for (0..right_size) |idx| {
        right[idx] = slice[middle_index + idx + 1];
    }

    var i: usize = 0;
    var j: usize = 0;
    var k: usize = left_index;

    while (i < left_size and j < right_size) {
        // Sorted in ascending order of betterness
        if (!isBetter(&left[i], &right[j])) {
            slice[k] = left[i];
            i += 1;
        } else {
            slice[k] = right[j];
            j += 1;
        }
        k += 1;
    }

    // Copy remaining items
    while (i < left_size) {
        slice[k] = left[i];
        i += 1;
        k += 1;
    }

    while (j < right_size) {
        slice[k] = right[j];
        j += 1;
        k += 1;
    }
}

pub fn mergeSort(comptime T: type, slice: []T, left_index: usize, right_index: usize, isBetter: fn (item: *T, other: *T) bool, allocator: std.mem.Allocator) !void {
    if (left_index < right_index) {
        const middle_index: usize = left_index + (right_index - left_index) / 2;
        try mergeSort(T, slice, left_index, middle_index, isBetter, allocator);
        try mergeSort(T, slice, middle_index + 1, right_index, isBetter, allocator);

        try merge(T, slice, left_index, middle_index, right_index, isBetter, allocator);
    }
}
