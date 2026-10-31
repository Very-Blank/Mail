const std = @import("std");
const linux = std.os.linux;

const Server = @import("server.zig");

pub fn main(_: std.process.Init) !void {
    var smtp_server: Server = try .init(.{});
    defer smtp_server.deinit();

    try smtp_server.run();
}

test "All for one!" {
    _ = @import("client.zig");
    _ = @import("server.zig");
    _ = @import("command.zig");
}
