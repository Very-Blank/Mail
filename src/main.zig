const std = @import("std");
const Io = std.Io;

const smtp_commands = enum {
    HELO,
    MAIL,
    RCPT,
    DATA,
    RSET,
    SEND,
    SOML,
    SAML,
    VRFY,
    EXPN,
    HELP,
    NOOP,
    QUIT,
    TURN,
};

pub fn main(_: std.process.Init) !void {
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
