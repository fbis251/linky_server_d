module linkservice.common;

import std.algorithm, std.stdio;

import d2sqlite3;
import vibe.d;
import vibe.http.router;

import linkservice.utils.crypto;
import linkservice.utils.linksdb;
import linkservice.models;

int userId = 0; /// TODO: change me to a real ID
LinksDb linksDb; ///
LinksList linksList; ///

///
bool addLinkToDatabase(linkservice.models.Link link) {
    if(!validateUrl(link.url)) return false;
    return linksDb.insertLink(userId, link);
}

///
bool addUrlToDatabase(long userId, string url) {
    if(!validateUrl(url)) return false;
    linkservice.models.Link  link;
    link.url = url;
    return linksDb.insertLink(userId, link);
}

///
LinksList getLinksFromDatabase(long userId) {
    return linksDb.readDatabase(userId);
}

///
bool deleteUrlFromDatabase(long userId, long linkId) {
    if(linkId < 0) {
        const string errorMessage = format("Could not delete URL. Invalid ID: %d", linkId);
        throw new HTTPStatusException(HTTPStatus.badRequest, errorMessage);
    }

    return linksDb.deleteLink(userId, linkId);
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
string logRequest(HTTPServerRequest req) {
    logInfo("%s: %s", timeStamp(), req.toString());
    version(logHeaders) {
        auto headers = req.headers.toRepresentation();
        foreach(header; headers) {
            logInfo("%s: %s", header.key, header.value);
        }
    }

    return "";
}

void debugfln(Char, A...)(in Char[] fmt, A args) {
    debug {
        writefln(fmt, args);
    }
}

void errorfln(Char, A...)(in Char[] fmt, A args) {
    writefln(fmt, args);
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
