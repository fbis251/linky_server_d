module linkservice.common;

import std.algorithm, std.array, std.format, std.stdio, std.string, std.base64;

import d2sqlite3;
import vibe.http.router;

import linkservice.utils.crypto;
import linkservice.utils.linksdb;
import linkservice.utils.usersdb;
import linkservice.models;

const long INVALID_LINK_ID = 0;
const long INVALID_USER_ID = 0;
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

/// Updates the archived status of a Link
bool archiveLink(long userId, long linkId, bool isArchived) {
    return linksDb.setArchived(userId, linkId, isArchived);
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

/// Updates the favorite status of a Link
bool favoriteLink(long userId, long linkId, bool isFavorite) {
    return linksDb.setFavorite(userId, linkId, isFavorite);
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

string getAuthTokenFromBasicHeader(string authHeader) {
    string result = null;
    string check = authHeader.replace("Basic ", "").replace("basic ", "");
    string decoded = cast(string) Base64.decode(check);
    debugfln("decoded: %s", decoded);
    string[] parts = decoded.split(':');
    if(parts.length == 2) {
        result = parts[0];
    }
    return result;
}

/// Checks whether or not the passed-in Link's linkId is invalid
bool isLinkIdValid(Link link) {
    return link.linkId > INVALID_LINK_ID;
}

/// Checks whether or not the passed-in Users's userId is invalid
bool isUserIdValid(User user) {
    return user.userId > INVALID_USER_ID;
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
