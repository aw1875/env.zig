pub const env = @import("env").Env(struct {
    GITHUB_CLIENT_ID: []const u8,
    GITHUB_CLIENT_SECRET: []const u8,
    GITHUB_CALLBACK_URL: []const u8,
    PUBLIC_MESSAGE: []const u8,
    SPECIAL_MESSAGE: []const u8,
    PORT: u16,
});
