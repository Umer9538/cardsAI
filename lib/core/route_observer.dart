import 'package:flutter/widgets.dart';

/// Lets a screen know when another route covers it, and when it is uncovered.
///
/// The scan flow needs this and it is not a nicety. The result screen is
/// *pushed on top of* the scanning screen rather than replacing it, so the
/// scanner stays mounted underneath — and it stops itself the moment it reads a
/// code, because a reader that keeps firing turns one product into a dozen
/// lookups. Coming back from the result therefore returned to a live widget
/// holding a stopped camera: a black viewfinder that nothing would ever
/// restart.
///
/// A single observer, registered on the app's navigator. Anything that owns a
/// camera and lives under a pushed route wants it.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
