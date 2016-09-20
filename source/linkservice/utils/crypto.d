module linkservice.utils.crypto;

import std.algorithm, std.array, std.stdio, std.format, std.string, std.base64;
import std.digest.sha;
import sodium;
import linkservice.common;

// Return values used by the sodium/argon2i functions to signify success/failure
const int SODIUM_INIT_FAILURE = -1;
const int CRYPTO_PWHASH_SUCCESS = 0;
const int CRYPTO_PWHASH_VERIFY_SUCCESS = 0;
const int AUTH_VERIFY_SUCCESS = 0;

// Default hashing parameters for argon
const enum ARGON2I_OPSLIMIT = crypto_pwhash_OPSLIMIT_INTERACTIVE;
const enum ARGON2I_MEMLIMIT = crypto_pwhash_MEMLIMIT_INTERACTIVE;

// String constants for authentication string generation
const string AUTH_STRING_DELIMITER = ":";

// Default token, key and MAC byte lengths
const int AUTH_TOKEN_LENGTH = 32; // 32 bytes == 256 bits
const int AUTH_KEY_LENGTH   = crypto_auth_KEYBYTES;
const int AUTH_MAC_LENGTH   = crypto_auth_BYTES;

bool verifyPassword(const string password, const string hashedPassword) {
    debugfln("verifyPassword(%s, %s)", password, hashedPassword);
    import std.algorithm.mutation;
    if(hashedPassword.length > crypto_pwhash_STRBYTES) {
        // TODO: Throw exception, stored hash was somehow longer than what argon2i returns
    }
    char[crypto_pwhash_STRBYTES] hashedPasswordArray;
    // Zero fill the the array since crypto_pwhash_argon2i_str_verify expects null bytes for
    // unused array entries
    hashedPasswordArray[] = 0;
    for(int i = 0; i < crypto_pwhash_STRBYTES; i++) {
        if(i < hashedPassword.length) {
            hashedPasswordArray[i] = hashedPassword[i];
        }
    }
    return argon2iVerifyPassword(password, hashedPasswordArray);
}

string hashPassword(const string password) {
    auto hashedPassword = argon2iHashPassword(password);
    // Convert the null-terminated C-style string returned by the argon2i function into a D string
    return fromStringz(hashedPassword.ptr).idup;
}

bool argon2iVerifyPassword(const string password, const char[crypto_pwhash_STRBYTES] hashedPassword) {
    debugfln("argon2iVerifyPassword(%s, %s)", password, hashedPassword);
    synchronized { // sodium_init could be executed by multiple threads simultaneously
        if (sodium_init == SODIUM_INIT_FAILURE) {
            // TODO: Throw exception here
        }
    }
    return crypto_pwhash_argon2i_str_verify(hashedPassword, password.ptr, password.length) == CRYPTO_PWHASH_VERIFY_SUCCESS;
}

char[crypto_pwhash_STRBYTES] argon2iHashPassword(const string password) {
    synchronized { // sodium_init could be executed by multiple threads simultaneously
        if (sodium_init == SODIUM_INIT_FAILURE) {
            // TODO: Throw exception here
        }
    }
    char[crypto_pwhash_STRBYTES] hashedPassword;

    if (crypto_pwhash_argon2i_str(hashedPassword,
            password.ptr,
            password.length,
            ARGON2I_OPSLIMIT,
            ARGON2I_MEMLIMIT
        ) != CRYPTO_PWHASH_SUCCESS) {
        // TODO: Throw exception here, out of memory
    }
    return hashedPassword;
}

ubyte[AUTH_KEY_LENGTH] generateNewAuthKey() {
    ubyte[AUTH_KEY_LENGTH] randomBytes = generateRandomBytes(AUTH_KEY_LENGTH);
    return randomBytes;
}

ubyte[AUTH_TOKEN_LENGTH] generateNewAuthToken() {
    ubyte[AUTH_TOKEN_LENGTH] randomBytes = generateRandomBytes(AUTH_TOKEN_LENGTH);
    return randomBytes;
}

ubyte[] generateRandomBytes(int byteCount) {
    synchronized { // sodium_init could be executed by multiple threads simultaneously
        if (sodium_init == SODIUM_INIT_FAILURE) {
            // TODO: Throw exception
        }
    }
    ubyte[] randomBytes;
    randomBytes.length = byteCount;
    // Use Sodium to generate random bytes
    randombytes_buf(randomBytes.ptr, randomBytes.length);
    return randomBytes.dup; // always pass a copy of the random bytes using .dup
}

string generateAuthString(const ubyte[AUTH_KEY_LENGTH] key,
                          const ubyte[AUTH_TOKEN_LENGTH] token) {
    ubyte[AUTH_MAC_LENGTH] mac;
    crypto_auth(mac.ptr, token.ptr, token.length, key.ptr);
    return format("%s%s%s", Base64.encode(token), AUTH_STRING_DELIMITER, Base64.encode(mac));
}

bool verifyAuthToken(const ubyte[AUTH_KEY_LENGTH] key,
                     const ubyte[AUTH_TOKEN_LENGTH] token,
                     const ubyte[AUTH_MAC_LENGTH] mac) {
    return crypto_auth_verify(mac.ptr, token.ptr, token.length, key.ptr) == AUTH_VERIFY_SUCCESS;
}
