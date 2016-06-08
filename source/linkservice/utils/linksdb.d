module linkservice.utils.linksdb;

import std.format, std.datetime;
import d2sqlite3;

import linkservice.models;
import linkservice.common;

const static TABLE_NAME = "LINKS";
const static COLUMN_LINK_ID = "LINK_ID";
const static COLUMN_CATEGORY = "CATEGORY";
const static COLUMN_IS_ARCHIVED = "IS_ARCHIVED";
const static COLUMN_IS_FAVORITE = "IS_FAVORITE";
const static COLUMN_TIMESTAMP = "TIMESTAMP";
const static COLUMN_TITLE = "TITLE";
const static COLUMN_URL = "URL";
const static COLUMN_USER_ID = "USER_ID";

class LinksDb {
    Database sqliteDb;

    this(Database database){
        sqliteDb = database;
    }

    LinksList readDatabase(long userId) {
        LinksList linksList;

        string query = format("SELECT * FROM LINKS WHERE %s = %d", COLUMN_USER_ID, userId);
        ResultRange results = sqliteDb.execute(query);
        foreach (Row row; results) {
            Link rowLink = getRow(row);
            debugfln("ID: %2d, USER: %2d, Timestamp: %s, Title: %s, URL: %s, Category: %s",
                    rowLink.linkId,
                    userId,
                    SysTime(unixTimeToStdTime(rowLink.timestamp)),
                    rowLink.title,
                    rowLink.url,
                    rowLink.category);
            linksList.linksList ~= rowLink;
        }
        return linksList;
    }

    void writeDatabase(string[] urls) {

    }

    bool deleteLink(long userId, long linkId) {
        // TODO: Perform validation for user etc
        string query = format("DELETE FROM %s WHERE %s = %d;",
            TABLE_NAME,
            COLUMN_LINK_ID,
            linkId);

        debugfln("Query: %s", query);

        try {
            Statement statement = sqliteDb.prepare(query);
            statement.inject();
            return true;
        } catch (SqliteException e) {
            errorfln("ERROR WHEN DELETING LINK ", e.msg);
        }

        return false;
    }

    bool insertLink(long userId, Link link) {
        debugfln("Inserting: %s", link);
        // Inserts will always ignore the link ID
        string insert = format("INSERT INTO %s (%s, %s, %s, %s)",
                               TABLE_NAME,
                               COLUMN_USER_ID,
                               COLUMN_URL,
                               COLUMN_TITLE,
                               COLUMN_CATEGORY);
        string values = format("VALUES(:%s, :%s, :%s, :%s);",
                               COLUMN_USER_ID,
                               COLUMN_URL,
                               COLUMN_TITLE,
                               COLUMN_CATEGORY);

        try {
            Statement statement = sqliteDb.prepare(insert ~ values);
            statement.inject(userId, link.url, link.title, link.category);
            return true;
        } catch (SqliteException e) {
            errorfln("ERROR WHEN INSERTING LINK ", e.msg);
        }

        return false;
    }

    /// Gets a Link from a database row result
    private Link getRow(Row row) {
        Link link;
        link.linkId = row.peek!long(0);
        link.category = row[COLUMN_CATEGORY].as!string;
        link.timestamp = row[COLUMN_TIMESTAMP].as!int;
        link.title = row[COLUMN_TITLE].as!string;
        link.url = row[COLUMN_URL].as!string;
        link.isArchived = (row[COLUMN_IS_ARCHIVED].as!long != 0);
        link.isFavorite = (row[COLUMN_IS_FAVORITE].as!long != 0);
        return link;
    }
}
