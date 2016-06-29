module linkservice.web;

import std.algorithm, std.array, std.stdio, std.format, std.conv;
import std.exception : enforce;
import vibe.core.log;
import vibe.http.fileserver;
import vibe.http.router;
import vibe.http.server;
import vibe.utils.validation;
import vibe.web.web;

import linkservice.common;
import linkservice.models;

/// Aggregates all information about the currently logged in user (if any).
struct UserSettings {
    bool loggedIn = false;
    User user = getInvalidUser(); /// Invalid User by default
}

/// The methods of this class will be mapped to HTTP routes and serve as request handlers.
class LinkServiceWeb {
    private {
        // Type-safe and convenient access of user settings. This
        // SessionVar will store the contents of the variable in the
        // HTTP session with the key "settings". A session will be
        // started automatically as soon as m_userSettings gets modified
        // modified.
        SessionVar!(UserSettings, "settings") m_userSettings;
    }

    // overrides the path that gets inferred from the method name to
    @auth
    @path("/") void getHome(string _authUser) {
        auto settings = m_userSettings;
        auto linksArray = getLinksFromDatabase(getUserId());
        render!("home.dt", linksArray, settings);
    }

    @auth
    void getDelete(string _authUser, long linkId) {
        bool result = false;

        try {
            if(linkId < 0) {
                throw new Exception("Index out of range");
            }
            result = deleteLinkFromDatabase(getUserId(), linkId);
        } catch(Exception e) {
            throw new HTTPStatusException(HTTPStatus.badRequest, format("Could not delete URL. Invalid ID: %d", linkId));
        }

        redirect("./");
    }

    @auth
    void getSave(string _authUser, string url) {
        enforce(validateUrl(url), "Invalid URL");
        addUrlToDatabase(getUserId(), url);
        redirect("./");
    }

    // Method name gets mapped to "GET /login" and a single optional
    // _error parameter is accepted (see postLogin)
    void getLogin(string _error = null) {
        string errorMessage = _error;
        render!("login.dt", errorMessage);
    }

    // Method name gets mapped to "POST /login" and two HTTP form parameters
    // (taken from HTTPServerRequest.form or .query) are accepted.
    //
    // The @errorDisplay attribute causes any exceptions to be passed to the
    // _error parameter of getLogin to render the error. The same happens for
    // validation errors (ValidUsername).
    @errorDisplay!getLogin
    void postLogin(ValidUsername username, string password) {
        debugfln("postLogin() username: %s, password: %s", username, password);

        User user = usersDb.getUser(username);
        enforceHTTP(validateLogin(user, password), HTTPStatus.forbidden, "Invalid user name or password.");

        UserSettings s;
        s.loggedIn = true;
        s.user = user;
        m_userSettings = s;
        redirect("./");
    }

    // GET /logout
    // This method accepts the raw HTTPServerResponse to access advanced fields
    void getLogout(scope HTTPServerResponse res) {
        m_userSettings = UserSettings.init;
        // NOTE: there is also a terminateSession() function in vibe.web.web
        // that avoids the need to work with a raw HTTPServerResponse.
        res.terminateSession();
        redirect("./login");
    }

    // GET /settings
    // This method uses a custom @auth attribute (defined below) that injects
    // code to ensure correct authentication and that fills the _authUser parameter
    // with the authenticated user name
    @auth
    void getSettings(string _authUser, string _error = null) {
        UserSettings settings = m_userSettings;
        auto error = _error;
        auto pageTitle = "asdf";
        auto errorMessage ="aa";
        render!("error.dt", pageTitle, errorMessage, error, settings);
    }

    // Defines the @auth attribute in terms of an @before annotation. @before causes
    // the given method (ensureAuth) to be called before the request handler is run.
    // It's return value will be passed to the "_authUser" parameter of the handler.
    private enum auth = before!ensureAuth("_authUser");

    // Implementation of the @auth attribute - ensures that the user is logged in and
    // redirects to the log in page otherwise (causing the actual request handler method
    // to be skipped).
    private string ensureAuth(scope HTTPServerRequest req, scope HTTPServerResponse res) {
        if (!LinkServiceWeb.m_userSettings.loggedIn) redirect("/login");
        return LinkServiceWeb.m_userSettings.user.username;
    }

    private long getUserId() {
        return m_userSettings.user.userId;
    }

    // Adds support for using private member functions with "before". The ensureAuth method
    // is only used internally in this class and should be private, but by default external
    // template code has no access to private symbols, even if those are explicitly passed
    // to the template. This mixin template defined in vibe.web.web creates a special class
    // member that enables this usage pattern.
    mixin PrivateAccessProxy;
}
