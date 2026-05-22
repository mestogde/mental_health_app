bool requiresExtendedAccess(String? accessLevel) {
  return (accessLevel ?? 'guest').trim().toLowerCase() != 'guest';
}
