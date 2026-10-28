import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

abstract class EditorWindowService {
  void setCloseHandler(Future<void> Function() handler);
  Future<void> setTitle(String title);
  Future<void> destroy();
  void dispose();
}

class NativeEditorWindowService
    with WindowListener
    implements EditorWindowService {
  Future<void> Function()? _onClose;
  Future<void> initialize() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
  }

  Future<void> show() async {
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(900, 600),
        center: true,
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  @override
  void setCloseHandler(Future<void> Function() handler) => _onClose = handler;
  @override
  void onWindowClose() {
    final handler = _onClose;
    if (handler != null) unawaited(handler());
  }

  @override
  Future<void> setTitle(String title) => windowManager.setTitle(title);
  @override
  Future<void> destroy() => windowManager.destroy();
  @override
  void dispose() => windowManager.removeListener(this);
}
