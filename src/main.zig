const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const stdout_file = std.Io.File.stdout();
    var stdout_buf: [4096]u8 = undefined;
    var stdout = stdout_file.writerStreaming(init.io, &stdout_buf);
    try stdout.interface.print("nearme stub\n", .{});
    try stdout.interface.flush();
}
