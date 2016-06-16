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
import linkservice.utils.linksdb;
import linkservice.common;
import linkservice.rest;
import linkservice.web;

///
shared static this() {
    auto db = Database("private/database.sqlite");
    linksDb = new LinksDb(db);

    auto router = new URLRouter;

    router
        .registerWebInterface(new LinkServiceWeb())
        .registerRestInterface(new LinkServiceRestApi())
        .get("*", serveStaticFiles("public/"));

    auto routes = router.getAllRoutes();
    foreach(route; routes) {
        debugfln("Method: %s", route.method);
        debugfln("pattern: %s", route.pattern);
    }

    auto settings = new HTTPServerSettings();
    settings.sessionStore = new MemorySessionStore();
    settings.errorPageHandler = toDelegate(&errorPage);
    settings.port = 8251;
    settings.bindAddresses = ["::", "0.0.0.0"];
    listenHTTP(settings, router);
}
