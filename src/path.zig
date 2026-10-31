const User = @import("user.zig");
const Domain = @import("domain.zig");

user: User,
domain: Domain,

const Self = @This();

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
pub fn parse(buffer: []const u8) !Self {
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

    return .{
        .user = try User.parse(buffer[start + 1 .. middle]),
        .domain = try Domain.parse(buffer[middle + 1 .. end]),
    };
}
