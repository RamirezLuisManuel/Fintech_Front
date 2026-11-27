import 'dart:convert';
import 'dart:js_interop';

@JS('window.addEventListener')
external void _addWindowListener(JSString type, JSFunction listener);

@JS('window.removeEventListener')
external void _removeWindowListener(JSString type, JSFunction listener);

@JS('fetch')
external JSPromise<JSAny?> _jsFetch(JSString url, JSObject init);

@JS('Object')
external JSObject _createJsObject();

@JS('Reflect.set')
external void _jsSet(JSObject target, JSString key, JSAny? value);

JSFunction? _unloadListener;

/// Registra un listener de cierre de pestaña/navegador en Web para revocar el JWT en el servidor
void registerWebUnloadLogout({
  required String Function() getLogoutUrl,
  required String? Function() getAccessToken,
  required String? Function() getCorreo,
}) {
  unregisterWebUnloadLogout();

  void handleUnload(JSAny? _) {
    final token = getAccessToken();
    if (token == null || token.isEmpty) return;

    final headers = _createJsObject();
    _jsSet(headers, 'Content-Type'.toJS, 'application/json'.toJS);
    _jsSet(headers, 'Authorization'.toJS, 'Bearer $token'.toJS);

    final init = _createJsObject();
    _jsSet(init, 'method'.toJS, 'POST'.toJS);
    _jsSet(init, 'headers'.toJS, headers);
    _jsSet(init, 'body'.toJS, jsonEncode({'correo': getCorreo() ?? ''}).toJS);
    _jsSet(init, 'keepalive'.toJS, true.toJS);

    try {
      _jsFetch(getLogoutUrl().toJS, init);
    } catch (_) {}
  }

  _unloadListener = handleUnload.toJS;
  _addWindowListener('pagehide'.toJS, _unloadListener!);
  _addWindowListener('beforeunload'.toJS, _unloadListener!);
}

void unregisterWebUnloadLogout() {
  if (_unloadListener != null) {
    _removeWindowListener('pagehide'.toJS, _unloadListener!);
    _removeWindowListener('beforeunload'.toJS, _unloadListener!);
    _unloadListener = null;
  }
}
