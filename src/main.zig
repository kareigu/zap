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

pub fn main() !void {
    std.log.info("zat {}", .{constants.version});
    std.log.err("zat", .{});
    std.log.warn("zat", .{});
    std.log.debug("zat", .{});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
