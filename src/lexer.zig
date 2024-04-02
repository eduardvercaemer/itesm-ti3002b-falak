const std = @import("std");
const Context = @import("context.zig").Context;

pub const LexerError = error{
    UnexpectedEndOfLine,
    UnexpectedEndOfFile,
    UnexpectedSymbol,
    InvalidCharacterLiteral,
    InvalidEscapeSequence,
    OutOfMemory,
    OverFlow,
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
    repr: []const u8,
    value: union(enum) {
        symbol: []const u8,
        keyword: Keyword,
        literal: Literal,
        operator: Operator,
        comment: void,
    },
};

const EscapeSequence = struct {
    start: usize,
    end: usize,
    // TODO: unicode escapes ???
    codepoint: u8,
};

const LexerContext = struct {
    ctx: *Context,
    size: usize,
    line: u32,
    offset: usize,
    runner: usize,
    current: u8,
    escape_sequences: std.ArrayList(EscapeSequence),
};

pub fn lexer(ctx: *Context) LexerError!void {
    var lctx = LexerContext{
        .ctx = ctx,
        .size = ctx.file.len,
        .line = 1,
        .offset = 0,
        .runner = undefined,
        .current = undefined,
        .escape_sequences = std.ArrayList(EscapeSequence).init(ctx.allocator),
    };

    while (lctx.offset < lctx.size) : (lctx.offset += 1) {
        lctx.current = ctx.file[lctx.offset];
        lctx.runner = lctx.offset + 1;

        if (lctx.current == '\n') lctx.line += 1;
        if (isWhitespace(lctx.current)) continue;

        if (lctx.current == '#') {
            try runUntil(&lctx, hasNewline, false, true, true, false);
            try addToken(&lctx, .{ .comment = {} });
            lctx.offset = lctx.runner - 1;
            continue;
        }

        if (isSymbolStart(lctx.current)) {
            // TODO: process keywords
            try runUntil(&lctx, hasSymbolChar, true, true, true, false);
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
                    try runUntil(&lctx, hasPound, false, true, false, false);
                    try expect(&lctx, '>');
                    try addToken(&lctx, .{ .comment = {} });
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
                try runUntil(&lctx, hasDoubleQuote, false, false, false, true);
                const raw = ctx.file[lctx.offset..lctx.runner];
                var encoded = std.ArrayList(u8).init(ctx.allocator);
                var remaining: usize = 1;
                for (lctx.escape_sequences.items) |sequence| {
                    try encoded.appendSlice(raw[remaining..sequence.start]);
                    try encoded.append(sequence.codepoint);
                    remaining = sequence.end;
                }
                if (remaining < raw.len - 1) {
                    try encoded.appendSlice(raw[remaining .. raw.len - 1]);
                }
                try addToken(&lctx, .{ .literal = .{ .string = encoded.items } });
                lctx.offset = lctx.runner - 1;
                continue;
            },
            '\'' => {
                try runUntil(&lctx, hasSingleQuote, false, false, false, true);
                if (lctx.runner - lctx.offset != 3) {
                    // TODO: escapes and multibyte chars
                    return error.InvalidCharacterLiteral;
                }
                try addToken(&lctx, .{ .literal = .{ .character = ctx.file[lctx.offset + 1] } });
                lctx.offset = lctx.runner - 1;
                continue;
            },
            '0'...'9' => {
                try runUntil(&lctx, hasDigit, true, true, true, false);
                try addToken(&lctx, .{ .literal = .{ .integer = try parseI32(ctx.file[lctx.offset..lctx.runner]) } });
                lctx.offset = lctx.runner - 1;
                continue;
            },
            else => {},
        }

        std.debug.print("Unexpected Symbol '{c}'\n", .{lctx.current});
        return error.UnexpectedSymbol;
    }
}

fn addToken(lctx: *LexerContext, value: anytype) !void {
    const token = Token{
        .start = lctx.offset,
        .end = lctx.runner,
        .line = lctx.line,
        .repr = lctx.ctx.file[lctx.offset..lctx.runner],
        .value = value,
    };
    try lctx.ctx.tokens.append(token);
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

fn runUntil(lctx: *LexerContext, cb: *const fn (lctx: *LexerContext) bool, negate: bool, allow_newline: bool, allow_eof: bool, apply_escapes: bool) !void {
    const EscapeState = enum {
        WontEscape,
        Outside,
        Inside,
    };

    if (apply_escapes) {
        lctx.escape_sequences.clearRetainingCapacity();
    }

    var state: EscapeState = if (apply_escapes) .Outside else .WontEscape;

    while (lctx.runner < lctx.size) : (lctx.runner += 1) {
        const runner = lctx.ctx.file[lctx.runner];
        if (runner == '\n') {
            if (allow_newline) {
                lctx.line += 1;
            } else {
                return error.UnexpectedEndOfLine;
            }
        }

        switch (state) {
            .WontEscape => {},
            .Outside => if (runner == '\\') {
                state = .Inside;
            },
            .Inside => {
                switch (runner) {
                    'n', 'r', 't', '\\', '\'', '\"' => |c| {
                        try lctx.escape_sequences.append(.{
                            .start = lctx.runner - lctx.offset - 1,
                            .end = lctx.runner - lctx.offset + 1,
                            .codepoint = switch (c) {
                                'n' => '\n',
                                'r' => '\r',
                                't' => '\t',
                                '\\' => '\\',
                                '\'' => '\'',
                                '\"' => '\"',
                                else => unreachable,
                            },
                        });
                        state = .Outside;
                        continue;
                    },
                    else => return error.InvalidEscapeSequence,
                }
            },
        }

        if ((state != .Inside) and (cb(lctx) != negate)) {
            if (!negate) lctx.runner += 1;
            return;
        }
    }

    if (!allow_eof) return error.UnexpectedEndOfFile;
}

fn hasDigit(lctx: *LexerContext) bool {
    return switch (lctx.ctx.file[lctx.runner]) {
        '0'...'9' => true,
        else => false,
    };
}

fn hasPound(lctx: *LexerContext) bool {
    return lctx.ctx.file[lctx.runner] == '#';
}

fn hasDoubleQuote(lctx: *LexerContext) bool {
    return lctx.ctx.file[lctx.runner] == '"';
}

fn hasSingleQuote(lctx: *LexerContext) bool {
    return lctx.ctx.file[lctx.runner] == '\'';
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

pub fn parseI32(buf: []const u8) !i32 {
    var x: i32 = 0;

    for (buf) |c| {
        const digit = c - '0';

        // x *= radix
        var ov = @mulWithOverflow(x, 10);
        if (ov[1] != 0) return error.OverFlow;

        // x += digit
        ov = @addWithOverflow(ov[0], digit);
        if (ov[1] != 0) return error.OverFlow;
        x = ov[0];
    }

    return x;
}
