const std = @import("std");
const Context = @import("context.zig").Context;

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

pub const Stmt = union(enum) {
    assign: struct {
        location: Sym,
        expr: Expr,
    },
    inc: Sym,
    dec: Sym,
    call: struct {
        function: Sym,
        args: std.ArrayList(Expr),
    },
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

pub const Expr = struct {};

pub fn parser(ctx: *Context) ParserError!void {
    _ = ctx;
}
