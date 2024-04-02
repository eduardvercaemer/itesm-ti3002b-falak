const std = @import("std");

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
    _ = file;
}
