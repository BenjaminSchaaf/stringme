module stringme;

import std.conv;
import std.algorithm;

import vibe.d;

const READ_TIMEOUT = 2.dur!"seconds";

struct ConnectString {
    string address;
    string password;
    string rconPassword;

    this(string connectString) {
        auto commands = connectString.split(";");

        foreach (command; commands) {
            command = command.stripLeft();

            auto value = parseSourceCommandVariale(command, "connect");
            if (value !is null) address = value;

            value = parseSourceCommandVariale(command, "password");
            if (value !is null) password = value;

            value = parseSourceCommandVariale(command, "rcon_password");
            if (value !is null) rconPassword = value;
        }
    }

    this(string address, string password, string rconPassword) {
        this.address = address;
        this.password = password;
        this.rconPassword = rconPassword;
    }

    string toString(bool includeRcon = true) {
        auto str = "connect %s; password \"%s\"".format(address, password);
        if (includeRcon) str ~= "; rcon_password \"%s\"".format(rconPassword);
        return str;
    }

    TCPConnection connectRCon() {
        auto splits = address.split(":");

        auto connection = connectTCP(splits[0], splits[1].to!ushort);
        connection.readTimeout = READ_TIMEOUT;
        return connection;
    }

    void validate(ref string[string] errors) {
        // TODO:
        //try {
        //    resolveHost();
        //} catch () {

        //}

        if (!address.canFind(":")) {
            errors["address"] = "must be in the format 'ip:port'";
        }
    }
}

string parseSourceCommandVariale(string command, string variable) {
    command = command.stripLeft();

    auto start = variable ~ " ";
    if (!command.startsWith(start)) return null;

    auto value = command[start.length..$].strip();

    if (value[0] == '"') value = value[1..$ - 1];

    return value;
}
