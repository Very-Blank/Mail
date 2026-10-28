const std = @import("std");
const net = std.Io.net;
const Io = std.Io;

const SmtpCommand = enum {
    // https://www.rfc-editor.org/info/rfc821/#section-4.1
    HELO, // HELO <SP> <domain> <CRLF>
    MAIL, // MAIL <SP> FROM:<reverse-path> <CRLF>
    RCPT, // RCPT <SP> TO:<forward-path> <CRLF>
    DATA, // DATA <CRLF>
    QUIT, // QUIT <CRLF>

    pub fn parse(buffer: [4]u8) !SmtpCommand {
        inline for (@typeInfo(SmtpCommand).@"enum".field_names) |name| {
            no_match: {
                inline for (0..4) |i|

                    // https://www.rfc-editor.org/info/rfc821/#section-4.1.2
                    if (buffer[i] != name[i] and (buffer[i] -% 32) != name[i])
                        break :no_match;

                return @field(SmtpCommand, name);
            }
        }

        return error.NotACommand;
    }
};

// https://www.rfc-editor.org/info/rfc821/#page-30
// We only implement a subset of the spec.
// FULL:
// <path> ::= "<" [ <a-d-l> ":" ] <mailbox> ">"
// IMPL:
// <path> ::= "<" <mailbox> ">"
//
// FULL:
// <local-part> ::= <dot-string> | <quoted-string>
// IMPL:
// <local-part> ::= <dot-string>
//
// FULL:
// <char> ::= <c> | "\" <x>
// IMPL:
// <char> ::= <a>

const Path = struct {
    local: []const u8,
    domain: []const u8,
};

const SmtpServer = struct {
    pub fn receive(buffer: []const u8) !void {
        if (buffer.len < 4)
            return error.InvalidMessgage;

        const command: SmtpCommand = .parse(buffer[0..4]);

        switch (command) {
            .HELO => {},
            .MAIL => {},
            .RCPT => {},
            .DATA => {},
            .QUIT => {},
        }
    }
};

pub fn main(_: std.process.Init) !void {}
