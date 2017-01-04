module linkservice.models_server;

/// Default title for the website
const string CONFIG_DEFAULT_TITLE = "Linky";
/// Default bind address
const string CONFIG_DEFAULT_ADDRESS = "0.0.0.0";
/// Default port to listen on
const ushort CONFIG_DEFAULT_PORT = 8000;
/// Default path for the sqlite database file
const string CONFIG_DEFAULT_DB_PATH = "private/database.db";
/// Install mode allows the admin to configure the site after first install
const bool CONFIG_INSTALL_MODE = false;

/// The server configuration options
struct LinkyConfig {
    /// .
    bool installMode = CONFIG_INSTALL_MODE;
    /// .
    string databasePath = CONFIG_DEFAULT_DB_PATH;
    /// .
    string siteTitle = CONFIG_DEFAULT_TITLE;
    /// .
    string address = CONFIG_DEFAULT_ADDRESS;
    /// .
    ushort port = CONFIG_DEFAULT_PORT;
    //bool allow_registrations = false;
}

/// .
struct User {
    /// .
    ulong  userId;
    /// .
    string authKey;
    /// .
    int  createdTimestamp;
    /// .
    int lastUpdateTimestamp;
    /// .
    string passwordHash;
    /// .
    string username;
}
