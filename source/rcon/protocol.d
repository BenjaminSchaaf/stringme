module rcon.protocol;

import std.socket;
import std.bitmanip;
import std.exception;

import vibe.d;
import vibe.core.net;

struct Packet {
    enum Type {
        AUTH = 3,
        AUTH_RESPONSE = 2,
        EXEC_COMMAND = 2,
        RESPONSE_VALUE = 0,
    }

    int id;
    Type type;
    string message;

    static Packet receive(TCPConnection connection) {
        ubyte[4] sizeBuffer;
        connection.read(sizeBuffer);
        int size = littleEndianToNative!int(sizeBuffer);
        enforce(size >= 10 && size <= 4096, "Invalid packet size");

        ubyte[] buffer = new ubyte[size];
        connection.read(buffer);
        return Packet.fromBuffer(buffer);
    }

    static Packet fromBuffer(ubyte[] data) {
        auto id = data.read!(int, Endian.littleEndian);
        auto type = data.read!(Type, Endian.littleEndian);
        string message = null;

        // Some messages are plain empty, including no \0 at the end
        if (data.length > 2) {
            message = cast(string)data[0..data.length - 3];
        }

        return Packet(id, type, message);
    }

    unittest {
        auto data =
            nativeToLittleEndian(5) ~
            nativeToLittleEndian(3) ~
            cast(ubyte[])[0x66, 0x6f, 0x6f, 0x00, 0x00, 0x00];

        auto packet = Packet.fromBuffer(data);
        assert(packet.id == 5);
        assert(packet.type == 3);
        assert(packet.message == "foo");
    }

    this(int id, Type type, string message) {
        this.id = id;
        this.type = type;
        this.message = message;
    }

    @property int size() {
        return cast(int)(message.length + 1 + 10);
    }

    ubyte[] header() {
        auto data = new ubyte[12];
        data.write!(int, Endian.littleEndian)(size, 0);
        data.write!(int, Endian.littleEndian)(id, 4);
        data.write!(int, Endian.littleEndian)(type, 8);
        return data;
    }

    ubyte[] toBuffer() {
        auto data = new ubyte[size + 4];

        size_t offset = 0;
        data[offset..offset + 12] = header();

        offset += 12;
        data[offset..offset + message.length] = cast(ubyte[])message;

        offset += message.length;
        data[offset..offset + 3] = [0x00, 0x00, 0x00];

        return data;
    }

    unittest {
        auto packet = Packet(5, Type.AUTH, "foo");

        assert(packet.toBuffer() ==
            nativeToLittleEndian(14) ~
            nativeToLittleEndian(5) ~
            nativeToLittleEndian(3) ~
            cast(ubyte[])[0x66, 0x6f, 0x6f, 0x00, 0x00, 0x00]);
    }

    void send(TCPConnection connection) {
        connection.write(toBuffer());
    }

    string toString() {
        return "RCON(%s, %s, %s)".format(id, type, message);
    }
}
