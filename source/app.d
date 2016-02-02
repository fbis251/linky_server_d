import vibe.d;
import vibe.vibe;
import vibe.data.json;
import std.algorithm, std.array, std.stdio, std.format, std.conv;

import password;

///
string[] urls;
///
string databaseFile = "private/links.txt";

///
void main() {
    // returns false if a help screen has been requested and displayed (--help)
    if (!finalizeCommandLineOptions())
        return;
    lowerPrivileges();
    readDatabase();
    runEventLoop();
    writeDatabase();
}

///
shared static this() {
    auto router = new URLRouter;

    router
        .get("/static/*", serveStaticFiles("./public/"))
        .get("/hash", &hash)
        .get("/", &index)
        .post("/login", &login)
        // restrict all following routes to authenticated users:
        //.any("*", &checkLogin)
        .post("/add", &add)
        .get("/delete/:id", &deleteUrl)
        .get("/home", &home)
        .get("/list", &list)
        .get("/logout", &logout)
        .get("/save", &save);

    auto settings = new HTTPServerSettings;
    settings.sessionStore = new MemorySessionStore;
    settings.port = 8251;
    settings.bindAddresses = ["::", "0.0.0.0"];
    settings.errorPageHandler = toDelegate(&errorPage);
    listenHTTP(settings, router);
}

///
void hash(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    auto hash = generateHash("pass");
    writeHashFile(hash);
    res.writeBody(hash);
}

///
void index(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);

    if(req.session) {
        res.redirect("/home");
    } else {
        res.render!("index.dt");
    }
}

///
void add(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    bool result = false;

    Json requestJson = req.json;
    foreach (string key, value; requestJson) {
        logInfo("%s: %s", key, value);
        if(key == "url") {
            string newUrl = requestJson["url"].get!string;
            urls ~= newUrl;
            logInfo("Saved URL: %s", newUrl);
            result = true;
        }
    }

    writeDatabase();
    auto response = Json(["success": Json(result)]);
    res.writeJsonBody(response);
}

///
void deleteUrl(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    enforceHTTP("id" in req.params, HTTPStatus.badRequest, "Missing ID field.");
    bool result = false;
    auto idString = req.params["id"];
    int id;

    try {
        formattedRead(idString, "%s", &id);

        if(id < 0 || id >= urls.length) {
            throw new Exception("Index out of range");
        }
        auto removedUrl = urls[id];
        urls = remove(urls, id);
        logInfo("Removed %s", removedUrl);
        result = true;
    } catch(Exception e) {
        throw new HTTPStatusException(HTTPStatus.badRequest, "Could not delete URL. Invalid ID: " ~ req.params["id"]);
    }
    writeDatabase();
    readDatabase();

    auto response = Json(["success": Json(result)]);
    res.writeJsonBody(response);
}

///
void home(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    res.render!("home.dt", urls);
}

///
void list(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    auto a = Json.emptyArray;
    foreach(url; urls) {
        a ~= Json(url);
    }

    logInfo("Returned %d urls", urls.length);
    res.writeJsonBody(a);
}

///
void login(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    enforceHTTP("password" in req.form, HTTPStatus.badRequest, "Missing password field.");

    logInfo("Trying to log in");
    // todo: verify user/password here
    string password = req.form["password"];
    if(checkBcryptPassword(password)) {
        auto session = res.startSession();
        //session.set("password", req.form["password"]);
        logInfo("Refresh Token: %s", getRefreshToken());

        // TODO: Return auth token as JSON
        //auto response = Json(["success": Json(true), "refreshToken": Json(getRefreshToken())]);
        //res.writeJsonBody(response);
        res.redirect("/home");
    } else {
        //auto response = Json(["success": Json(false)]);
        //res.writeJsonBody(response);
        res.redirect("/");
    }
}

///
void logout(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    if(req.session) res.terminateSession();

    res.redirect("/");
}

///
void save(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    enforceHTTP("url" in req.query, HTTPStatus.badRequest, "Missing url field.");
    string url = req.query["url"];
    urls ~= url;
    logInfo("Saved URL: %s", url);
    writeDatabase();
    res.redirect("/home");
}

////////////////////////////////////////////////////////////////////////////////////////////////////
/// Helper Functions
////////////////////////////////////////////////////////////////////////////////////////////////////

void checkLogin(HTTPServerRequest req, HTTPServerResponse res) {
    // force a redirect to / for unauthenticated users
    if (!req.session) {
        if("Authorization" in req.headers) {
            string authToken = req.headers["Authorization"];
            if(authToken == getRefreshToken()) {
                logInfo("Valid authToken");
                auto session = res.startSession();
                return;
            }
        }

        // Invalid session, redirect to login page
        //res.redirect("/");
        throw new HTTPStatusException(HTTPStatus.unauthorized, "Please log in");
    }
}

///
void errorPage(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error) {
    logRequest(req);
    string pageTitle = format("Error %d", error.code);
    string errorMessage = format("Error %d: %s", error.code, error.message);
    res.render!("error.dt", pageTitle, errorMessage);
}

///
void logRequest(HTTPServerRequest req) {
    logInfo("%s: %s, %s", timeStamp(), req.toString(), req.json);

    auto headers = req.headers.toRepresentation();
    foreach(header; headers) {
        logInfo("%s: %s", header.key, header.value);
    }
}

///
void readDatabase() {
    auto lines = File(databaseFile)   // Open for reading
        .byLineCopy()      // Read persistent lines
        .array();           // into an array

    urls = lines.array;
    logInfo("Read %d URLs from database", urls.length);
}
///

void writeDatabase() {
    auto f = File(databaseFile, "w"); // open for appending
    foreach(url; urls) {
        f.writeln(url);
    }
    f.close();
    logInfo("Done writing %d URLs to the database", urls.length);
}

///
auto timeStamp() {
    const auto currentTime = Clock.currTime();

    auto month = currentTime.month;
    auto day = currentTime.day;
    auto hour = currentTime.hour;
    auto minute = currentTime.minute;
    auto second = currentTime.second;

    return format("%d/%02d %02d:%02d:%02d", month, day, hour, minute, second);
}
