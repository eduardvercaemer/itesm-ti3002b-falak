const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const Context = @import("context.zig").Context;

const MAX_FILE_SIZE = 1_000_000;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) {
        return error.BadArguments;
    }

    const file = try std.fs.cwd().readFileAlloc(allocator, args[1], MAX_FILE_SIZE);

    var ctx = Context{
        .file = file,
        .allocator = allocator,
        .tokens = undefined,
        .program = undefined,
        .symbols = undefined,
        .message = null,
    };

    // defer {
    //     for (ctx.tokens.items) |item| switch (item.value) {
    //         .comment => std.debug.print("{d} comment: {s}\n", .{ item.line, item.repr }),
    //         .symbol => std.debug.print("{d} symbol: {s}\n", .{ item.line, item.repr }),
    //         .operator => |op| std.debug.print("{d} op: {any}\n", .{ item.line, op }),
    //         .keyword => |kw| std.debug.print("{d} keyword: {any}\n", .{ item.line, kw }),
    //         .literal => |lit| switch (lit) {
    //             .string => std.debug.print("{d} string literal: {s}\n", .{ item.line, item.repr }),
    //             .integer => std.debug.print("{d} integer literal: {s}\n", .{ item.line, item.repr }),
    //             .character => std.debug.print("{d} character literal: {s}\n", .{ item.line, item.repr }),
    //             else => {},
    //         },
    //     };
    // }

    // defer {
    //     for (ctx.program.items) |def| switch (def) {
    //         .function => std.debug.print("function definition\n", .{}),
    //         .globals => std.debug.print("globals definition\n", .{}),
    //     };
    // }

    errdefer {
        const message = ctx.message orelse "";
        std.debug.print("error during compilation\n{s}\n", .{message});
    }

    try lexer.lexer(&ctx);
    try parser.parser(&ctx);
}
