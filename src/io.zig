const std = @import("std");
const Error = @import("constants.zig").Error;

pub fn is_valid_path(path: []const u8) Error!void {
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
