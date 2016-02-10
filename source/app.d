import vibe.d;
import vibe.appmain;
import vibe.core.core;
import vibe.core.log;
import vibe.data.json;
import vibe.http.router;
import vibe.http.server;
import vibe.web.rest;
import std.stdio;

import database, link_service_common, link_service_rest, link_service;

///
shared static this() {
    urls = readDatabase();
    auto router = new URLRouter;

    router
        .registerWebInterface(new LinkService())
        .registerRestInterface(new LinkServiceRestApi())
        .get("*", serveStaticFiles("public/"));

    auto routes = router.getAllRoutes();
    foreach(route; routes) {
        writefln("Method: %s", route.method);
        writefln("pattern: %s", route.pattern);
    }

    auto settings = new HTTPServerSettings();
    settings.sessionStore = new MemorySessionStore();
    settings.errorPageHandler = toDelegate(&errorPage);
    settings.port = 8251;
    settings.bindAddresses = ["::", "0.0.0.0"];
    listenHTTP(settings, router);
}
