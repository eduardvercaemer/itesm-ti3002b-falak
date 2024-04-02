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

var file: []const u8 = undefined;
var tokens: std.ArrayList(Token) = undefined;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) {
        return error.BadArguments;
    }

    file = try std.fs.cwd().readFileAlloc(allocator, args[1], MAX_FILE_SIZE);
    tokens = std.ArrayList(Token).init(allocator);

    try read_tokens();
}

fn read_tokens() !void {
    const S = struct {
        var offset: usize = 0;
        fn comment() void {}
    };

    while (S.offset < file.len) {
        const at = file[S.offset];
        switch (at) {
            else => return error.MissingTokenHandler,
        }
    }
}
