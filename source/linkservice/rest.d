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

@path("/api/1")
interface LinksRestApiV1 {


    @headerParam("_basicAuth", "Authorization")
    @path("links")
    Json addLink(string _basicAuth, Link link);

    @headerParam("_basicAuth", "Authorization")
    @path("links/:linkId/archive")
    void setArchiveLink(string _basicAuth, long _linkId);

    @headerParam("_basicAuth", "Authorization")
    @path("links/:linkId/archive")
    void removeArchiveLink(string _basicAuth, long _linkId);

    @headerParam("_basicAuth", "Authorization")
    @path("links/:linkId")
    void deleteLink(string _basicAuth, long _linkId);

    @headerParam("_basicAuth", "Authorization")
    @path("links/:linkId/favorite")
    void setFavoriteLink(string _basicAuth, long _linkId);

    @headerParam("_basicAuth", "Authorization")
    @path("links/:linkId/favorite")
    void removeFavoriteLink(string _basicAuth, long _linkId);

    Json postLogin(string username, string password);

    @headerParam("_basicAuth", "Authorization")
    @path("links/:linkId")
    Json putUpdateLink(string _basicAuth, long _linkId, Link link);

    @headerParam("_basicAuth", "Authorization")
    Json getLinks(string _basicAuth);
}

/// Version 1 of the Link Saver Rest API
class LinkServiceRestApi : LinksRestApiV1 {

    private User getUserFromAuthToken(string basicAuth) {
        debugfln("getUserFromAuthToken() basicAuth = %s", basicAuth);
        string authToken = getAuthTokenFromBasicHeader(basicAuth);
        if(authToken == null || authToken.empty) {
            throw new HTTPStatusException(HTTPStatus.unauthorized, "Please log in");
        }
        User user = usersDb.getUserFromAuthToken(authToken);
        if(!isUserIdValid(user)) {
            throw new HTTPStatusException(HTTPStatus.unauthorized, "Please log in");
        }
        return user;
    }

override:
    Json addLink(string _basicAuth, Link link) {
        logInfo("POST /links");
        debugfln("addLink() link.title = %s, link.url = %s", link.title, link.url);

        User user = getUserFromAuthToken(_basicAuth);
        enforce(validateUrl(link.url), "Invalid URL");
        debugfln("Trying to add URL: %s", link.url);

        Link responseLink = addLinkToDatabase(user.userId, link);
        debugfln("Link add successful? %d, link ID: %d", isLinkIdValid(responseLink), responseLink.linkId);
        AddLinkResponse response;
        response.successful = isLinkIdValid(responseLink);
        response.link = responseLink;
        return serializeToJson(response);
    }

    void setArchiveLink(string _basicAuth, long linkId) {
        logInfo("PUT /links/%d/archive", linkId);

        User user = getUserFromAuthToken(_basicAuth);
        if(!archiveLink(user.userId, linkId, true)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not archive link");
        }
    }

    void removeArchiveLink(string _basicAuth, long linkId) {
        logInfo("DELETE /links/%d/archive", linkId);

        User user = getUserFromAuthToken(_basicAuth);
        if(!archiveLink(user.userId, linkId, false)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not unarchive link");
        }
    }

    void deleteLink(string _basicAuth, long linkId) {
        logInfo("GET /delete/%d", linkId);
        debugfln("getDelete() linkId = %d", linkId);

        User user = getUserFromAuthToken(_basicAuth);
        if(!deleteLinkFromDatabase(user.userId, linkId)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not delete link");
        }
    }

    void setFavoriteLink(string _basicAuth, long linkId) {
        logInfo("PUT /links/%d/favorite", linkId);

        User user = getUserFromAuthToken(_basicAuth);
        if(!favoriteLink(user.userId, linkId, true)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not favorite link");
        }
    }

    void removeFavoriteLink(string _basicAuth, long linkId) {
        logInfo("DELETE /links/%d/favorite", linkId);

        User user = getUserFromAuthToken(_basicAuth);
        if(!favoriteLink(user.userId, linkId, false)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not unfavorite link");
        }
    }

    Json postLogin(string username, string password) {
        logInfo("POST /login");
        debugfln("postLogin() username = %s", username);

        User user = usersDb.getUser(username);
        if(!validateLogin(user, password)) {
            throw new HTTPStatusException(HTTPStatus.unauthorized, "Invalid username or password");
        }

        LoginResponse response;
        response.successful = true;
        response.authToken = user.authToken;
        response.username = user.username;

        return serializeToJson(response);
    }

    Json putUpdateLink(string _basicAuth, long linkId, Link link) {
        logInfo("PUT /links/%d", linkId);

        User user = getUserFromAuthToken(_basicAuth);
        enforce(validateUrl(link.url), "Invalid URL");
        debugfln("Trying to update URL: %s", link.url);

        Link responseLink = updateLinkInDatabase(user.userId, link);
        debugfln("Link update successful? %d, link ID: %d", isLinkIdValid(responseLink), responseLink.linkId);

        if(!isLinkIdValid(responseLink)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not unarchive link");
        }

        AddLinkResponse response;
        response.successful = isLinkIdValid(responseLink);
        response.link = responseLink;
        return serializeToJson(response);
    }

    Json getLinks(string _basicAuth) {
        logInfo("GET /links");

        User user = getUserFromAuthToken(_basicAuth);

        Link[] linksArray = getLinksFromDatabase(user.userId);
        logInfo("User:%s, URL count: %d", user.username, linksArray.length);

        return serializeToJson(linksArray);
    }
}
