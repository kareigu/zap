const std = @import("std");
const ConstantsError = @import("constants.zig").Error;

const OUT = std.io.getStdOut().writer();

pub const StdOut = struct {
    const STDOUT_BUFFER_SIZE = 2 * 1024;
    const Writer = std.io.BufferedWriter(STDOUT_BUFFER_SIZE, @TypeOf(OUT));
    pub const Error = Writer.Error;

    writer: Writer = .{ .unbuffered_writer = OUT },

    pub fn init() StdOut {
        return StdOut{};
    }

    pub fn write(self: *StdOut, bytes: []const u8) Error!void {
        const size = try self.writer.write(bytes);
        if (size != bytes.len) {
            std.log.err("failed writing line: wrote {d} bytes, expecting {d}", .{ size, bytes.len });
            return Error.Unexpected;
        }
    }

    pub fn write_fmt(self: *StdOut, comptime format: []const u8, args: anytype) !void {
        try std.fmt.format(self.writer.writer(), format, args);
    }

    pub fn write_padding(self: *StdOut, size: usize) !void {
        try self.writer.writer().writeByteNTimes(' ', size);
    }

    pub fn flush(self: *StdOut) !void {
        try self.writer.flush();
    }
};

pub fn read_to_buffer(alloc: std.mem.Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const byte_size = if (file.metadata()) |metadata| metadata.size() else |_| try seek_file_size(file);

    std.log.debug("allocating {d} bytes", .{byte_size});
    const buf = try alloc.alloc(u8, byte_size);
    const read = try buf_reader.read(buf);
    std.log.debug("read {d} bytes", .{read});

    return buf;
}

fn seek_file_size(file: std.fs.File) !u64 {
    try file.reader().skipUntilDelimiterOrEof(0);
    const bytes = try file.reader().context.getPos();
    std.log.debug("seeked byte_size: {d}", .{bytes});

    try file.reader().context.seekTo(0);
    return bytes;
}

pub fn is_valid_path(path: []const u8) ConstantsError!void {
    const Error = ConstantsError;
    std.fs.cwd().access(path, .{}) catch |e| switch (e) {
        error.FileNotFound => {
            std.log.err("file not found: {s}", .{path});
            return Error.FileNotFound;
        },
        error.NameTooLong => {
            std.log.err("name too long: {d} characters", .{path.len});
            return Error.InvalidArgs;
        },
        error.BadPathName => {
            std.log.err("bad filepath: {s}", .{path});
            return Error.InvalidArgs;
        },
        error.InvalidUtf8, error.InvalidWtf8 => {
            std.log.err("invalid utf-8: {s}", .{path});
            return Error.InvalidArgs;
        },
        error.PermissionDenied => {
            std.log.err("permission denied: {s}", .{path});
            return Error.PermissionDenied;
        },
        error.ReadOnlyFileSystem => {
            std.log.err("read only filesystem: {s}", .{path});
            return Error.PermissionDenied;
        },
        error.InputOutput, error.SymLinkLoop, error.SystemResources => {
            std.log.err("io error: {s}", .{path});
            return Error.IOError;
        },
        error.FileBusy => {
            std.log.err("file busy: {s}", .{path});
            return Error.IOError;
        },
        error.Unexpected => {
            std.log.err("unknown error: {s}", .{path});
            return Error.InvalidArgs;
        },
    };
}
