import 'dart:js_interop';
import 'package:flutter/material.dart';

@JS('Reflect.set')
external void _jsSet(JSObject target, JSString key, JSAny? value);

@JS('Reflect.get')
external JSAny? _jsGet(JSObject target, JSString key);

/// Implementación Web usando etiqueta HTML `<img>` nativa vía HtmlElementView.
/// Esto permite que Chrome y Edge muestren los PNG públicos de GestoPago
/// sin ser bloqueados por CORS en CanvasKit, manteniendo el fallback automático
/// al monograma cuando el servicio responde 404.
Widget buildPlatformMonogramaImage({
  required String imageUrl,
  required String altText,
  required double size,
  required Widget fallback,
}) {
  return _WebNativeImg(
    key: ValueKey(imageUrl),
    imageUrl: imageUrl,
    altText: altText,
    size: size,
    fallback: fallback,
  );
}

class _WebNativeImg extends StatefulWidget {
  final String imageUrl;
  final String altText;
  final double size;
  final Widget fallback;

  const _WebNativeImg({
    super.key,
    required this.imageUrl,
    required this.altText,
    required this.size,
    required this.fallback,
  });

  @override
  State<_WebNativeImg> createState() => _WebNativeImgState();
}

class _WebNativeImgState extends State<_WebNativeImg> {
  bool _loaded = false;
  bool _failed = false;

  void _configureImgElement(Object element) {
    final jsEl = element as JSObject;
    final style = _jsGet(jsEl, 'style'.toJS) as JSObject?;

    if (style != null) {
      _jsSet(style, 'width'.toJS, '100%'.toJS);
      _jsSet(style, 'height'.toJS, '100%'.toJS);
      _jsSet(style, 'objectFit'.toJS, 'contain'.toJS);
      _jsSet(style, 'display'.toJS, 'block'.toJS);
      _jsSet(style, 'pointerEvents'.toJS, 'none'.toJS);
      _jsSet(style, 'userSelect'.toJS, 'none'.toJS);
      _jsSet(style, 'opacity'.toJS, '0'.toJS);
      _jsSet(style, 'transition'.toJS, 'opacity 150ms ease-in'.toJS);
    }

    _jsSet(jsEl, 'alt'.toJS, widget.altText.toJS);
    _jsSet(jsEl, 'draggable'.toJS, false.toJS);
    _jsSet(jsEl, 'referrerPolicy'.toJS, 'no-referrer'.toJS);

    _jsSet(
      jsEl,
      'onload'.toJS,
      ((JSAny? _) {
        if (style != null) {
          _jsSet(style, 'opacity'.toJS, '1'.toJS);
        }
        if (mounted && !_loaded) {
          setState(() => _loaded = true);
        }
      }).toJS,
    );

    _jsSet(
      jsEl,
      'onerror'.toJS,
      ((JSAny? _) {
        if (mounted && !_failed) {
          setState(() => _failed = true);
        }
      }).toJS,
    );

    // Asignar src después de registrar onload/onerror para capturar respuestas inmediatas de caché
    _jsSet(jsEl, 'src'.toJS, widget.imageUrl.toJS);

    final complete = _jsGet(jsEl, 'complete'.toJS);
    final naturalWidth = _jsGet(jsEl, 'naturalWidth'.toJS);
    if (complete.isA<JSBoolean>() &&
        (complete as JSBoolean).toDart &&
        naturalWidth.isA<JSNumber>() &&
        (naturalWidth as JSNumber).toDartInt > 0) {
      if (style != null) {
        _jsSet(style, 'opacity'.toJS, '1'.toJS);
      }
      if (mounted && !_loaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_loaded) setState(() => _loaded = true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.fallback;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_loaded) widget.fallback,
        IgnorePointer(
          child: Padding(
            padding: EdgeInsets.all(widget.size * 0.10),
            child: HtmlElementView.fromTagName(
              tagName: 'img',
              onElementCreated: _configureImgElement,
            ),
          ),
        ),
      ],
    );
  }
}
