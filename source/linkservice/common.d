module linkservice.common;

import std.algorithm, std.stdio;

import d2sqlite3;
import vibe.d;
import vibe.http.router;

import linkservice.utils.crypto;
import linkservice.utils.linksdb;
import linkservice.utils.usersdb;
import linkservice.models;

long INVALID_LINK_ID = -1;
long INVALID_USER_ID = -1;
LinksDb linksDb;     /// The links database
UsersDb usersDb;     /// The users database

///
Link addLinkToDatabase(long userId, Link link) {
    if(!validateUrl(link.url)) {
        return getInvalidLink();
    }

    return linksDb.insertLink(userId, link);
}

///
bool addUrlToDatabase(long userId, string url) {
    if(!validateUrl(url)) return false;
    Link  link;
    link.url = url;
    Link resultLink = linksDb.insertLink(userId, link);
    return isLinkIdValid(resultLink);
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
bool checkPostLogin(string username, string password) {
    debugfln("username %s, password %s", username, password);
    User user = usersDb.getUser(username);
    if(!isUserIdValid(user)) return false;
    return checkBcryptPassword(password, user.passwordHash);
}

/// Returns a Link with an invalid linkId, useful when returning an error
Link getInvalidLink() {
    Link badLink;
    badLink.linkId = INVALID_LINK_ID;
    return badLink;
}

/// Checks whether or not the passed-in Link's linkId is invalid
bool isLinkIdValid(Link link) {
    return link.linkId != INVALID_LINK_ID;
}

/// Checks whether or not the passed-in Users's userId is invalid
bool isUserIdValid(User user) {
    return user.userId != INVALID_USER_ID;
}

///
void errorPage(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error) {
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
