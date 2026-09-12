enum LinkAction { portal, external, blocked }

/// Keep credentials and sessions inside the configured HTTPS portal origin.
class NavigationPolicy {
  NavigationPolicy(this.origin) {
    if (origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw ArgumentError('PORTAL_ORIGIN must be an HTTPS origin');
    }
  }

  final Uri origin;

  bool sameOrigin(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == origin.host &&
      uri.port == origin.port &&
      uri.userInfo.isEmpty;

  LinkAction classify(Uri uri) {
    if (uri.userInfo.isNotEmpty) return LinkAction.blocked;
    if (sameOrigin(uri)) {
      // Existing document-signing links carry their own server-issued token.
      // Continue this established UAE PASS flow in the system browser.
      if (RegExp(
        r'^/sign/[A-Za-z0-9_-]{16,200}(/start)?$',
      ).hasMatch(uri.path)) {
        return LinkAction.external;
      }
      return uri.path == '/customer' || uri.path.startsWith('/customer/')
          ? LinkAction.portal
          : LinkAction.blocked;
    }
    if (uri.scheme == 'https' && uri.host.isNotEmpty ||
        uri.scheme == 'tel' ||
        uri.scheme == 'mailto') {
      return LinkAction.external;
    }
    return LinkAction.blocked;
  }

  // Only read-only destinations are accepted from OS links or push payloads.
  // Invite/reset links are deliberately handled by the existing website.
  Uri? appDestination(Uri uri) {
    if (!sameOrigin(uri) || uri.hasQuery || uri.hasFragment) return null;
    if (const {
          '/customer',
          '/customer/dashboard',
          '/customer/messages',
          '/customer/appointments',
          '/customer/archive',
          '/customer/account',
        }.contains(uri.path) ||
        RegExp(r'^/customer/orders/[1-9][0-9]*$').hasMatch(uri.path)) {
      return uri;
    }
    return null;
  }
}
