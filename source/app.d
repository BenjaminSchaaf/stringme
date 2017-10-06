import std.conv;
import std.file;
import std.json;
import std.array;
import std.algorithm;

import vibe.d;
import vibe.rcon;

import connect_string;

const CONFIG_FILE = "config/application.json";
const LOG_FILE = "logs/error.log";
const ACCESS_FILE = "logs/access.log";

version (unittest) {} else
shared static this() {
    // Settings setup
    auto settings = readSettings();

    settings.accessLogFile = ACCESS_FILE;
    settings.options |= HTTPServerOption.distribute;

    auto fileLogger = cast(shared)new FileLogger(LOG_FILE);
    fileLogger.minLevel = LogLevel.info;
    registerLogger(fileLogger);

    setLogFormat(FileLogger.Format.thread, FileLogger.Format.thread);

    // Routing setup
    auto router = new URLRouter;
    router.get("/", &index);
    router.post("/", &getPassword);
    // TODO: API?
    //router.get("/sv_password.json", &getPasswordJson);

    auto fsettings = new HTTPFileServerSettings;
    //fsettings.serverPathPrefix = "/static";
    router.get("*", serveStaticFiles("public/", fsettings));

    listenHTTP(settings, router);
}

auto readSettings() {
    auto json = parseJSON(readText(CONFIG_FILE));

    auto settings = new HTTPServerSettings;
    settings.port = json["port"].str.to!ushort;
    settings.bindAddresses = json["bindAddresses"].array.map!(a => a.str).array;
    //settings.hostName = "stringme";
    return settings;
}


void writeJsonError(HTTPServerResponse res, string message, int status) {
    auto json = Json(["status": Json(status), "error": Json(message)]);
    res.writeJsonBody(json, status);
}

bool hasForm(HTTPServerRequest req, string value) {
    return value in req.form && req.form[value] != "";
}

// Routes

void index(HTTPServerRequest req, HTTPServerResponse res) {
    string[string] errors;

    ConnectString connectString;

    res.render!("index.dt", req, connectString, errors);
}

void getPassword(HTTPServerRequest req, HTTPServerResponse res) {
    string[string] errors;
    ConnectString connectString;

    // Get form params
    if (req.hasForm("string")) {
        connectString = ConnectString(req.form["string"]);
        connectString.validate(errors);

        // Move errors to string field
        if ("rconPassword" in errors) errors["string"] = "password " ~ errors["rconPassword"];
        errors.remove("rconPassword");

        if ("address" in errors) errors["string"] = "address " ~ errors["address"];
        errors.remove("address");
    } else if (req.hasForm("address") && req.hasForm("rcon_password")) {
        connectString.address = req.form["address"];
        connectString.rconPassword = req.form["rcon_password"];

        connectString.validate(errors);
    } else {
        errors["base"] = "Need either a connect string or server details!";
    }

    // Get sv_password
    if (errors.keys.length == 0) {
        RCONClient client;

        try {
            client = connectString.connectRCon();
        } catch (Exception e) {
            errors["base"] = "Failed to connect to server";
        }

        if (client !is null) {
            scope (exit) client.close();

            try {
                if (!client.authenticate(connectString.rconPassword)) {
                    errors["base"] = "Failed to authenticate with rcon";
                } else {
                    connectString.password = client.readConVar("sv_password");
                }
            } catch (Exception e) {
                errors["base"] = "Connection error";
            }
        }
    }

    res.render!("index.dt", req, connectString, errors);
}
