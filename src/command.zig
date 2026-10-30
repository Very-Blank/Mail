const std = @import("std");
const linux = std.os.linux;

pub const CommandType = enum {
    // https://www.rfc-editor.org/info/rfc821/#section-4.1
    HELO, // HELO <SP> <domain> <CRLF>
    MAIL, // MAIL <SP> FROM:<reverse-path> <CRLF>
    RCPT, // RCPT <SP> TO:<forward-path> <CRLF>
    DATA, // DATA <CRLF>
    QUIT, // QUIT <CRLF>

    const Self = @This();

    pub fn parse(buffer: [4]u8) !Self {
        inline for (@typeInfo(Self).@"enum".field_names) |name| {
            no_match: {
                inline for (0..4) |i|

                    // https://www.rfc-editor.org/info/rfc821/#section-4.1.2
                    if (buffer[i] != name[i] and (buffer[i] -% 32) != name[i])
                        break :no_match;

                return @field(Self, name);
            }
        }

        return error.NotACommand;
    }
};

pub const Command = union(CommandType) {
    HELO: struct { domain: []const u8 },
    MAIL: struct { local: []const u8, domain: []const u8 },
    RCPT: struct { local: []const u8 },
    DATA: void,
    QUIT: void,

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
    // <char> ::= <a> | <d>
    pub fn parse(buffer: [512]u8) !Command {
        const command: CommandType = .parse(buffer[0..4]);

        switch (command) {
            // HELO <SP> <domain> <CRLF>
            .HELO => {},
            // MAIL <SP> FROM:<reverse-path> <CRLF>
            .MAIL => {},
            // RCPT <SP> TO:<forward-path> <CRLF>
            .RCPT => {},
            // DATA <CRLF>
            .DATA => {},
            // QUIT <CRLF>
            .QUIT => {},
        }
    }
};

const Path = struct {
    local: []const u8,
    domain: []const u8,

    /// We validate the local-path only, domain part isn't validated.
    pub fn parse(buffer: []const u8) !Path {
        if (buffer.len < 2)
            return error.BufferLenTooShort;

        const start: usize = found: {
            for (0..buffer.len) |i| {
                switch (buffer[i]) {
                    '<' => break :found i,
                }
            }

            return error.NoPathStart;
        };

        // It's much more easier to guarantee corrrect behaviour if
        // we start from the end.
        // Since it's possible for the local part to have: "\" <x>
        // Where <x> could be ">"
        const end: usize = found: {
            var i: usize = buffer.len - 1;
            while (0 < i) : (i -= 1) {
                switch (buffer[i]) {
                    '>' => break :found i,
                }
            }

            return error.NoPathEnd;
        };

        // Same here.
        const middle: usize = found: {
            var i: usize = end;
            while (0 < i) : (i -= 1) {
                switch (buffer[i]) {
                    '@' => break :found i,
                }
            }

            return error.NoPathMiddle;
        };

        const path: Path = .{
            .local = buffer[middle + 1 .. end],
            .domain = buffer[start + 1 .. middle],
        };

        for (path.local, 0..) |c, i| {
            if (std.ascii.isAlphanumeric(c))
                continue;

            if (c == '.' and
                i + 1 < path.local.len and
                std.ascii.isAlphanumeric(path.local[i + 1]))
                continue;

            return error.UnsupportedLocalPath;
        }

        return path;
    }
};
