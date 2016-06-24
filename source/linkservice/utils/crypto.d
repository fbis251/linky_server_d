module linkservice.utils.crypto;

import std.algorithm, std.array, std.stdio, std.format;
import std.digest.sha;
import botan.passhash.bcrypt;
import botan.rng.rng;
import botan.rng.auto_rng;

/// BCrypt Iterations
const int WORK_FACTOR = 10;

///
bool checkBcryptPassword(const string password, const string storedHash) {
    return checkBcrypt(password, storedHash);
}

string generateHash(const string plaintext) {
    // bcrypt has no support for NUL characters and passwords > 72 characters
    // Generate a sha384 hash of the plaintext and pass that to bcrypt to mitigate this
    //auto hash = cast(string) plaintext.sha384Of;
    auto hash = getSha384HexString(plaintext);
    Unique!AutoSeededRNG rng = new AutoSeededRNG;
    return generateBcrypt(hash, *rng, WORK_FACTOR);
}

/// Generates 16 random bytes and returns the sha256 digest of them as a hex string
string generateRefreshToken() {
    Unique!AutoSeededRNG rng = new AutoSeededRNG;
    ubyte[16] randomBytes;
    rng.randomize(randomBytes.ptr, randomBytes.length);
    writeln(getSha256HexString(randomBytes));
    return getSha256HexString(randomBytes);
}

string getSha256HexString(ubyte[] array) {
    return toHexString(sha256Of(array).dup);
}

string getSha384HexString(string inputString) {
    return toHexString(sha384Of(inputString).dup);
}
