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
