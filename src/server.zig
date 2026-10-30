const std = @import("std");
const linux = std.os.linux;

const Server = struct {
    port: u16 = std.mem.nativeToBig(u16, 6000),
    address: u32 = @bitCast([4]u8{ 127, 0, 0, 1 }),
    socket: linux.fd_t,

    pub fn init(
        address: struct {
            port: u16 = std.mem.nativeToBig(u16, 6000),
            address: u32 = @bitCast([4]u8{ 127, 0, 0, 1 }),
        },
    ) !Server {
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

    pub fn deinit(self: *const SmtpServer) void {
        _ = linux.shutdown(self.socket, linux.SHUT.RDWR);
        _ = linux.close(self.socket);
    }

    pub fn run(self: *SmtpServer) !void {
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
        var buffer: [1000]u8 = undefined;

        const result = linux.read(
            accepted_socket,
            &buffer,
            buffer.len,
        );

        if (linux.errno(result) != .SUCCESS) {
            return error.FailedToRead;
        }

        std.debug.print("read: {s}\n", .{buffer[0..result]});

        std.debug.print("Client disconnected\n", .{});
    }

    pub fn parse(buffer: []const u8) !void {
        if (buffer.len < 4)
            return error.InvalidMessgage;

        const command: Command = .parse(buffer[0..4]);

        switch (command) {
            .HELO => {
                std.debug.print("{s}", .{buffer[5..buffer.len]});
            },
            .MAIL => {},
            .RCPT => {},
            .DATA => {},
            .QUIT => {},
        }
    }
};
