module linkservice.utils.usersdb;

import std.format, std.datetime;
import d2sqlite3;

import linkservice.models;
import linkservice.common;

const static TALBE_USERS              = "USERS";
const static COLUMN_USER_ID           = "USER_ID";
const static COLUMN_USERNAME          = "USERNAME";
const static COLUMN_PASSWORD_HASH     = "PASSWORD_HASH";
const static COLUMN_AUTH_TOKEN        = "AUTH_TOKEN";
const static COLUMN_LAST_SYNC         = "LAST_SYNC";
const static COLUMN_CREATED_TIMESTAMP = "CREATED_TIMESTAMP";

/// Handles getting and inserting users into the database
class UsersDb {
    Database sqliteDb;

    this(Database database) {
        debugfln("UsersDb()");
        sqliteDb = database;
    }

    /// Gets a user from the database that has the passed-in username
    User getUser(string username) {
        debugfln("getUser(%s)", username);

        string query = format("SELECT * FROM %s WHERE %s = '%s';",
            TALBE_USERS,
            COLUMN_USERNAME,
            username);

        debugfln("Query: %s", query);

        try {
            ResultRange results = sqliteDb.execute(query);
            foreach (Row row; results) {
                User resultUser = getUserFromRow(row);
                debugfln("getUser() username: %s", resultUser.username);
                return resultUser;
            }
        } catch (SqliteException e) {
            errorfln("ERROR WHEN SELECTING USER ", e.msg);
        }

        debugfln("getUser() User not found, returning invalid user");
        return getInvalidUser();
    }

    /// Gets a user from the database that has the passed-in authentication token
    User getUserFromAuthToken(string authToken) {
        debugfln("getUserFromAuthToken(%s)", authToken);

        string query = format("SELECT * FROM %s WHERE %s = '%s';",
            TALBE_USERS,
            COLUMN_AUTH_TOKEN,
            authToken);

        debugfln("Query: %s", query);

        try {
            ResultRange results = sqliteDb.execute(query);
            foreach (Row row; results) {
                User resultUser = getUserFromRow(row);
                debugfln("getUserFromAuthToken() username: %s", resultUser.username);
                return resultUser;
            }
        } catch (SqliteException e) {
            errorfln("ERROR WHEN SELECTING USER ", e.msg);
        }

        debugfln("getUserFromAuthToken() User not found, returning invalid user");
        return getInvalidUser();
    }

    /// Gets a User object from a database row result
    private User getUserFromRow(Row row) {
        User user;
        user.userId = row.peek!long(0);
        user.authToken = row[COLUMN_AUTH_TOKEN].as!string;
        user.createdTimestamp = row[COLUMN_CREATED_TIMESTAMP].as!int;
        user.lastSync = row[COLUMN_LAST_SYNC].as!int;
        user.passwordHash = row[COLUMN_PASSWORD_HASH].as!string;
        user.username = row[COLUMN_USERNAME].as!string;
        return user;
    }
}
