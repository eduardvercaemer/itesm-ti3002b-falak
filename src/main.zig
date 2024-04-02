const std = @import("std");
const lexer = @import("lexer.zig");
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
        .tokens = std.ArrayList(lexer.Token).init(allocator),
    };

    defer {
        for (ctx.tokens.items) |item| switch (item.value) {
            .comment => |comment| std.debug.print("{d} comment: {s}\n", .{ item.line, comment }),
            .symbol => |symbol| std.debug.print("{d} symbol: {s}\n", .{ item.line, symbol }),
            .operator => |op| std.debug.print("{d} op: {any}\n", .{ item.line, op }),
            .literal => |lit| switch (lit) {
                .string => |string| std.debug.print("{d} string literal: {s}\n", .{ item.line, string }),
                .integer => |int| std.debug.print("{d} integer literal: {d}\n", .{ item.line, int }),
                .character => |char| std.debug.print("{d} character literal: {c}\n", .{ item.line, char }),
                else => {},
            },
            else => {},
        };
    }

    try lexer.lexer(&ctx);
}
