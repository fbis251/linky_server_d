module linkservice.common;

import std.algorithm, std.stdio;

import d2sqlite3;
import vibe.d;
import vibe.http.router;

import linkservice.utils.crypto;
import linkservice.utils.linksdb;
import linkservice.utils.usersdb;
import linkservice.models;

const long INVALID_LINK_ID = -1;
const long INVALID_USER_ID = -1;
LinksDb linksDb;     /// The links database
UsersDb usersDb;     /// The users database

/// Adds a Link to the database for the User with userId
Link addLinkToDatabase(long userId, Link link) {
    if(!validateUrl(link.url)) {
        return getInvalidLink();
    }

    return linksDb.insertLink(userId, link);
}

/// Adds a URL into the database for the User with userId
bool addUrlToDatabase(long userId, string url) {
    if(!validateUrl(url)) return false;
    Link  link;
    link.url = url;
    Link resultLink = linksDb.insertLink(userId, link);
    return isLinkIdValid(resultLink);
}

/// Deletes a Link from the database
bool deleteLinkFromDatabase(long userId, long linkId) {
    if(linkId < 0) {
        const string errorMessage = format("Could not delete URL. Invalid ID: %d", linkId);
        throw new HTTPStatusException(HTTPStatus.badRequest, errorMessage);
    }

    return linksDb.deleteLink(userId, linkId);
}

/// Renders an error page with the HTTP error message and code
void errorPage(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error) {
    string pageTitle = format("Error %d", error.code);
    string errorMessage = format("Error %d: %s", error.code, error.message);
    res.render!("error.dt", pageTitle, errorMessage);
}

/// Gets all the stored Links for the user with userId from the database
Link[] getLinksFromDatabase(long userId) {
    return linksDb.readDatabase(userId);
}

/// Returns a Link with an invalid linkId, useful when returning an error
Link getInvalidLink() {
    Link badLink;
    badLink.linkId = INVALID_LINK_ID;
    return badLink;
}

/// Returns a User with an invalid userId, useful when returning an error
User getInvalidUser() {
    User badUser;
    badUser.userId = INVALID_USER_ID;
    return badUser;
}

/// Checks whether or not the passed-in Link's linkId is invalid
bool isLinkIdValid(Link link) {
    return link.linkId != INVALID_LINK_ID;
}

/// Checks whether or not the passed-in Users's userId is invalid
bool isUserIdValid(User user) {
    return user.userId != INVALID_USER_ID;
}

/// Checks that the User is valid and passwed-in password matches the User's stored passwordHash
bool validateLogin(User user, string password) {
    return isUserIdValid(user) && checkBcryptPassword(password, user.passwordHash);
}

/// Validates a URL string to make sure it isn't null or empty
bool validateUrl(string url) {
    return (url != null || !strip(url).empty);
}

//////////////////
// Logging code //
//////////////////

/// Prints debugging messages to stdout. Messages will only be printed in debug version
void debugfln(Char, A...)(in Char[] fmt, A args) {
    debug {
        writefln(fmt, args);
    }
}

/// Prints error messages to stdout
void errorfln(Char, A...)(in Char[] fmt, A args) {
    writefln(fmt, args);
}

/// Logs an HTTP request to stdout
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

/// Returns a formatted timestamp string
string timeStamp() {
    const auto currentTime = Clock.currTime();

    auto month = currentTime.month;
    auto day = currentTime.day;
    auto hour = currentTime.hour;
    auto minute = currentTime.minute;
    auto second = currentTime.second;

    return format("%d/%02d %02d:%02d:%02d", month, day, hour, minute, second);
}
