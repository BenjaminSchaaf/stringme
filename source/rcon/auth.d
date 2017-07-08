module rcon.auth;

import std.random;
import std.exception;

import vibe.core.net;

import rcon.util;
import rcon.protocol;

bool authenticate(TCPConnection connection, string password) {
    // Create a unique authentication ID
    auto authID = uniqueID();

    Packet(authID, Packet.Type.AUTH, password).send(connection);

    // Source always sends an empty reponse before acknowledging success/failure
    auto empty = Packet.receive(connection);
    enforce(empty.type == Packet.Type.RESPONSE_VALUE);
    enforce(empty.message == "");

    auto authResponse = Packet.receive(connection);
    enforce(authResponse.type == Packet.Type.AUTH_RESPONSE);

    return authResponse.id == authID;
}
