const std = @import("std");
const Context = @import("context.zig").Context;
const Literal = @import("lexer.zig").Literal;

pub const ParserError = error{};

pub const Program = std.ArrayList(Definition);

pub const Definition = union(enum) {
    function: Function,
    globals: std.ArrayList(Sym),
};

pub const Function = struct {
    symbol_id: usize,
    params: std.ArrayList(Sym),
    vars: std.ArrayList(Sym),
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
    left: Expr,
    right: Expr,
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
        expr: Expr,
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

pub fn parser(ctx: *Context) ParserError!void {
    _ = ctx;
}
