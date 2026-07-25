/// The HTTP client the X requests share.
///
/// Every plugin in this app (Substack, Deepmarks, Reddit, Karakeep) already
/// takes an injectable `http.Client` and reuses it. The X path — by far the
/// busiest — did not: it called the top-level `http.get`, which builds a client
/// per call and closes it again, so every single API request paid for a fresh
/// TCP and TLS handshake with no keep-alive. Sharing one client lets the
/// connection pool do its job, and makes the core client as mockable as the
/// plugins already are.
library;

import 'package:http/http.dart' as http;

http.Client? _shared;

/// The shared client, created on first use.
http.Client get xHttpClient => _shared ??= http.Client();

/// Replaces the shared client, for tests. Passing null restores the default on
/// the next access.
set xHttpClient(http.Client? client) => _shared = client;
