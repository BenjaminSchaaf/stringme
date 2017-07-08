module rcon.util;

import std.regex;
import std.exception;

import vibe.d;

import rcon.protocol;

string readCVar(TCPConnection connection, string convar) {
    Packet(1, Packet.Type.EXEC_COMMAND, convar).send(connection);

    auto response = Packet.receive(connection);
    enforce(response.type == Packet.Type.RESPONSE_VALUE, "Invalid response");

    return parseCVar(convar, response.message);
}

string parseCVar(string convar, string message) {
    auto prefix = "\"%s\" = \"".format(convar);
    enforce(message.startsWith(prefix), "Invalid convar format");

    message = message[prefix.length..$];
    message = replaceFirst(message, regex("\" \\( def\\. \".*\" \\)[\n\r].*$", "s"), "");
    return message;
}

unittest {
    auto message = `"sv_password" = "FxhwJE-NudCrPW_5"" ( def. "" )
  notify
  - Server password for entry into multiplayer games)`;

    assert(parseCVar("sv_password", message) == "FxhwJE-NudCrPW_5\"");
}

int uniqueID() {
    import std.random;

    return uniform(1, int.max);
}
