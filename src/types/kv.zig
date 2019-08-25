const std = @import("std");
const fmt = std.fmt;
const Allocator = std.mem.Allocator;

pub fn KV(comptime K: type, comptime V: type) type {
    return struct {
        key: K,
        value: V,

        const Self = @This();
        pub const Redis = struct {
            pub const Serializer = struct {};

            // KV can parse itself as a list of
            // two elements or as a fragment of
            // a bigger list.
            pub const Parser = struct {
                pub fn parse(tag: u8, comptime rootParser: type, msg: var) !Self {
                    switch (tag) {
                        else => return error.DecodeError,
                        '*' => {
                            // TODO: write real implementation
                            var buf: [100]u8 = undefined;
                            var end: usize = 0;
                            for (buf) |*elem, i| {
                                const ch = try msg.readByte();
                                elem.* = ch;
                                if (ch == '\r') {
                                    end = i;
                                    break;
                                }
                            }

                            try msg.skipBytes(1);
                            const size = try fmt.parseInt(usize, buf[0..end], 10);

                            if (size != 2) {
                                return error.DecodeError;
                            }

                            return Self{
                                .key = try rootParser.parse(K, msg),
                                .value = try rootParser.parse(V, msg),
                            };
                        },
                    }
                }

                pub inline fn destroy(self: Self, comptime rootParser: type, allocator: *Allocator) void {
                    switch (@typeInfo(K)) {
                        else => {},
                        .Enum, .Union, .Struct, .Pointer, .Optional => {
                            rootParser.freeReply(self.key, allocator);
                        },
                    }
                    switch (@typeInfo(V)) {
                        else => {},
                        .Enum, .Union, .Struct, .Pointer, .Optional => {
                            rootParser.freeReply(self.value, allocator);
                        },
                    }
                }

                pub fn parseAlloc(tag: u8, comptime rootParser: type, allocator: *Allocator, msg: var) !Self {
                    switch (tag) {
                        else => return error.DecodeError,
                        '*' => {
                            // TODO: write real implementation
                            var buf: [100]u8 = undefined;
                            var end: usize = 0;
                            for (buf) |*elem, i| {
                                const ch = try msg.readByte();
                                elem.* = ch;
                                if (ch == '\r') {
                                    end = i;
                                    break;
                                }
                            }

                            try msg.skipBytes(1);
                            const size = try fmt.parseInt(usize, buf[0..end], 10);

                            if (size != 2) {
                                return error.DecodeError;
                            }

                            return Self{
                                .key = try rootParser.parseAlloc(K, allocator, msg),
                                .value = try rootParser.parseAlloc(V, allocator, msg),
                            };
                        },
                    }
                }

                pub const TokensPerFragment = 2;
                pub fn parseFragment(comptime rootParser: type, msg: var) !Self {
                    return Self{
                        .key = try rootParser.parse(K, msg),
                        .value = try rootParser.parse(V, msg),
                    };
                }
                pub fn parseFragmentAlloc(comptime rootParser: type, allocator: *Allocator, msg: var) !Self {
                    return Self{
                        .key = try rootParser.parseAlloc(K, allocator, msg),
                        .value = try rootParser.parseAlloc(V, allocator, msg),
                    };
                }
            };
        };
    };
}