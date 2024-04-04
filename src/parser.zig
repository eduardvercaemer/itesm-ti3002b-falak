const std = @import("std");
const Context = @import("context.zig").Context;

pub const ParserError = error{};

pub fn parser(ctx: *Context) ParserError!void {
    _ = ctx;
}
