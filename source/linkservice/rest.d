module linkservice.rest;

import vibe.appmain;
import vibe.core.core;
import vibe.core.log;
import vibe.data.json;
import vibe.http.router;
import vibe.http.server;
import vibe.web.rest;

import core.time;

import linkservice.common;
import linkservice.models;

@rootPathFromName
interface Api {
    @headerParam("_authToken", "Authorization")
    Json postAdd(string _authToken, Link link);

    Json postLogin(string username, string password);

    @headerParam("_authToken", "Authorization")
    @path("/archive/:id")
    Json getArchive(string _authToken, int _id, bool isArchived);

    @headerParam("_authToken", "Authorization")
    @path("/delete/:id")
    Json getDelete(string _authToken, int _id);

    @headerParam("_authToken", "Authorization")
    Json getList(string _authToken);
}

///
class LinkServiceRestApi : Api {

override:
    Json postAdd(string _authToken, Link link) {
        checkAuthToken(_authToken);
        enforce(validateUrl(link.url), "Invalid URL");
        SuccessResponse response;

        logInfo("Trying to add URL: %s", link.url);
        response.success = addLinkToDatabase(link);
        // TODO: Return the link object here instead
        // response.link = getLinkFromDb(blah);
        return serializeToJson(response);
    }

    Json postLogin(string username, string password) {
        LoginResponse response;
        response.success = checkPostLogin(username, password);
        if(response.success) {
            response.refreshToken = getUserRefreshToken(username);
            response.username = username;
        }

        return serializeToJson(response);
    }

    Json getDelete(string _authToken, int linkId) {
        checkAuthToken(_authToken);
        logInfo("Trying to delete ID: %d", linkId);
        SuccessResponse response;
        response.success = deleteUrlFromDatabase(userId, linkId);
        return serializeToJson(response);
    }

    Json getArchive(string _authToken, int linkId, bool isArchived) {
        checkAuthToken(_authToken);
        logInfo("Trying to archive ID: %d", linkId);
        SuccessResponse response;
        response.success = false;
        // TODO: Allow setting link.isArchived = isArchived
        return serializeToJson(response);
    }

    Json getList(string _authToken) {
        logInfo("getList()");
        checkAuthToken(_authToken);
        linksList = getLinksFromDatabase(userId);
        logInfo("URLs: %d", linksList.linksList.length);

        return serializeToJson(linksList);
    }
}
