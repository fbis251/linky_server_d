module linkservice.models_auth;

/// A basic auth request sent via the rest API
struct BasicAuthUser {
    long userId;  /// The ID of the user making the request
    string token; /// The authentication token of the user
    string mac;   /// The authentication HMAC of the user
}
