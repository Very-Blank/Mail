const std = @import("std");
const linux = std.os.linux;

port: u16 = std.mem.nativeToBig(u16, 6000),
address: u32 = @bitCast([4]u8{ 127, 0, 0, 1 }),
socket: linux.fd_t,

const Self = @This();

const Command = @import("command.zig").Command;

pub fn init(
    address: struct {
        port: u16 = std.mem.nativeToBig(u16, 6000),
        address: u32 = @bitCast([4]u8{ 127, 0, 0, 1 }),
    },
) !Self {
    const socket: linux.fd_t = init: {
        const result = linux.socket(linux.AF.INET, linux.SOCK.STREAM, linux.IPPROTO.TCP);

        if (linux.errno(result) != .SUCCESS)
            return error.FailedToCreateSocket;

        break :init @intCast(result);
    };

    errdefer _ = linux.close(socket);

    if (linux.errno(
        linux.bind(
            socket,
            @ptrCast(&linux.sockaddr.in{
                .port = address.port,
                .addr = address.address,
            }),
            @sizeOf(linux.sockaddr.in),
        ),
    ) != .SUCCESS)
        return error.FailedToBind;

    if (linux.errno(
        linux.listen(
            socket,
            1,
        ),
    ) != .SUCCESS)
        return error.FailedToListen;

    return .{
        .port = address.port,
        .address = address.address,
        .socket = socket,
    };
}

pub fn deinit(self: *const Self) void {
    _ = linux.shutdown(self.socket, linux.SHUT.RDWR);
    _ = linux.close(self.socket);
}

pub fn run(self: *Self) !void {
    const accepted_socket: linux.fd_t = init: {
        const result = linux.accept(
            self.socket,
            @ptrCast(&self.address),
            @constCast(&@as(linux.socklen_t, @sizeOf(linux.sockaddr.in))),
        );

        if (linux.errno(result) != .SUCCESS)
            return error.FailedToAccept;

        break :init @intCast(result);
    };

    defer {
        _ = linux.shutdown(accepted_socket, linux.SHUT.RDWR);
        _ = linux.close(accepted_socket);
    }

    std.debug.print("Client connected\n", .{});

    std.debug.print("Reading input\n", .{});

    while (true) {
        var buffer: [512]u8 = @splat(0);

        const result = linux.read(
            accepted_socket,
            &buffer,
            buffer.len,
        );

        if (linux.errno(result) != .SUCCESS) {
            return error.FailedToRead;
        }

        const command = Command.parse(buffer) catch continue;

        std.debug.print("Command: {any}\n", .{command});
    }

    std.debug.print("Client disconnected\n", .{});
}
