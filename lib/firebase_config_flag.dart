// Not touched by `flutterfire configure` (that command only rewrites firebase_options.dart).
// Flip this to true once real values are filled in there and the app is ready for cloud sync.
const bool kFirebaseConfigured = true;

/// Runtime Firebase initialization status. This is separate from the generated configuration flag.
bool firebaseRuntimeReady = false;
String? firebaseRuntimeError;
