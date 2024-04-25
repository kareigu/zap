const std = @import("std");
const constants = @import("constants.zig");
const Error = constants.Error;
const io = @import("io.zig");
const error_to_u8 = @import("common.zig").error_to_u8;

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

const help_print =
    \\zap - {}
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
        return error_to_u8(Error.InvalidArgs);
    }

    const FileList = std.DoublyLinkedList([]const u8);
    var files = FileList{};
    defer {
        while (files.popFirst()) |file| {
            alloc.destroy(file);
        }
    }

    for (args[1..args.len]) |arg| {
        if (arg[0] == '-') {
            var start_flag: u16 = 1;
            while (start_flag < arg.len and arg[start_flag] == '-') : (start_flag += 1) {}

            const flag = arg[start_flag..arg.len];
            if (std.mem.eql(u8, flag, "version") or std.mem.eql(u8, flag, "v")) {
                std.log.info("{}", .{constants.version});
                return 0;
            }
            if (std.mem.eql(u8, flag, "help") or std.mem.eql(u8, flag, "h")) {
                std.log.info(help_print, .{constants.version});
                return 0;
            }

            std.log.err("invalid argument provided: {s}", .{arg});
            return error_to_u8(Error.InvalidArgs);
        }

        io.is_valid_path(arg) catch |e| return error_to_u8(e);
        const node = try alloc.create(FileList.Node);
        node.data = arg;
        files.append(node);
    }

    var file = files.first;
    while (file) |f| {
        std.log.info("{s}", .{f.data});
        const contents = try io.read_to_buffer(alloc, f.data);
        defer alloc.free(contents);

        std.log.info("{s}", .{contents});

        file = f.next;
    }

    return 0;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
