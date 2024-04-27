const builtin = @import("builtin");
const compile_constants = @import("compile_constants");

pub const version = compile_constants.version;
pub const log_level = switch (builtin.mode) {
    .Debug => .debug,
    else => .info,
};

pub const Error = error{
    NoArgs,
    InvalidArgs,
    FileNotFound,
    IOError,
    PermissionDenied,
};

pub const Colour = enum {
    Default,
    LineNumber,
    Header,
};
