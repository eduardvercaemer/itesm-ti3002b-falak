const Token = @import("lexer.zig").Token;
const std = @import("std");

pub const Context = struct {
    file: []const u8,
    allocator: std.mem.Allocator,
    tokens: std.ArrayList(Token),
};
