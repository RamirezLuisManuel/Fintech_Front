/// Stub para plataformas móviles/desktop (el cierre se maneja con WidgetsBindingObserver)
void registerWebUnloadLogout({
  required String Function() getLogoutUrl,
  required String? Function() getAccessToken,
  required String? Function() getCorreo,
}) {}

void unregisterWebUnloadLogout() {}
