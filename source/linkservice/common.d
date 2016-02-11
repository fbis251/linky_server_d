module linkservice.common;

import vibe.d;
import vibe.http.router;
import std.algorithm;

import linkservice.utils.password;
import linkservice.utils.database;

///
string[] urls;

bool addUrlToDatabase(string url) {
    if(!validateUrl(url)) return false;
    urls ~= url;
    writeDatabase(urls);
    return true;
}

///
bool deleteUrlFromDatabase(int id) {
    bool result = false;
    try {
        if(id < 0 || id >= urls.length) {
            throw new Exception("Index out of range");
        }
        auto removedUrl = urls[id];
        urls = remove(urls, id);
        logInfo("Removed %s", removedUrl);
        result = true;
    } catch(Exception e) {
        throw new HTTPStatusException(HTTPStatus.badRequest, "Could not delete URL. Invalid ID: " ~ to!string(id));
    }
    writeDatabase(urls);
    urls = readDatabase();
    return result;
}

///
void checkAuthToken(string authToken) {
    logInfo("Checking Authorization header");
    if(authToken == getRefreshToken()) {
        logInfo("Valid authToken");
        return;
    }

    // Invalid session
    throw new HTTPStatusException(HTTPStatus.unauthorized, "Please log in");
}

///
bool checkPostLogin(string username, string password) {
    return checkBcryptPassword(password);
}

///
string getUserRefreshToken(string username) {
    return getRefreshToken();
}

///
void errorPage(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error) {
    //logRequest(req);
    string pageTitle = format("Error %d", error.code);
    string errorMessage = format("Error %d: %s", error.code, error.message);
    res.render!("error.dt", pageTitle, errorMessage);
}

///
bool validateUrl(string url) {
    // TODO: URL validation is returning an HTTP 500 in web
    return (url != null || !strip(url).empty);
}

///
string logRequest(HTTPServerRequest req, HTTPServerResponse res) {
    logInfo("%s: %s", timeStamp(), req.toString());

    bool logHeaders = false;
    //logHeaders = true;

    if(logHeaders) {
        auto headers = req.headers.toRepresentation();
        foreach(header; headers) {
            logInfo("%s: %s", header.key, header.value);
        }
    }

    return "";
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
