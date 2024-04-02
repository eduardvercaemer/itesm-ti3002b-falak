const std = @import("std");

pub const Context = struct {
    file: []const u8,
    allocator: std.mem.Allocator,
    tokens: std.ArrayList(Token),
};

pub const LexerError = error{
    UnexpectedEndOfFile,
    UnexpectedSymbol,
    OutOfMemory,
};

pub const Keyword = enum {
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

pub const Operator = enum {
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

pub const Literal = union(enum) {
    boolean: bool,
    integer: i32,
    // TODO: multi-byte unicode characters ???
    character: u8,
    string: []const u8,
};

pub const Token = struct {
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

const LexerContext = struct {
    ctx: *Context,
    size: usize,
    line: u32,
    offset: usize,
    runner: usize,
    current: u8,
};

pub fn lexer(ctx: *Context) LexerError!void {
    var lctx = LexerContext{
        .ctx = ctx,
        .size = ctx.file.len,
        .line = 1,
        .offset = 0,
        .runner = undefined,
        .current = undefined,
    };

    while (lctx.offset < lctx.size) : (lctx.offset += 1) {
        lctx.current = ctx.file[lctx.offset];
        lctx.runner = lctx.offset + 1;

        if (lctx.current == '\n') lctx.line += 1;
        if (isWhitespace(lctx.current)) continue;

        if (lctx.current == '#') {
            try runUntil(&lctx, hasNewline, false, true, false);
            try addToken(&lctx, .{ .comment = ctx.file[lctx.offset..lctx.runner] });
            lctx.offset = lctx.runner - 1;
            continue;
        }

        if (isSymbolStart(lctx.current)) {
            // TODO: process keywords
            try runUntil(&lctx, hasSymbolChar, true, true, false);
            try addToken(&lctx, .{ .symbol = ctx.file[lctx.offset..lctx.runner] });
            lctx.offset = lctx.runner - 1;
            continue;
        }

        const simpleOp = switch (lctx.current) {
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
            try addToken(&lctx, .{ .operator = operator });
            continue;
        }

        switch (lctx.current) {
            '=' => {
                if (peek(&lctx, '=')) {
                    try expect(&lctx, '=');
                    try addToken(&lctx, .{ .operator = Operator.o_equal });
                    lctx.offset = lctx.runner - 1;
                } else {
                    try addToken(&lctx, .{ .operator = Operator.o_assign });
                }
                continue;
            },
            '!' => {
                if (peek(&lctx, '=')) {
                    try expect(&lctx, '=');
                    try addToken(&lctx, .{ .operator = Operator.o_nequal });
                    lctx.offset = lctx.runner - 1;
                } else {
                    try addToken(&lctx, .{ .operator = Operator.o_not });
                }
                continue;
            },
            '<' => {
                if (peek(&lctx, '=')) {
                    try expect(&lctx, '=');
                    try addToken(&lctx, .{ .operator = Operator.o_ltequal });
                    lctx.offset = lctx.runner - 1;
                } else if (peek(&lctx, '#')) {
                    try expect(&lctx, '#');
                    try runUntil(&lctx, hasPound, false, false, false);
                    try expect(&lctx, '>');
                    try addToken(&lctx, .{ .comment = ctx.file[lctx.offset..lctx.runner] });
                    lctx.offset = lctx.runner - 1;
                    continue;
                } else {
                    try addToken(&lctx, .{ .operator = Operator.o_lt });
                }
                continue;
            },
            '>' => {
                if (peek(&lctx, '=')) {
                    try expect(&lctx, '=');
                    try addToken(&lctx, .{ .operator = Operator.o_gtequal });
                    lctx.offset = lctx.runner - 1;
                } else {
                    try addToken(&lctx, .{ .operator = Operator.o_gt });
                }
                continue;
            },
            '&' => {
                try expect(&lctx, '&');
                try addToken(&lctx, .{ .operator = Operator.o_and });
                lctx.offset = lctx.runner - 1;
                continue;
            },
            '|' => {
                try expect(&lctx, '|');
                try addToken(&lctx, .{ .operator = Operator.o_pipes });
                lctx.offset = lctx.runner - 1;
                continue;
            },
            '"' => {
                try runUntil(&lctx, hasDoubleQuote, false, false, true);
                try addToken(&lctx, .{ .literal = .{ .string = ctx.file[lctx.offset..lctx.runner] } });
                lctx.offset = lctx.runner - 1;
                continue;
            },
            else => {},
        }

        return error.UnexpectedSymbol;
    }
}

fn addToken(lctx: *LexerContext, value: anytype) !void {
    try lctx.ctx.tokens.append(Token{ .start = lctx.offset, .end = lctx.runner, .line = lctx.line, .value = value });
}

fn peek(lctx: *LexerContext, c: u8) bool {
    if (!(lctx.runner < lctx.size)) return false;
    return lctx.ctx.file[lctx.runner] == c;
}

fn expect(lctx: *LexerContext, c: u8) !void {
    if (!(lctx.runner < lctx.size)) return error.UnexpectedEndOfFile;
    if (lctx.ctx.file[lctx.runner] != c) return error.UnexpectedSymbol;
    lctx.runner += 1;
}

fn runUntil(lctx: *LexerContext, cb: *const fn (lctx: *LexerContext) bool, negate: bool, allow_eof: bool, apply_escapes: bool) !void {
    // TODO: apply string literal escapes
    _ = apply_escapes;
    while (lctx.runner < lctx.size) : (lctx.runner += 1) {
        if (lctx.ctx.file[lctx.runner] == '\n') lctx.line += 1;
        if (cb(lctx) != negate) {
            if (!negate) lctx.runner += 1;
            return;
        }
    }

    if (!allow_eof) return error.UnexpectedEndOfFile;
}

fn hasPound(lctx: *LexerContext) bool {
    return lctx.ctx.file[lctx.runner] == '#';
}

fn hasDoubleQuote(lctx: *LexerContext) bool {
    return lctx.ctx.file[lctx.runner] == '"';
}

fn hasNewline(lctx: *LexerContext) bool {
    return lctx.ctx.file[lctx.runner] == '\n';
}

fn hasSymbolChar(lctx: *LexerContext) bool {
    return isSymbolChar(lctx.ctx.file[lctx.runner]);
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
