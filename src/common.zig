const constants = @import("constants.zig");

pub fn error_to_u8(err: constants.Error) u8 {
    return @truncate(@intFromError(err));
}
