const std = @import("std");
const Token = @import("lexer.zig").Token;
const Program = @import("parser.zig").Program;

pub const Context = struct {
    file: []const u8,
    allocator: std.mem.Allocator,
    // lexer
    tokens: std.ArrayList(Token),
    // parser
    program: Program,
    symbols: std.ArrayList([]const u8),
    message: ?[]const u8,
};
