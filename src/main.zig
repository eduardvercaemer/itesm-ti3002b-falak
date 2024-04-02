const std = @import("std");

const MAX_FILE_SIZE = 1_000_000;

const Keyword = enum {
    k_break,
    k_elseif,
    k_return,
    k_dec,
    k_false,
    k_true,
    k_do,
    k_if,
    k_var,
    k_else,
    k_inc,
    k_while,
};

const Literal = union(enum) {
    boolean: bool,
    integer: i32,
    character: []const u8,
    string: []const u8,
};

const Token = union(enum) {
    identifier: []const u8,
    keyword: Keyword,
    literal: Literal,
    comment: []const u8,
};

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    const file = try std.fs.cwd().readFileAlloc(allocator, "README.md", MAX_FILE_SIZE);
    std.debug.print("file: {s}\n", .{file});
}
