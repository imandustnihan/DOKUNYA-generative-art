import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/studio_controller.dart';
import '../../core/graphics/art_painter.dart';

class ArtCanvas extends StatefulWidget {
  const ArtCanvas({super.key, required this.controller});
  final StudioController controller;
  @override
  State<ArtCanvas> createState() => _ArtCanvasState();
}

class _ArtCanvasState extends State<ArtCanvas> {
  final _pointers = <int, Offset>{};
  double _startDistance = 1, _startZoom = 1;
  Offset _anchor = Offset.zero, _lastPan = Offset.zero;
  bool _pinching = false, _panning = false;
  StudioController get c => widget.controller;
  double pressure(PointerEvent e) =>
      e.pressureMax > e.pressureMin && e.kind == PointerDeviceKind.stylus
      ? ((e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin)).clamp(
          .1,
          1,
        )
      : .6;
  (double, double) normalize(Offset p, Size size) {
    final q = (p - c.pan) / c.zoom;
    return ((q.dx / size.width).clamp(0, 1), (q.dy / size.height).clamp(0, 1));
  }

  @override
  void dispose() {
    c.engine.endAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      c.canvasSize = size;
      return Semantics(
        container: true,
        label: c.t('canvas'),
        image: true,
        child: RepaintBoundary(
          key: const ValueKey('art_boundary'),
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            child: Listener(
              key: const ValueKey('art_canvas'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) {
                _pointers[e.pointer] = e.localPosition;
                if (_pointers.length == 2) {
                  c.engine.endAll();
                  _pinching = true;
                  final p = _pointers.values.toList();
                  _startDistance = math.max(1, (p[0] - p[1]).distance);
                  _startZoom = c.zoom;
                  _anchor = ((p[0] + p[1]) / 2 - c.pan) / c.zoom;
                } else if (_pointers.length == 1) {
                  _panning = e.buttons == kMiddleMouseButton;
                  _lastPan = e.localPosition;
                  if (!_panning) {
                    final p = normalize(e.localPosition, size);
                    c.begin(e.pointer, p.$1, p.$2, pressure(e));
                  }
                }
              },
              onPointerMove: (e) {
                if (!_pointers.containsKey(e.pointer)) return;
                _pointers[e.pointer] = e.localPosition;
                if (_pinching && _pointers.length >= 2) {
                  final p = _pointers.values.take(2).toList();
                  final scale =
                      (_startZoom * (p[0] - p[1]).distance / _startDistance)
                          .clamp(.5, 4)
                          .toDouble();
                  c.setView(scale, (p[0] + p[1]) / 2 - _anchor * scale);
                } else if (_panning) {
                  c.setView(c.zoom, c.pan + e.localPosition - _lastPan);
                  _lastPan = e.localPosition;
                } else if (!_pinching) {
                  final p = normalize(e.localPosition, size);
                  c.move(e.pointer, p.$1, p.$2, pressure(e));
                }
              },
              onPointerUp: (e) {
                _pointers.remove(e.pointer);
                c.end(e.pointer);
                if (_pointers.isEmpty) {
                  _pinching = false;
                  _panning = false;
                }
              },
              onPointerCancel: (e) {
                _pointers.remove(e.pointer);
                c.end(e.pointer);
                if (_pointers.isEmpty) {
                  _pinching = false;
                  _panning = false;
                }
              },
              onPointerSignal: (e) {
                if (e is! PointerScrollEvent) return;
                GestureBinding.instance.pointerSignalResolver.register(e, (
                  event,
                ) {
                  final scroll = event as PointerScrollEvent;
                  if (HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isMetaPressed) {
                    final scale =
                        (c.zoom * math.exp(-scroll.scrollDelta.dy * .002))
                            .clamp(.5, 4)
                            .toDouble();
                    final anchor = (scroll.localPosition - c.pan) / c.zoom;
                    c.setView(scale, scroll.localPosition - anchor * scale);
                  } else {
                    c.setView(c.zoom, c.pan - scroll.scrollDelta);
                  }
                });
              },
              child: ClipRect(
                child: CustomPaint(
                  key: const ValueKey('art_paint'),
                  painter: ArtPainter(
                    c.engine,
                    repaint: c.clock,
                    shaderProvider: () => c.shader,
                    zoomProvider: () => c.zoom,
                    panProvider: () => c.pan,
                  ),
                  size: size,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
