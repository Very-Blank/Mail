const std = @import("std");
const linux = std.os.linux;

// https://www.rfc-editor.org/info/rfc821/#page-42
// NOTE: We limit the sizes here since it makes things very convenient for us.
const user_max_len = 64;
const domain_max_len = 64;
const command_max_len = 512;

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
    HELO: Domain,
    MAIL: Path,
    RCPT: Path,
    DATA: void,
    QUIT: void,

    // https://www.rfc-editor.org/info/rfc821/#page-42
    pub const User = struct {
        buffer: [user_max_len]u8 = @splat(0),
        len: u8 = 0,

        pub inline fn get(self: *const User) []const u8 {
            std.debug.assert(0 < self.len and self.len <= user_max_len);
            return self.buffer[0..self.len];
        }

        pub fn valid(self: User) bool {
            std.debug.assert(self.len <= user_max_len);

            if (self.len == 0)
                return false;

            for (self.get(), 0..) |c, i| {
                if (std.ascii.isAlphanumeric(c))
                    continue;

                if (c == '.' and
                    i + 1 < self.len and
                    std.ascii.isAlphanumeric(self.buffer[i + 1]))
                    continue;

                return false;
            }

            return true;
        }
    };

    pub const Domain = struct {
        buffer: [domain_max_len]u8 = @splat(0),
        len: u8 = 0,

        pub inline fn get(self: *const Domain) []const u8 {
            std.debug.assert(0 < self.len and self.len <= domain_max_len);
            return self.buffer[0..self.len];
        }
    };

    pub const Path = struct {
        user: User,
        domain: Domain,
    };

    pub fn parse(buffer: [command_max_len]u8) !Command {
        const command: CommandType = try .parse(.{
            buffer[0],
            buffer[1],
            buffer[2],
            buffer[3],
        });

        switch (command) {
            // HELO <SP> <domain> <CRLF>
            .HELO => {
                if (buffer[4] != ' ')
                    return error.NoSeperator;

                var i: usize = 4;
                while (buffer[i] == ' ' and i < buffer.len) : (i += 1) {}

                // FIXME: 10 is just a magic number, find the mininum valid number.
                if (buffer.len <= i + 10)
                    return error.Invalid;

                // FIXME: for test:
                return .{ .DATA = {} };
            },
            // MAIL <SP> FROM:<reverse-path> <CRLF>
            .MAIL => {
                if (buffer[4] != ' ')
                    return error.NoSeperator;

                var i: usize = 4;
                while (buffer[i] == ' ' and i < buffer.len) : (i += 1) {}

                // FIXME: 10 is just a magic number, find the mininum valid number.
                if (buffer.len <= i + 10)
                    return error.Invalid;

                if (!std.mem.eql(u8, buffer[i .. i + ("FROM:").len], "FROM:"))
                    return error.Invalid;

                return .{ .MAIL = try parsePath(buffer) };
            },
            // RCPT <SP> TO:<forward-path> <CRLF>
            .RCPT => {
                if (buffer[4] != ' ')
                    return error.NoSeperator;

                var i: usize = 4;
                while (buffer[i] == ' ' and i < buffer.len) : (i += 1) {}

                // FIXME: 10 is just a magic number, find the mininum valid number.
                if (buffer.len <= i + 10)
                    return error.Invalid;

                if (!std.mem.eql(u8, buffer[i .. i + ("TO:").len], "TO:"))
                    return error.Invalid;

                return .{ .MAIL = try parsePath(buffer) };
            },
            // DATA <CRLF>
            .DATA => {
                return .{ .DATA = {} };
            },
            // QUIT <CRLF>
            .QUIT => {
                return .{ .QUIT = {} };
            },
        }
    }

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
    pub fn parsePath(buffer: [command_max_len]u8) !Path {
        const start: usize = found: {
            for (0..buffer.len) |i| {
                switch (buffer[i]) {
                    '<' => break :found i,
                    else => {},
                }
            }

            return error.NoPathStart;
        };

        // It's much more easier to guarantee corrrect behaviour if
        // we start from the end.
        // Since it's possible for the local part to have: "\" <x>
        // Where <x> could be ">" and other bs
        const end: usize = found: {
            var i: usize = buffer.len - 1;
            while (0 < i) : (i -= 1) {
                switch (buffer[i]) {
                    '>' => break :found i,
                    else => {},
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
                    else => {},
                }
            }

            return error.NoPathMiddle;
        };

        if (!(start + 1 < middle and middle + 1 < end))
            return error.InvalidPath;

        var path: Path = .{
            .domain = .{},
            .user = .{},
        };

        const user: []const u8 = buffer[start + 1 .. middle];
        @memcpy(path.user.buffer[0..user.len], user);
        path.user.len = @intCast(user.len);

        const domain: []const u8 = buffer[middle + 1 .. end];
        @memcpy(path.domain.buffer[0..domain.len], domain);
        path.domain.len = @intCast(domain.len);

        return path;
    }
};
