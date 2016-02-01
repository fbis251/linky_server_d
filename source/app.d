import vibe.d;
import vibe.vibe;
import vibe.data.json;
import std.algorithm, std.array, std.stdio, std.format, std.conv;

///
string[] urls;
///
string databaseFile = "links.txt";

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
        .get("/", &index)
        .get("/list", &list)
        .get("/delete/:id", &deleteUrl)
        .get("/save", &save)
        .post("/add", &add)
        .get("*", serveStaticFiles("./public/"));

    auto settings = new HTTPServerSettings;
    settings.port = 8251;
    settings.bindAddresses = ["::1", "0.0.0.0"];
    settings.errorPageHandler = toDelegate(&errorPage);
    listenHTTP(settings, router);
}

///
void index(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    res.render!("index.dt", urls);
}

///
void save(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    enforceHTTP("url" in req.query, HTTPStatus.badRequest, "Missing url field.");
    string url = req.query["url"];
    urls ~= url;
    logInfo("Saved URL: %s", url);
    writeDatabase();
    res.redirect("/");
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
void list(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    auto a = Json.emptyArray;
    foreach(url; urls) {
        a ~= Json(url);
    }

    //auto json = Json(["urls": a]);
    logInfo("Returned %d urls", urls.length);
    res.writeJsonBody(a);
}

///
void deleteUrl(HTTPServerRequest req, HTTPServerResponse res) {
    logRequest(req);
    enforceHTTP("id" in req.params, HTTPStatus.badRequest, "Missing ID field.");
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
    } catch(Exception e) {
        throw new HTTPStatusException(HTTPStatus.badRequest, "Could not delete URL. Invalid ID: " ~ req.params["id"]);
    }
    writeDatabase();
    readDatabase();

    res.redirect("/");
}

///
void errorPage(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error) {
    logRequest(req);
    string pageTitle = format("Error %d", error.code);
    string errorMessage = format("Error %d: %s", error.code, error.message);
	res.render!("error.dt", pageTitle, errorMessage);
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
void logRequest(HTTPServerRequest req) {
    logInfo("%s: %s, %s", timeStamp(), req.toString(), req.json);
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
