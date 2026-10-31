const std = @import("std");
const linux = std.os.linux;

const command = @import("command.zig");
const Command = command.Command;
const CommandType = command.CommandType;

// https://www.rfc-editor.org/info/rfc821/#page-42
const max_command_len = 512;
const max_reply_len = 512;

// FIXME: Change localhost to the actuall domain
const domain = "localhost";

commad_line: [max_command_len]u8 = @splat(0),
reply_line: [max_reply_len]u8 = @splat(0),
socket: linux.fd_t,
details: linux.sockaddr.in,

const Self = @This();

pub fn deinit(self: *Self) void {
    _ = linux.shutdown(self.socket, linux.SHUT.RDWR);
    _ = linux.close(self.socket);
}

// Reply codes can be found here:
// https://www.rfc-editor.org/info/rfc821/#page-35
pub fn serve(self: *Self) !void {
    try self.reply("{d} {s} Service ready\r\n", .{ 220, domain });

    var last_command: ?CommandType = null;
    state: switch (try self.read()) {
        .HELO => |client_domain| {
            std.debug.print("client: HELO <SP> <{s}>\n", .{client_domain.get()});

            if (last_command != null) {
                try self.reply("{d} Bad sequence of commands", .{503});
                return;
            }

            last_command = .HELO;

            continue :state try self.read();
        },
        .MAIL => |path| {
            std.debug.print("client: MAIL <SP> FROM:<{s}@{s}>\n", .{ path.user.get(), path.domain.get() });

            if (last_command != .HELO) {
                try self.reply("{d} Bad sequence of commands", .{503});
                return;
            }

            last_command = .MAIL;

            continue :state try self.read();
        },
        .RCPT => |path| {
            std.debug.print("client: RCPT <SP> TO:<{s}@{s}>\n", .{ path.user.get(), path.domain.get() });

            if (last_command != .HELO or last_command != .RCPT) {
                try self.reply("{d} Bad sequence of commands", .{503});
                return;
            }

            last_command = .RCPT;

            continue :state try self.read();
        },
        .DATA => {
            std.debug.print("client: DATA\n", .{});
            return;
        },
        .QUIT => {
            try self.reply("{d} {s} Service closing transmission channel", .{ 221, domain });
            return;
        },
        // else => {
        //     try self.reply("{d} Bad sequence of commands", .{503});
        // },
    }
}

/// Writes the message to the socket, appends <CRLF> to the end.
pub fn reply(self: *Self, comptime format: []const u8, args: anytype) !void {
    const slice = std.mem.print(&self.reply_line, format ++ "\r\n", args) catch unreachable;
    if (linux.errno(linux.write(self.socket, slice.ptr, slice.len)) != .SUCCESS)
        return error.WriteFailed;
}

pub fn read(self: *Self) !Command {
    const result = linux.read(
        self.socket,
        &self.commad_line,
        self.commad_line.len,
    );

    if (linux.errno(result) != .SUCCESS) {
        return error.FailedToRead;
    }

    return Command.parse(self.commad_line);
}
