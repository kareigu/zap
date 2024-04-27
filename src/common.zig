const constants = @import("constants.zig");

pub fn error_to_u8(err: constants.Error) u8 {
    return @truncate(@intFromError(err));
}

pub const Options = packed struct {
    header: bool = true,
    line_numbers: bool = true,
    colour: bool = true,
};

pub inline fn digit_count(n: usize) usize {
    return @intFromFloat(@floor(@log10(@as(f64, @floatFromInt(n))) + 1.0));
}
