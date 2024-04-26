const std = @import("std");
const constants = @import("constants.zig");
const Error = constants.Error;
const io = @import("io.zig");
const Options = @import("common.zig").Options;
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
    \\  -H, --header        -  enable/disable header printing [default: true]
    \\  -l, --line-numbers  - enable/disable line numbers [default: true]
    \\
    \\-- global --
    \\  -h, --help          -  display this help message
    \\  -v, --version       -  display program version
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

    var options = Options{};

    var command_issued = false;
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

            if (std.mem.eql(u8, flag, "header") or std.mem.eql(u8, flag, "H")) {
                options.header = !options.header;
                continue;
            }

            if (std.mem.eql(u8, flag, "line-numbers") or std.mem.eql(u8, flag, "l")) {
                options.line_numbers = !options.line_numbers;
                continue;
            }

            std.log.err("invalid argument provided: {s}", .{arg});
            return error_to_u8(Error.InvalidArgs);
        }

        io.is_valid_path(arg) catch |e| return error_to_u8(e);
        const node = try alloc.create(FileList.Node);
        node.data = arg;
        files.append(node);
        command_issued = true;
    }

    if (!command_issued) {
        std.log.err("no file(s) provided", .{});
        return error_to_u8(Error.InvalidArgs);
    }

    var file = files.first;
    while (file) |f| {
        if (options.header) {
            std.log.info("{s}", .{f.data});
        }
        const contents = try io.read_to_buffer(alloc, f.data);
        defer alloc.free(contents);

        var linenr: usize = 1;
        var line_start: usize = 0;
        var i: usize = 0;
        while (i < contents.len) : (i += 1) {
            if (contents[i] != '\n') {
                continue;
            }

            if (options.line_numbers) {
                std.log.info("{d:>8}│ {s}", .{ linenr, contents[line_start..i] });
            } else {
                std.log.info("{s}", .{contents[line_start..i]});
            }

            line_start = i + 1;
            linenr += 1;
        }

        file = f.next;
    }

    return 0;
}
