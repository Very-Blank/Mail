const std = @import("std");
const linux = std.os.linux;

const Domain = @import("domain.zig");
const Path = @import("path.zig");

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
            // https://www.rfc-editor.org/info/rfc821/#section-4.1.2
            if (std.ascii.eqlIgnoreCase(name, &buffer))
                return @field(Self, name);
        }

        return error.InvalidCommand;
    }
};

pub const Command = union(CommandType) {
    HELO: Domain,
    MAIL: Path,
    RCPT: Path,
    DATA: void,
    QUIT: void,

    // https://www.rfc-editor.org/info/rfc821/#page-42
    const max_len = 512;

    pub const Reader = struct {
        buffer: []const u8,
        index: usize = 0,

        pub inline fn consume(self: *Reader, n: usize) bool {
            if (self.buffer.len <= self.index + n) {
                self.index = self.buffer.len;
                return false;
            }

            defer self.index += n;

            return true;
        }

        pub inline fn consumeSpace(self: *Reader) void {
            while (self.index < self.buffer.len and self.buffer[self.index] == ' ') : (self.index += 1) {}
        }

        pub inline fn consumeExpect(self: *Reader, expected: []const u8) bool {
            if (self.buffer.len <= self.index + expected.len)
                return false;

            defer self.index += expected.len;

            return std.ascii.eqlIgnoreCase(
                self.buffer[self.index .. self.index + expected.len],
                expected,
            );
        }

        pub inline fn readToEnd(self: *Reader) ![]const u8 {
            if (self.buffer.len <= self.index)
                return error.InvalidCommand;

            const start = self.index;

            while (self.index < self.buffer.len) : (self.index += 1) {
                if (self.buffer[self.index] == '\r' and self.index + 1 < self.buffer.len and self.buffer[self.index + 1] == '\n' and self.index != start) {
                    return self.buffer[start..self.index];
                }
            }

            return error.InvalidCommand;
        }
    };

    pub fn parse(buffer: [max_len]u8) !Command {
        var reader: Reader = .{ .buffer = &buffer };

        std.debug.assert(
            reader.consume(4),
        );

        const command: CommandType = try .parse(.{
            buffer[0],
            buffer[1],
            buffer[2],
            buffer[3],
        });

        switch (command) {
            // HELO <SP> <domain> <CRLF>
            .HELO => {
                if (!reader.consumeExpect(" "))
                    return error.NoSeperator;

                reader.consumeSpace();

                return .{
                    .HELO = try Domain.parse(try reader.readToEnd()),
                };
            },
            // MAIL <SP> FROM:<reverse-path> <CRLF>
            .MAIL => {
                if (!reader.consumeExpect(" "))
                    return error.NoSeperator;

                reader.consumeSpace();

                if (!reader.consumeExpect("FROM:"))
                    return error.InvalidCommand;

                const slice = try reader.readToEnd();

                return .{ .MAIL = try Path.parse(slice) };
            },
            // RCPT <SP> TO:<forward-path> <CRLF>
            .RCPT => {
                if (!reader.consumeExpect(" "))
                    return error.NoSeperator;

                reader.consumeSpace();

                if (!reader.consumeExpect("TO:"))
                    return error.InvalidCommand;

                const slice = try reader.readToEnd();

                return .{ .RCPT = try Path.parse(slice) };
            },
            .DATA => {
                if (!reader.consumeExpect("\r\n"))
                    return error.InvalidCommand;

                return .{ .DATA = {} };
            },
            // QUIT <CRLF>
            .QUIT => {
                if (!reader.consumeExpect("\r\n"))
                    return error.InvalidCommand;
                return .{ .QUIT = {} };
            },
        }
    }
};

test "Valid commands" {
    try std.testing.expectEqual(CommandType.HELO, try CommandType.parse("HELO".*));
    try std.testing.expectEqual(CommandType.MAIL, try CommandType.parse("MAIL".*));
    try std.testing.expectEqual(CommandType.RCPT, try CommandType.parse("RCPT".*));
    try std.testing.expectEqual(CommandType.DATA, try CommandType.parse("DATA".*));
    try std.testing.expectEqual(CommandType.QUIT, try CommandType.parse("QUIT".*));
}

test "Invalid commands" {
    try std.testing.expectError(error.InvalidCommand, CommandType.parse("SOME".*));
    try std.testing.expectError(error.InvalidCommand, CommandType.parse("BURG".*));
    try std.testing.expectError(error.InvalidCommand, CommandType.parse("HDFD".*));
}

test "Case insensitive of commands" {
    try std.testing.expectEqual(CommandType.HELO, try CommandType.parse("heLo".*));
    try std.testing.expectEqual(CommandType.HELO, try CommandType.parse("hELo".*));
    try std.testing.expectEqual(CommandType.HELO, try CommandType.parse("Helo".*));
    try std.testing.expectEqual(CommandType.HELO, try CommandType.parse("hElO".*));
}
