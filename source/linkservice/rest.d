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
import linkservice.models_auth;

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

    private User getUserFromAuthHeader(string basicAuthString) {
        BasicAuthUser authUser = getBasicAuthUser(basicAuthString);
        long userId = authUser.userId;
        if(authUser.token.empty || authUser.mac.empty) {
            errorfln("Error: invalid auth passed(%d, %s, %s",
                     authUser.userId,
                     authUser.token,
                     authUser.mac);
            throw new HTTPStatusException(HTTPStatus.forbidden, "Please log in");
        }

        User user = usersDb.getUser(userId);
        if(!isUserIdValid(user)) {
            errorfln("Error: Invalid userId [%d]", userId);
            throw new HTTPStatusException(HTTPStatus.unauthorized, "Please log in");
        }
        if(!isUserAuthValid(user, authUser)) {
            errorfln("Error: Invalid auth token for userId [%d]", userId);
            throw new HTTPStatusException(HTTPStatus.unauthorized, "Please log in");
        }
        return user;
    }

override:
    Json addLink(string _basicAuth, Link link) {
        logInfo("POST /links");
        debugfln("addLink() link.title = %s, link.url = %s", link.title, link.url);

        User user = getUserFromAuthHeader(_basicAuth);
        enforce(validateUrl(link.url), "Invalid URL");
        debugfln("Trying to add URL: %s", link.url);

        // TODO: Need to throw an error if the Link couldn't be added to database
        Link responseLink = addLinkToDatabase(user.userId, link);
        debugfln("Link add successful? %d, link ID: %d", isLinkIdValid(responseLink), responseLink.linkId);

        if(!isLinkIdValid(responseLink)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not add link");
        }

        AddLinkResponse response;
        response.successful = isLinkIdValid(responseLink);
        response.link = responseLink;
        return serializeToJson(response);
    }

    void setArchiveLink(string _basicAuth, long linkId) {
        logInfo("PUT /links/%d/archive", linkId);

        User user = getUserFromAuthHeader(_basicAuth);
        if(!archiveLink(user.userId, linkId, true)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not archive link");
        }
    }

    void removeArchiveLink(string _basicAuth, long linkId) {
        logInfo("DELETE /links/%d/archive", linkId);

        User user = getUserFromAuthHeader(_basicAuth);
        if(!archiveLink(user.userId, linkId, false)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not unarchive link");
        }
    }

    void deleteLink(string _basicAuth, long linkId) {
        logInfo("GET /delete/%d", linkId);
        debugfln("getDelete() linkId = %d", linkId);

        User user = getUserFromAuthHeader(_basicAuth);
        if(!deleteLinkFromDatabase(user.userId, linkId)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not delete link");
        }
    }

    void setFavoriteLink(string _basicAuth, long linkId) {
        logInfo("PUT /links/%d/favorite", linkId);

        User user = getUserFromAuthHeader(_basicAuth);
        if(!favoriteLink(user.userId, linkId, true)) {
            throw new HTTPStatusException(HTTPStatus.notFound, "Could not favorite link");
        }
    }

    void removeFavoriteLink(string _basicAuth, long linkId) {
        logInfo("DELETE /links/%d/favorite", linkId);

        User user = getUserFromAuthHeader(_basicAuth);
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
        response.userId = user.userId;
        response.authString = getNewUserAuthString(user);
        response.username = username;

        return serializeToJson(response);
    }

    Json putUpdateLink(string _basicAuth, long linkId, Link link) {
        logInfo("PUT /links/%d", linkId);

        User user = getUserFromAuthHeader(_basicAuth);
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

        User user = getUserFromAuthHeader(_basicAuth);

        Link[] linksArray = getLinksFromDatabase(user.userId);
        logInfo("User:%s, URL count: %d", user.username, linksArray.length);

        return serializeToJson(linksArray);
    }
}
