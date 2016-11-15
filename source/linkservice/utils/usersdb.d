module linkservice.utils.usersdb;

import std.format, std.datetime;
import d2sqlite3;

import linkservice.models;
import linkservice.common;

const static TALBE_USERS              = "USERS";
const static COLUMN_USER_ID           = "USER_ID";
const static COLUMN_USERNAME          = "USERNAME";
const static COLUMN_PASSWORD_HASH     = "PASSWORD_HASH";
const static COLUMN_AUTH_KEY          = "AUTH_KEY";
const static COLUMN_LAST_SYNC         = "LAST_SYNC";
const static COLUMN_CREATED_TIMESTAMP = "CREATED_TIMESTAMP";

/// Handles getting and inserting users into the database
class UsersDb {
    private Database sqliteDb;

    this(Database database) {
        debugfln("UsersDb()");
        sqliteDb = database;
    }

    /// Gets a user from the database that has the passed-in username
    User getUser(long userId) {
        debugfln("getUser(%s)", userId);

        string query = format("SELECT * FROM %s WHERE %s = '%s';",
            TALBE_USERS,
            COLUMN_USER_ID,
            userId);

        debugfln("Query: %s", query);

        try {
            ResultRange results = sqliteDb.execute(query);
            foreach (Row row; results) {
                User resultUser = getUserFromRow(row);
                debugfln("getUser() username: %s", resultUser.username);
                return resultUser;
            }
        } catch (SqliteException e) {
            errorfln("ERROR WHEN SELECTING USER, error: %s", e.msg);
        }

        debugfln("getUser() User not found, returning invalid user");
        return getInvalidUser();
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
            errorfln("ERROR WHEN SELECTING USER username: %s, error: %s", username, e.msg);
        }

        debugfln("getUser() User not found, returning invalid user");
        return getInvalidUser();
    }

    public bool updateUserAuthKey(long userId, string newAuthKey) {
        debugfln("updateUserAuthKey(%d, %s)", userId, newAuthKey);

        string query = format("UPDATE %s SET %s = \"%s\" WHERE %s = %d;",
            TALBE_USERS,
            COLUMN_AUTH_KEY,
            newAuthKey,
            COLUMN_USER_ID,
            userId);

        debugfln("Query: %s", query);

        int previousChangeCount = sqliteDb.totalChanges;
        try {
            Statement statement = sqliteDb.prepare(query);
            statement.execute();
            // If the query was successful the total change count will be increased
            bool result = sqliteDb.totalChanges > previousChangeCount;
            debugfln("updateUserAuthKey() result: %s", result ? "true" : "false");
            return result;
        } catch (SqliteException e) {
            errorfln("ERROR updating user auth key, error: %s", e.msg);
        }

        return false;
    }

    public bool updateUserPasswordHash(long userId, string newPasswordHash) {
        debugfln("updateUserPasswordHash(%d, %s)", userId, newPasswordHash);

        string query = format("UPDATE %s SET %s = \"%s\" WHERE %s = %d;",
            TALBE_USERS,
            COLUMN_PASSWORD_HASH,
            newPasswordHash,
            COLUMN_USER_ID,
            userId);

        debugfln("Query: %s", query);

        int previousChangeCount = sqliteDb.totalChanges;
        try {
            Statement statement = sqliteDb.prepare(query);
            statement.execute();
            // If the query was successful the total change count will be increased
            bool result = sqliteDb.totalChanges > previousChangeCount;
            debugfln("updateUserPasswordHash() result: %s", result ? "true" : "false");
            return result;
        } catch (SqliteException e) {
            errorfln("ERROR updating user password, error: %s", e.msg);
        }

        return false;
    }

    /// Gets a User object from a database row result
    private User getUserFromRow(Row row) {
        User user;
        user.userId = row.peek!long(0);
        user.authKey = row[COLUMN_AUTH_KEY].as!string;
        user.createdTimestamp = row[COLUMN_CREATED_TIMESTAMP].as!int;
        user.lastSync = row[COLUMN_LAST_SYNC].as!int;
        user.passwordHash = row[COLUMN_PASSWORD_HASH].as!string;
        user.username = row[COLUMN_USERNAME].as!string;
        return user;
    }
}
