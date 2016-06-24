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
    Json getArchive(string _authToken, long _id, bool isArchived);

    @headerParam("_authToken", "Authorization")
    @path("/delete/:id")
    Json getDelete(string _authToken, long _id);

    @headerParam("_authToken", "Authorization")
    Json getList(string _authToken);
}

///
class LinkServiceRestApi : Api {

    User getUserFromAuthToken(string authToken) {
        User user = usersDb.getUserFromAuthToken(authToken);
        if(!isUserIdValid(user)) {
            throw new HTTPStatusException(HTTPStatus.unauthorized, "Please log in");
        }
        return user;
    }

override:
    Json postAdd(string _authToken, Link link) {
        logInfo("POST /add");
        debugfln("postAdd() link.title = %s, link.url = %s", link.title, link.url);
        enforce(validateUrl(link.url), "Invalid URL");

        User user = getUserFromAuthToken(_authToken);
        AddLinkResponse response;

        debugfln("Trying to add URL: %s", link.url);
        Link responseLink = addLinkToDatabase(user.userId, link);
        response.successful = isLinkIdValid(responseLink);
        response.link = responseLink;
        return serializeToJson(response);
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

    Json getArchive(string _authToken, long linkId, bool isArchived) {
        logInfo("GET /archived/%d?isArchived=%d", linkId, isArchived);
        debugfln("getDelete() linkId = %d, isArchived = %d", linkId, isArchived);

        User user = getUserFromAuthToken(_authToken);
        SuccessResponse response;
        response.successful = false;
        // TODO: Allow setting link.isArchived = isArchived
        return serializeToJson(response);
    }

    Json getDelete(string _authToken, long linkId) {
        logInfo("GET /delete/%d", linkId);
        debugfln("getDelete() linkId = %d", linkId);

        User user = getUserFromAuthToken(_authToken);
        SuccessResponse response;
        response.successful = deleteLinkFromDatabase(user.userId, linkId);
        return serializeToJson(response);
    }

    Json getList(string _authToken) {
        logInfo("GET /list");

        User user = getUserFromAuthToken(_authToken);

        LinksList linksList = getLinksFromDatabase(user.userId);
        logInfo("User:%s, URL count: %d", user.username, linksList.linksList.length);

        return serializeToJson(linksList);
    }
}
