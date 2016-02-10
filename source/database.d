module database;

import std.algorithm, std.array, std.stdio;

///
string databaseFile = "private/links.txt";

///
string[] readDatabase() {
    writeln("readDatabase() called");
    auto lines = File(databaseFile)
        .byLineCopy()
        .array();

    auto urls = lines.array;
    writefln("Read %d URLs from database", urls.length);
    return urls;
}

///
void writeDatabase(string[] urls) {
    auto f = File(databaseFile, "w"); // open for appending
    foreach(url; urls) {
        f.writeln(url);
    }
    f.close();
}
