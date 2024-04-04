const std = @import("std");
const Context = @import("context.zig").Context;
const Literal = @import("lexer.zig").Literal;
const Token = @import("lexer.zig").Token;

pub const ParserError = error{
    UnexpectedToken,
    UnexpectedEndOfFile,
    OutOfMemory,
};

pub const Program = std.ArrayList(Definition);

pub const Definition = union(enum) {
    function: Function,
    globals: std.ArrayList(Sym),
};

pub const Function = struct {
    symbol_id: usize,
    params: std.ArrayList(Sym),
    vars: ?std.ArrayList(Sym),
    stmts: std.ArrayList(Stmt),
};

pub const Sym = struct {
    symbol_id: usize,
};

pub const ExprWithBlock = struct {
    expr: Expr,
    stmts: std.ArrayList(Stmt),
};

pub const FunctionCall = struct {
    function: Sym,
    args: std.ArrayList(Expr),
};

pub const Stmt = union(enum) {
    assign: struct {
        location: Sym,
        expr: Expr,
    },
    inc: Sym,
    dec: Sym,
    call: FunctionCall,
    if_: struct {
        expr: Expr,
        stmts: std.ArrayList(Stmt),
        else_if: ?std.ArrayList(ExprWithBlock),
        else_: ?ExprWithBlock,
    },
    while_: ExprWithBlock,
    do_while: ExprWithBlock,
    break_: void,
    return_: Expr,
    empty: void,
};

pub const BinaryOp = struct {
    left: *Expr,
    right: *Expr,
};

pub const Expr = union(enum) {
    or_: BinaryOp,
    and_: BinaryOp,
    comp: BinaryOp,
    rel: struct {
        op: BinaryOp,
        kind: enum {
            lt,
            lte,
            gt,
            gte,
        },
    },
    add: BinaryOp,
    mul: BinaryOp,
    unary: struct {
        expr: *Expr,
        kind: enum {
            plus,
            neg,
            not,
        },
    },
    ref: Sym,
    call: FunctionCall,
    array: std.ArrayList(Expr),
    literal: Literal,
};

const ParserContext = struct {
    ctx: *Context,
    tokens: []const Token,
    current: ?*const Token,
    size: usize,
    offset: usize,
};

pub fn parser(ctx: *Context) ParserError!void {
    ctx.program = std.ArrayList(Definition).init(ctx.allocator);
    ctx.symbols = std.ArrayList([]const u8).init(ctx.allocator);

    var pctx = ParserContext{
        .ctx = ctx,
        .tokens = ctx.tokens.items,
        .size = ctx.tokens.items.len,
        .offset = 0,
        .current = null,
    };

    while (pctx.offset < pctx.size) : (pctx.offset += 1) {
        pctx.current = &pctx.tokens[pctx.offset];

        std.debug.print("current token: {s} : {s}\n", .{ @tagName(pctx.current.?.value), pctx.current.?.repr });

        switch (pctx.current.?.value) {
            .comment => {},
            .symbol => try functionDefinition(&pctx),
            .keyword => |k| switch (k) {
                .k_var => {},
                else => {
                    ctx.message = try std.fmt.allocPrint(ctx.allocator, "Expected global variable definition. Found {any}.", .{k});
                    return error.UnexpectedToken;
                },
            },
            else => {
                ctx.message = "Expected comment, function definition, or global variable definition.";
                return error.UnexpectedToken;
            },
        }
    }
}

fn functionDefinition(pctx: *ParserContext) ParserError!void {
    const t = try expect(pctx, .symbol);
    const sym = try makeSym(pctx, t.value.symbol);

    try expectOp(pctx, .o_oparen);
    const params = try symList(pctx, true);

    try expectOp(pctx, .o_cparen);
    try expectOp(pctx, .o_ocurly);

    const vars = if (peekKw(pctx, .k_var)) vars: {
        expectKw(pctx, .k_var) catch unreachable;
        const vars = try symList(pctx, false);
        try expectOp(pctx, .o_semi);
        break :vars vars;
    } else null;

    try expectOp(pctx, .o_ccurly);

    const function = Function{
        .params = params,
        .vars = vars,
        .stmts = std.ArrayList(Stmt).init(pctx.ctx.allocator),
        .symbol_id = sym,
    };

    std.debug.print("added function with sym {d}\n", .{sym});

    try pctx.ctx.program.append(.{ .function = function });
}

fn symList(pctx: *ParserContext, allow_empty: bool) ParserError!std.ArrayList(Sym) {
    var list = std.ArrayList(Sym).init(pctx.ctx.allocator);
    if (peek(pctx, .symbol)) {
        const t = expect(pctx, .symbol) catch unreachable;
        const sym = try makeSym(pctx, t.value.symbol);
        try list.append(.{ .symbol_id = sym });
    } else {
        if (allow_empty) {
            return list;
        } else {
            pctx.ctx.message = "List cannot be empty. Expected at least one item.";
            return error.UnexpectedToken;
        }
    }

    while (peekOp(pctx, .o_comma)) {
        expectOp(pctx, .o_comma) catch unreachable;
        const t = expect(pctx, .symbol) catch unreachable;
        const sym = try makeSym(pctx, t.value.symbol);
        try list.append(.{ .symbol_id = sym });
    }

    return list;
}

fn peek(pctx: *ParserContext, comptime token_kind: anytype) bool {
    const t = pctx.current;
    if (t == null) {
        return false;
    }

    switch (t.?.value) {
        inline token_kind => return true,
        else => return false,
    }
}

fn peekOp(pctx: *ParserContext, comptime operator_kind: anytype) bool {
    const t = pctx.current;
    if (t == null) {
        return false;
    }

    switch (t.?.value) {
        .operator => |op| {
            switch (op) {
                operator_kind => return true,
                else => return false,
            }
        },
        else => return false,
    }
}

fn peekKw(pctx: *ParserContext, comptime keyword: anytype) bool {
    const t = pctx.current;
    if (t == null) {
        return false;
    }

    switch (t.?.value) {
        .keyword => |op| {
            switch (op) {
                keyword => return true,
                else => return false,
            }
        },
        else => return false,
    }
}

fn expect(pctx: *ParserContext, comptime token_kind: anytype) ParserError!*const Token {
    const t = pctx.current;
    if (t == null) {
        pctx.ctx.message = try std.fmt.allocPrint(pctx.ctx.allocator, "Expected {any}.", .{token_kind});
        return error.UnexpectedEndOfFile;
    }

    switch (t.?.value) {
        inline token_kind => {
            pctx.offset += 1;
            pctx.current = if (pctx.offset < pctx.size) &pctx.tokens[pctx.offset] else null;
            return t.?;
        },
        else => {
            pctx.ctx.message = try std.fmt.allocPrint(pctx.ctx.allocator, "Expected {any}, found {any}\n", .{
                token_kind,
                @tagName(t.?.value),
            });
            return error.UnexpectedToken;
        },
    }
}

fn expectOp(pctx: *ParserContext, comptime op_kind: anytype) ParserError!void {
    const t = pctx.current;
    if (t == null) {
        pctx.ctx.message = try std.fmt.allocPrint(pctx.ctx.allocator, "Expected {any}.", .{op_kind});
        return error.UnexpectedEndOfFile;
    }

    switch (t.?.value) {
        .operator => |op| {
            switch (op) {
                op_kind => {
                    pctx.offset += 1;
                    pctx.current = if (pctx.offset < pctx.size) &pctx.tokens[pctx.offset] else null;
                },
                else => {
                    pctx.ctx.message = try std.fmt.allocPrint(pctx.ctx.allocator, "Expected operator {any}. Found operator {any}.", .{ op_kind, t.?.value.operator });
                    return error.UnexpectedToken;
                },
            }
        },
        else => {
            pctx.ctx.message = try std.fmt.allocPrint(pctx.ctx.allocator, "Expected operator. Found {any}.", .{t.?.value});
            return error.UnexpectedToken;
        },
    }
}

fn expectKw(pctx: *ParserContext, comptime keyword: anytype) ParserError!void {
    const t = pctx.current;
    if (t == null) {
        pctx.ctx.message = try std.fmt.allocPrint(pctx.ctx.allocator, "Expected {any}.", .{keyword});
        return error.UnexpectedEndOfFile;
    }

    switch (t.?.value) {
        .keyword => |kw| {
            switch (kw) {
                keyword => {
                    pctx.offset += 1;
                    pctx.current = if (pctx.offset < pctx.size) &pctx.tokens[pctx.offset] else null;
                },
                else => {
                    pctx.ctx.message = try std.fmt.allocPrint(pctx.ctx.allocator, "Expected keyword {any}. Found keyword {any}.", .{ kw, t.?.value.operator });
                    return error.UnexpectedToken;
                },
            }
        },
        else => {
            pctx.ctx.message = try std.fmt.allocPrint(pctx.ctx.allocator, "Expected keyword. Found {any}.", .{t.?.value});
            return error.UnexpectedToken;
        },
    }
}

fn makeSym(pctx: *ParserContext, s: []const u8) !usize {
    for (pctx.ctx.symbols.items, 0..) |sym, i| {
        if (string_compare(s, sym)) {
            return i;
        }
    }

    try pctx.ctx.symbols.append(s);
    const id = pctx.ctx.symbols.items.len - 1;
    std.debug.print("interned symbol {d} \"{s}\"\n", .{ id, s });
    return id;
}

fn string_compare(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }

    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) {
            return false;
        }
    }

    return true;
}
