const std = @import("std");
const constants = @import("constants.zig");

pub const std_options = .{
    .log_level = constants.log_level,
    .logFn = logFn,
};

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;

    if (level == .info) {
        const stdout = std.io.getStdOut().writer();
        nosuspend stdout.print(format ++ "\n", args) catch return;
        return;
    }

    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(comptime level.asText() ++ ": " ++ format ++ "\n", args) catch return;
}

const Error = error{
    NoArgs,
    InvalidArgs,
};

const help_print =
    \\zat - {}
    \\
    \\-- global --
    \\  -h, --help     -  display this help message
    \\  -v, --version  -  display program version
;

pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len <= 1) {
        std.log.err("no args provided", .{});
        return @intFromError(Error.NoArgs);
    }

    for (args[1..args.len]) |arg| {
        if (arg[0] == '-') {
            if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                std.log.info("{}", .{constants.version});
                return 0;
            }
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                std.log.info(help_print, .{constants.version});
                return 0;
            }
        }

        std.log.err("invalid argument provided: {s}", .{arg});
        return @intFromError(Error.InvalidArgs);
    }

    std.log.info("zat {}", .{constants.version});
    return 0;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
