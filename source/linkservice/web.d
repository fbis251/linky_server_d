module linkservice.web;

import std.algorithm, std.array, std.conv, std.format, std.stdio, std.string;
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
    @path("/")
    void getHome(string _authUser, string _error) {
        auto settings = m_userSettings;
        string errorMessage = _error;
        auto linksArray = getLinksFromDatabase(getUserId());
        reverse(linksArray);
        render!("home.dt", serverConfig, linksArray, settings, errorMessage);
    }

    @auth
    @path("/link/delete")
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

        redirect("/");
    }

    @auth
    @errorDisplay!getHome
    @path("/link/edit")
    void getEditLink(string _authUser, string _error, long linkId) {
        debugfln("getEditLink(linkId: [%d])", linkId);
        Link link;
        string errorMessage = _error;
        if(errorMessage.empty) {
            link = getLinkFromDatabase(getUserId(), linkId);
            enforce(isLinkIdValid(link), "Invalid link, please log out and back in and try again.");
        }
        render!("edit_link.dt", serverConfig, link, errorMessage);
    }

    @auth
    @errorDisplay!getEditLink
    @path("/link/edit")
    void postUpdateLink(string _authUser,
                        long linkId,
                        string title,
                        string url,
                        string category,
                        bool archived,
                        bool favorite) {
        title = strip(title);
        url = strip(url);
        category = strip(category);
        debugfln("postUpdateLink(title: [%s], url: [%s], category: [%s], archived: [%d], favorite:[%d]",
                 title,
                 url,
                 category,
                 archived,
                 favorite);

        enforce(!strip(title).empty, "Title cannot be blank");
        enforce(validateTitle(title), format("Title is too long, max characters: %d", MAX_TITLE_LENGTH));
        enforce(!strip(url).empty, "URL cannot be blank");
        enforce(validateCategory(category),
                format("Category is too long, max characters: %d", MAX_CATEGORY_LENGTH));

        Link link;
        link.linkId     = linkId;
        link.category   = category;
        link.isArchived = archived;
        link.isFavorite = favorite;
        link.title      = title;
        link.url        = url;
        debugfln("Trying to update URL: %s", link.url);

        Link responseLink = updateLinkInDatabase(getUserId(), link);
        enforce(isLinkIdValid(responseLink), "Error updating the database, please contact the developer");
        redirect("/");
    }

    @auth
    @path("/user/edit")
    void getEditUser(string _authUser, string _error) {
        long userId = getUserId();
        try {
            auto user = getUser(userId);
            enforce(isUserIdValid(user), "Invalid User, please log out and back in.");
            string errorMessage = _error;
            render!("edit_user.dt", serverConfig, user, errorMessage);
        } catch(Exception e) {
            throw new HTTPStatusException(HTTPStatus.badRequest, format("Could not edit User, ID: %d", userId));
        }
    }

    @auth
    @errorDisplay!getEditUser
    @path("/user/edit")
    void postEditUser(string _authUser,
            string currentPassword,
            string newPassword,
            string repeatedNewPassword,
            bool forceClientLogout) {
        auto userId = getUserId();
        debugfln("Trying to update User with ID: %d", userId);
        auto user = getUser(userId);
        enforce(validateLogin(user, currentPassword),
                    "Current password is incorrect");
        enforce(validateLogin(user, currentPassword),
                    "Current password is incorrect");

        if(forceClientLogout) {
            enforce(updateUserAuthInfo(userId), "Error forcing Android clients to log out");
        }

        if(!newPassword.empty && !repeatedNewPassword.empty) {
            if(validatePasswordChange(newPassword, repeatedNewPassword)) {
                // New passwords match, attempt to update in DB
                enforce(updateUserPassword(userId, newPassword), "Error updating your password");
            } else {
                enforce(false, "Your new passwords do not match");
            }
        }

        redirect("/");
    }

    @auth
    @path("/link/save")
    void getSave(string _authUser, string url) {
        Link link;
        link.url = strip(url);
        enforce(validateUrl(link.url), "Invalid URL: " ~ link.url);
        Link responseLink = addLinkToDatabase(getUserId(), link);
        debugfln("Link add successful? %d, link ID: %d", isLinkIdValid(responseLink), responseLink.linkId);
        enforce(isLinkIdValid(responseLink), "Could not save link to database");

        redirect(format("/link/edit/?linkId=%d", responseLink.linkId));
    }

    // Method name gets mapped to "GET /login" and a single optional
    // _error parameter is accepted (see postLogin)
    void getLogin(string _error = null) {
        string errorMessage = _error;
        render!("login.dt", serverConfig, errorMessage);
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
        enforce(validateLogin(user, password), "Invalid user name or password.");

        UserSettings s;
        s.loggedIn = true;
        s.user = user;
        m_userSettings = s;
        redirect("/");
    }

    // GET /logout
    // This method accepts the raw HTTPServerResponse to access advanced fields
    void getLogout(scope HTTPServerResponse res) {
        m_userSettings = UserSettings.init;
        // NOTE: there is also a terminateSession() function in vibe.web.web
        // that avoids the need to work with a raw HTTPServerResponse.
        res.terminateSession();
        redirect("/login");
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
