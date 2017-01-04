import vibe.d;
import vibe.appmain;
import vibe.core.core;
import vibe.core.log;
import vibe.data.json;
import vibe.http.router;
import vibe.http.server;
import vibe.web.rest;
import std.stdio;

import d2sqlite3;
import dini;

import linkservice.utils.linksdb;
import linkservice.utils.usersdb;
import linkservice.common;
import linkservice.rest;
import linkservice.web;
import linkservice.models_server;

///
shared static this() {
    auto ini = Ini.Parse("server.conf");
    serverConfig = getIniConfig(ini);
    writefln("Site Title: %s", serverConfig.siteTitle);
    auto db = Database(serverConfig.databasePath);
    linksDb = new LinksDb(db);
    usersDb = new UsersDb(db);
    logInfo("Database initialized %s", serverConfig.databasePath);

    auto router = new URLRouter;
    router
        .registerWebInterface(new LinkServiceWeb())
        .registerRestInterface(new LinkServiceRestApi())
        .get("*", serveStaticFiles("public/"));

    auto routes = router.getAllRoutes();
    foreach(route; routes) {
        debugfln("%8s %s", route.method, route.pattern);
    }

    auto settings = new HTTPServerSettings();
    settings.sessionStore = new MemorySessionStore();
    settings.errorPageHandler = toDelegate(&errorPage);
    settings.port = serverConfig.port;
    settings.bindAddresses = [serverConfig.address];
    listenHTTP(settings, router);
}
