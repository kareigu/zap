const std = @import("std");
const constants = @import("constants.zig");
const Error = constants.Error;
const io = @import("io.zig");
const common = @import("common.zig");
const Options = common.Options;
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
    \\
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
    var writer = io.StdOut.init();
    defer writer.flush() catch std.log.err("stdout flush failed", .{});

    var command_issued = false;
    for (args[1..args.len]) |arg| {
        if (arg[0] == '-') {
            var start_flag: u16 = 1;
            while (start_flag < arg.len and arg[start_flag] == '-') : (start_flag += 1) {}

            const flag = arg[start_flag..arg.len];
            if (std.mem.eql(u8, flag, "version") or std.mem.eql(u8, flag, "v")) {
                writer.write_fmt("{}\n", .{constants.version}) catch {
                    std.log.err("failed writing to stdout", .{});
                    return error_to_u8(Error.IOError);
                };
                return 0;
            }
            if (std.mem.eql(u8, flag, "help") or std.mem.eql(u8, flag, "h")) {
                writer.write_fmt(help_print, .{constants.version}) catch {
                    std.log.err("failed writing to stdout", .{});
                    return error_to_u8(Error.IOError);
                };
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
            writer.write_fmt("{s}\n", .{f.data}) catch {
                std.log.err("failed writing to stdout", .{});
                return error_to_u8(Error.IOError);
            };
        }
        const contents = try io.read_to_buffer(alloc, f.data);
        defer alloc.free(contents);

        if (!options.line_numbers) {
            writer.write(contents) catch {
                std.log.err("failed writing to stdout", .{});
                return error_to_u8(Error.IOError);
            };
            return 0;
        }

        var line_count: usize = 0;
        for (contents) |c| {
            if (c == '\n') {
                line_count += 1;
            }
        }
        std.log.debug("line_count: {d}", .{line_count});
        const max_padding: usize = common.digit_count(line_count);
        std.log.debug("max_padding: {d}", .{max_padding});

        var linenr: usize = 1;
        var line_start: usize = 0;
        var i: usize = 0;
        while (i < contents.len) : (i += 1) {
            if (contents[i] != '\n') {
                continue;
            }

            i += 1;
            const padding_size = max_padding - common.digit_count(linenr);
            writer.write_padding(padding_size) catch {
                std.log.err("failed writing to stdout", .{});
                return error_to_u8(Error.IOError);
            };
            writer.write_fmt("{d}│ {s}", .{ linenr, contents[line_start..i] }) catch {
                std.log.err("failed writing to stdout", .{});
                return error_to_u8(Error.IOError);
            };

            line_start = i;
            i -= 1;
            linenr += 1;
        }

        file = f.next;
    }

    return 0;
}
