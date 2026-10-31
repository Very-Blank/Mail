const std = @import("std");
const linux = std.os.linux;

const Server = @import("server.zig");

// https://www.rfc-editor.org/info/rfc821/#page-42
pub fn main(_: std.process.Init) !void {
    var smtp_server: Server = try .init(.{});
    defer smtp_server.deinit();

    try smtp_server.run();
}
