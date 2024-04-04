const std = @import("std");
const Token = @import("lexer.zig").Token;
const Program = @import("parser.zig").Program;

pub const Context = struct {
    file: []const u8,
    allocator: std.mem.Allocator,
    tokens: std.ArrayList(Token),
    program: Program,
};
