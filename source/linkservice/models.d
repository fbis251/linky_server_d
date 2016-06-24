module linkservice.models;

/// Represents a List/Array containing all the links a user has stored
struct LinksList {
    Link[] linksList; /// An array containing all the user's Links
}

/// A response for an Add request, indicating the success or failure of the add request
struct AddLinkResponse {
    bool successful; /// Whether or not the last request was successful
    Link link; /// The Link that was just added, useful because it contains the unique linkId
}

/// A URL and its metadata such as title, timestamp, category, etc
struct Link {
    ulong linkId;
    string category;
    bool isArchived;
    bool isFavorite;
    ulong timestamp;
    string title;
    string url;
}

/// A request sent to /api/login
struct LoginRequest {
    string username; /// The username to use during login
    string password; /// The password to use during login
}

/// Sent to the client indicating the success of the login procedure, plus an authentication token
struct LoginResponse {
    bool successful;        /// Whether or not the login was successful
    string refreshToken; /// The token a client should use when requesting a user's data
    string username;     /// The username of the account that successfully authenticated
}

/// A generic response indicating success or failure of the previous request
struct SuccessResponse {
    bool successful; /// Whether or not the last request was successful
}

}
