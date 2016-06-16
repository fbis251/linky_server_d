module linkservice.utils.crypto;

import std.algorithm, std.array, std.stdio, std.format;
import std.digest.sha;
import botan.passhash.bcrypt;
import botan.rng.rng;
import botan.rng.auto_rng;

///
const string PASSWORD_FILE = "private/password.txt";
/// BCrypt Iterations
const int WORK_FACTOR = 10;

///
bool checkBcryptPassword(const string password) {
    return checkBcrypt(password, readHashFile());
}

string generateHash(const string plaintext) {
    // bcrypt has no support for NUL characters and passwords > 72 characters
    // Generate a sha384 hash of the plaintext and pass that to bcrypt to mitigate this
    auto hash = cast(string) plaintext.sha384Of;
    Unique!AutoSeededRNG rng = new AutoSeededRNG;
    return generateBcrypt(hash, *rng, WORK_FACTOR);
}

///
string getRefreshToken() {
    // TODO: Improve this
    return format("%-(%02x%)", readHashFile().sha256Of);
}

///
string readHashFile() {
    string result = "";

    auto lines = File(PASSWORD_FILE)   // Open for reading
        .byLineCopy()      // Read persistent lines
        .array();           // into an array
    if(lines.length > 0) {
        result = lines[0];
    }

    return result;
}

///
void writeHashFile(string hash) {
    auto f = File(PASSWORD_FILE, "w"); // open for appending
    f.write(hash);
    f.close();
}
