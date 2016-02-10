module link_service_rest;

import vibe.appmain;
import vibe.core.core;
import vibe.core.log;
import vibe.data.json;
import vibe.http.router;
import vibe.http.server;
import vibe.web.rest;

import core.time;

import link_service_common;

struct LinksList {
    Link[] linksList;
}

struct Link {
    int linkId;
    string category;
    int timestamp;
    string title;
    string url;
}

struct LoginRequest {
    string username;
    string password;
}

struct LoginResponse {
    bool success;
    string refreshToken;
    string username;
}

struct SuccessResponse {
    bool success;
}

@rootPathFromName
interface Api {
    @headerParam("_authToken", "Authorization")
    Json postAdd(string _authToken, string linkJsonString);

    @headerParam("_authToken", "Authorization")
    @path("/archive/:id")
    Json getArchive(string _authToken, int _id);

    @headerParam("_authToken", "Authorization")
    Json getList(string _authToken, string message = null);

    @path(":username/:password")
    Json postLogin(string _username, string _password);
}

///
class LinkServiceRestApi : Api {
override:
    Json postAdd(string _authToken, string linkJsonString) {
        checkAuthToken(_authToken);
        enforce(linkJsonString != "", "Invalid request.");
        SuccessResponse response;

        auto json = parseJsonString(linkJsonString);
        logInfo("Trying to add URL: %s", json["url"]);
        foreach (string key, value; json) {
            logInfo("%s: %s", key, value);
            if(key == "url") {
                string newUrl = json["url"].get!string;
                enforce(validateUrl(newUrl), "Invalid URL");
                response.success = addUrlToDatabase(newUrl);
                logInfo("Saved URL: %s", newUrl);
            }
        }

        return serializeToJson(response);
    }

    Json getArchive(string _authToken, int id) {
        checkAuthToken(_authToken);
        logInfo("Trying to delete ID: %d", id);
        SuccessResponse response;
        response.success = deleteUrlFromDatabase(id);
        return serializeToJson(response);
    }

    Json getList(string _authToken, string message) {
        checkAuthToken(_authToken);
        logInfo("URLs: %d", urls.length);

        LinksList linksList;
        int id = 0;
        foreach(url; urls) {
            Link link;
            link.linkId = id++;
            link.url = url;
            linksList.linksList ~= link;
        }

        return serializeToJson(linksList);
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
}
