import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controllers/editor_controller.dart';
import 'services/content_policy.dart';
import 'services/editor_interaction.dart';
import 'services/link_service.dart';
import 'services/settings_service.dart';
import 'services/window_service.dart';
import 'widgets/editor_screen.dart';

class MarkdownEditorApp extends StatelessWidget {
  const MarkdownEditorApp({
    super.key,
    required this.editor,
    required this.settings,
    required this.window,
    required this.policy,
    required this.links,
    this.interaction,
  });
  final EditorController editor;
  final SettingsController settings;
  final EditorWindowService window;
  final ContentPolicy policy;
  final LinkService links;
  final EditorInteraction? interaction;

  ThemeData _theme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff42645b),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Malgun Gothic',
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: colorScheme.surface,
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 450),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      title: '로컬 Markdown 에디터',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: settings.value.theme,
      home: EditorScreen(
        editor: editor,
        settings: settings,
        window: window,
        policy: policy,
        links: links,
        interaction: interaction,
      ),
    ),
  );
}
