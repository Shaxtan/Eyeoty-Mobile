/// Shared loading-state enum used by every data provider, so screens can
/// react consistently (idle / loading / loaded / error) regardless of
/// which provider they're watching.
enum LoadStatus { idle, loading, loaded, error }
