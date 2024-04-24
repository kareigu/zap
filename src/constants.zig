const builtin = @import("builtin");
const compile_constants = @import("compile_constants");

pub const version = compile_constants.version;
pub const log_level = switch (builtin.mode) {
    .Debug => .debug,
    else => .info,
};
