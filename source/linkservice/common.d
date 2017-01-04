module linkservice.common;

import std.algorithm, std.array, std.base64, std.conv, std.format, std.stdio, std.string;

import d2sqlite3;
import vibe.http.router;
import dini;

import linkservice.utils.crypto;
import linkservice.utils.linksdb;
import linkservice.utils.usersdb;
import linkservice.models;
import linkservice.models_auth;
import linkservice.models_server;

// Form submission validation, max field lengths
const int MAX_CATEGORY_LENGTH = 50;
const int MAX_TITLE_LENGTH = 100;

const long INVALID_LINK_ID = 0;
const long INVALID_USER_ID = 0;
LinksDb linksDb;     /// The links database
UsersDb usersDb;     /// The users database
LinkyConfig serverConfig;

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

/// Gets one stored Link for the user with userId from the database
Link getLinkFromDatabase(long userId, long linkId) {
    return linksDb.getLink(userId, linkId);
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

/// Gets the user with the passed-in userId from the database
User getUser(long userId) {
    return usersDb.getUser(userId);
}

/// Decodes a basic auth header string into a BasicAuthUser object. An invalid user will have empty fields
BasicAuthUser getBasicAuthUser(string authHeader) {
    BasicAuthUser authUser;
    string check = authHeader.replace("Basic ", "").replace("basic ", "");
    string decoded = cast(string) Base64.decode(check);
    debugfln("decoded: %s", decoded);
    string[] parts = decoded.split(':');
    if(parts.length == 3) {
        authUser.userId = to!long(parts[0]);
        authUser.token = parts[1];
        authUser.mac = parts[2];
    }
    return authUser;
}

/// Checks whether or not the passed-in Link's linkId is invalid
bool isLinkIdValid(Link link) {
    return link.linkId > INVALID_LINK_ID;
}

/// Checks whether or not the passed-in Users's userId is invalid
bool isUserIdValid(User user) {
    return user.userId > INVALID_USER_ID;
}

/// Updates the Link data in the database
Link updateLinkInDatabase(long userId, Link link) {
    if(!validateUrl(link.url)) {
        return getInvalidLink();
    }

    return linksDb.updateLink(userId, link);
}

/// Generates a new auth user string for the passed-in User. Useful for a login response in the REST service
string getNewUserAuthString(const User user) {
    ubyte[AUTH_KEY_LENGTH] key = Base64.decode(user.authKey)[0 .. AUTH_KEY_LENGTH];
    ubyte[AUTH_TOKEN_LENGTH] token = generateNewAuthToken();
    return generateAuthString(key, token);
}

/// Generates a new authentication key for the User with the passed-in userId
bool updateUserAuthInfo(const long userId) {
    string newAuthKey = Base64.encode(generateNewAuthKey());
    return usersDb.updateUserAuthKey(userId, newAuthKey);
}

/// Validates the passed-in BasicAuthUser and verifies that the auth token is valid for the User's stored key
bool isUserAuthValid(const User user, const BasicAuthUser basicAuthUser) {
    ubyte[] userKey = Base64.decode(user.authKey);
    ubyte[] decodedToken = Base64.decode(basicAuthUser.token);
    ubyte[] decodedMac = Base64.decode(basicAuthUser.mac);
    if(userKey.length != AUTH_KEY_LENGTH
       || decodedToken.length != AUTH_TOKEN_LENGTH
       || decodedMac.length != AUTH_MAC_LENGTH) {
        // Invalid lengths, most likely not a valid auth string
        return false;
    }
    ubyte[AUTH_KEY_LENGTH] key = userKey[0 .. AUTH_KEY_LENGTH];
    ubyte[AUTH_TOKEN_LENGTH] token = decodedToken[0 .. AUTH_TOKEN_LENGTH];
    ubyte[AUTH_MAC_LENGTH] mac = decodedMac[0 .. AUTH_MAC_LENGTH];
    return verifyAuthToken(key, token, mac);
}

/// Checks that the User is valid and passwed-in password matches the User's stored passwordHash
bool validateLogin(User user, string password) {
    debugfln("validateLogin(%s, %s)", user, password);
    auto userIdValid = isUserIdValid(user);
    auto passValid = verifyPassword(password, user.passwordHash);
    debugfln("user: %s, pass: %s", userIdValid ? "true" : "false", passValid ? "true" : "false");
    return userIdValid && passValid;
}

/// Makes sure that the new passwords are valid
bool validatePasswordChange(string newPassword, string repeatedNewPassword) {
    return newPassword == repeatedNewPassword;
}

/// Validates a URL string to make sure it isn't empty
bool validateCategory(const string category) {
    return category.length <= MAX_CATEGORY_LENGTH;
}

/// Validates a title string to make sure it isn't empty
bool validateTitle(const string title) {
    return !strip(title).empty && title.length <= MAX_TITLE_LENGTH;
}

/// Validates a URL string to make sure it isn't empty
bool validateUrl(const string url) {
    return !strip(url).empty;
}

/// Updates a user's password in the database
bool updateUserPassword(long userId, string newPassword) {
    string newPasswordHash = hashPassword(newPassword);
    return usersDb.updateUserPasswordHash(userId, newPasswordHash);
}

///////////////////////////
// Configuration Parsing //
///////////////////////////
LinkyConfig getIniConfig(Ini ini) {
    LinkyConfig config;
    if(ini.hasSection("db")) {
        config.databasePath = ini["db"].getKey("database_path", config.databasePath);
    }
    if(ini.hasSection("server")) {
        auto section = ini["server"];
        config.siteTitle = section.getKey("site_title", config.siteTitle);
        config.address = section.getKey("address", config.address);
        if(section.hasKey("port")) {
            config.port = to!ushort(section.getKey("port"));
        }
    }
    return config;
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
