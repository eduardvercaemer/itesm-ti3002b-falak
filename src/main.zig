const std = @import("std");

const MAX_FILE_SIZE = 1_000_000;

const Keyword = enum {
    k_break,
    k_dec,
    k_do,
    k_else,
    k_elseif,
    k_false,
    k_if,
    k_inc,
    k_return,
    k_true,
    k_var,
    k_while,
};

const Operator = enum {
    o_comma,
    o_semi,
    o_oparen,
    o_cparen,
    o_ocurly,
    o_ccurly,
    o_obrack,
    o_cbrack,
    o_assign,
    o_and,
    o_pipes,
    o_xor,
    o_equal,
    o_nequal,
    o_lt,
    o_ltequal,
    o_gt,
    o_gtequal,
    o_plus,
    o_minus,
    o_mul,
    o_div,
    o_mod,
    o_not,
};

const Literal = union(enum) {
    boolean: bool,
    integer: i32,
    // TODO: multi-byte unicode characters ???
    character: u8,
    string: []const u8,
};

const Token = struct {
    line: u32,
    start: usize,
    end: usize,
    value: union(enum) {
        symbol: []const u8,
        keyword: Keyword,
        literal: Literal,
        operator: Operator,
        comment: []const u8,
    },
};

var file: []const u8 = undefined;
var file_size: usize = undefined;
var file_line: u32 = 1;
var file_offset: usize = 0;
var file_runner: usize = undefined;
var current: u8 = undefined;

var tokens: std.ArrayList(Token) = undefined;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) {
        return error.BadArguments;
    }

    file = try std.fs.cwd().readFileAlloc(allocator, args[1], MAX_FILE_SIZE);
    file_size = file.len;
    tokens = std.ArrayList(Token).init(allocator);
    errdefer {
        for (tokens.items) |item| switch (item.value) {
            .comment => |comment| std.debug.print("comment: {s}\n", .{comment}),
            .symbol => |symbol| std.debug.print("symbol: {s}\n", .{symbol}),
            .operator => |op| std.debug.print("op: {any}\n", .{op}),
            .literal => |lit| switch (lit) {
                .string => |string| std.debug.print("string literal: {s}\n", .{string}),
                else => {},
            },
            else => {},
        };
    }

    {
        // LEXER
        while (file_offset < file_size) : (file_offset += 1) {
            current = file[file_offset];
            file_runner = file_offset + 1;

            if (current == '\n') file_line += 1;
            if (isWhitespace(current)) continue;

            if (current == '#') {
                std.debug.print("running single line comment\n", .{});
                try runUntil(hasNewline, false, true, false);
                try addToken(.{ .comment = file[file_offset..file_runner] });
                file_offset = file_runner - 1;
                continue;
            }

            if (isSymbolStart(current)) {
                std.debug.print("running symbol\n", .{});
                try runUntil(hasSymbolChar, true, true, false);
                try addToken(.{ .symbol = file[file_offset..file_runner] });
                file_offset = file_runner - 1;
                continue;
            }

            const simpleOp = switch (current) {
                ',' => Operator.o_comma,
                ';' => Operator.o_semi,
                '(' => Operator.o_oparen,
                ')' => Operator.o_cparen,
                '{' => Operator.o_ocurly,
                '}' => Operator.o_ccurly,
                '[' => Operator.o_obrack,
                ']' => Operator.o_cbrack,
                '^' => Operator.o_xor,
                '+' => Operator.o_plus,
                '-' => Operator.o_minus,
                '*' => Operator.o_mul,
                '/' => Operator.o_div,
                '%' => Operator.o_mod,
                else => null,
            };
            if (simpleOp) |operator| {
                try addToken(.{ .operator = operator });
                continue;
            }

            switch (current) {
                '=' => {
                    if (peek('=')) {
                        try expect('=');
                        try addToken(.{ .operator = Operator.o_equal });
                        file_offset = file_runner - 1;
                    } else {
                        try addToken(.{ .operator = Operator.o_assign });
                    }
                    continue;
                },
                '!' => {
                    if (peek('=')) {
                        try expect('=');
                        try addToken(.{ .operator = Operator.o_nequal });
                        file_offset = file_runner - 1;
                    } else {
                        try addToken(.{ .operator = Operator.o_not });
                    }
                    continue;
                },
                '<' => {
                    std.debug.print("got <\n", .{});
                    if (peek('=')) {
                        try expect('=');
                        try addToken(.{ .operator = Operator.o_ltequal });
                        file_offset = file_runner - 1;
                    } else if (peek('#')) {
                        try expect('#');
                        try runUntil(hasPound, false, false, false);
                        try expect('>');
                        try addToken(.{ .comment = file[file_offset..file_runner] });
                        file_offset = file_runner - 1;
                        continue;
                    } else {
                        try addToken(.{ .operator = Operator.o_lt });
                    }
                    continue;
                },
                '>' => {
                    if (peek('=')) {
                        try expect('=');
                        try addToken(.{ .operator = Operator.o_gtequal });
                        file_offset = file_runner - 1;
                    } else {
                        try addToken(.{ .operator = Operator.o_gt });
                    }
                    continue;
                },
                '&' => {
                    try expect('&');
                    try addToken(.{ .operator = Operator.o_and });
                    file_offset = file_runner - 1;
                    continue;
                },
                '|' => {
                    try expect('|');
                    try addToken(.{ .operator = Operator.o_pipes });
                    file_offset = file_runner - 1;
                    continue;
                },
                '"' => {
                    try runUntil(hasDoubleQuote, false, false, true);
                    try addToken(.{ .literal = .{ .string = file[file_offset..file_runner] } });
                    file_offset = file_runner - 1;
                    continue;
                },
                else => {},
            }

            std.debug.print("no handler\n", .{});
            return error.UnexpectedSymbol;
        }
    }
}

fn addToken(value: anytype) !void {
    try tokens.append(Token{ .start = file_offset, .end = file_runner, .line = file_line, .value = value });
}

fn peek(c: u8) bool {
    if (!(file_runner < file_size)) return false;
    return file[file_runner] == c;
}

fn expect(c: u8) !void {
    if (!(file_runner < file_size)) return error.UnexpectedEndOfFile;
    if (file[file_runner] != c) return error.UnexpectedSymbol;
    file_runner += 1;
}

fn runUntil(cb: *const fn () bool, negate: bool, allow_eof: bool, apply_escapes: bool) !void {
    // TODO: apply string literal escapes
    _ = apply_escapes;
    while (file_runner < file_size) : (file_runner += 1) {
        if (file[file_runner] == '\n') file_line += 1;
        if (cb() != negate) {
            if (!negate) file_runner += 1;
            return;
        }
    }
    if (!allow_eof) return error.UnexpectedEndOfFile;
}

fn hasPound() bool {
    return file[file_runner] == '#';
}

fn hasDoubleQuote() bool {
    return file[file_runner] == '"';
}

fn hasNewline() bool {
    return file[file_runner] == '\n';
}

fn hasSymbolChar() bool {
    return isSymbolChar(file[file_runner]);
}

fn isWhitespace(c: u8) bool {
    return switch (c) {
        '\n', '\r', ' ', '\t' => true,
        else => false,
    };
}

fn isAlpha(c: u8) bool {
    return switch (c) {
        'a'...'z', 'A'...'Z' => true,
        else => false,
    };
}

fn isAlphanum(c: u8) bool {
    return switch (c) {
        'a'...'z', 'A'...'Z', '0'...'9' => true,
        else => false,
    };
}

fn isSymbolStart(c: u8) bool {
    return isAlpha(c);
}

fn isSymbolChar(c: u8) bool {
    return switch (c) {
        'a'...'z', 'A'...'Z', '0'...'9', '_' => true,
        else => false,
    };
}
