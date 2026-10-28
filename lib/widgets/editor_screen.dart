import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../commands/formatting_commands.dart';
import '../controllers/editor_controller.dart';
import '../services/content_policy.dart';
import '../services/editor_interaction.dart';
import '../services/file_dialog_service.dart';
import '../services/link_service.dart';
import '../services/settings_service.dart';
import '../services/window_service.dart';
import 'markdown_preview.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
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
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _focus = FocusNode(debugLabel: 'Markdown editor');
  final _scroll = ScrollController();
  GlobalKey<EditableTextState> _editorKey = GlobalKey<EditableTextState>();
  late final EditorInteraction _ui;
  bool _modal = false;
  bool _exiting = false;
  int _document = 0;
  String _title = '';
  EditorController get editor => widget.editor;
  bool get _blocked => _modal || (_ui is EditorDialogs && (_ui).modal);

  @override
  void initState() {
    super.initState();
    _ui = widget.interaction ?? EditorDialogs(() => context);
    widget.window.setCloseHandler(_exit);
    editor.addListener(_changed);
    widget.settings.addListener(_settingsChanged);
    _changed();
  }

  void _changed() {
    if (_document != editor.documentId) {
      _document = editor.documentId;
      _editorKey = GlobalKey<EditableTextState>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (_scroll.hasClients) _scroll.jumpTo(0);
          _focus.requestFocus();
        }
      });
    }
    if (_title != editor.title) {
      _title = editor.title;
      unawaited(widget.window.setTitle(_title));
    }
  }

  void _settingsChanged() {
    final message = widget.settings.error;
    if (message != null) {
      widget.settings.clearError();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ui.notify(message);
      });
    }
  }

  Future<void> _exit() async {
    if (_exiting || _blocked || editor.busy) return;
    _exiting = true;
    try {
      await editor.confirmClose(
        _ui,
        onConfirmed: () async {
          await widget.settings.flush();
          await widget.window.destroy();
        },
      );
    } finally {
      _exiting = false;
    }
  }

  void _format(FormatCommand command) {
    if (_blocked || editor.transitionLocked) return;
    if (editor.composing) {
      _ui.notify('한글 조합을 마친 뒤 서식을 적용해 주세요.');
      return;
    }
    editor.applyEdit(FormattingCommands.apply(editor.text.value, command));
    _focus.requestFocus();
  }

  Future<void> _insertLink({bool image = false}) async {
    if (_blocked || editor.transitionLocked || editor.composing) return;
    final selection = FormattingCommands.selection(editor.text.value);
    final snapshot = editor.text.value;
    final label = TextEditingController(
      text: selection.textInside(snapshot.text),
    );
    final address = TextEditingController();
    final form = GlobalKey<FormState>();
    _modal = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.pop(ctx, false),
        },
        child: AlertDialog(
          title: Text(image ? '이미지 삽입' : '링크 삽입'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: label,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: image ? '이미지 설명' : '링크 텍스트',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: address,
                    decoration: InputDecoration(
                      labelText: image ? '로컬 이미지 경로' : '웹 주소',
                      hintText: image
                          ? 'images/example.png'
                          : 'https://example.com',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '주소 또는 경로를 입력해 주세요.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    image
                        ? '상대 경로는 저장한 문서의 폴더를 기준으로 합니다. 원격 이미지는 표시하지 않습니다.'
                        : 'HTTP(S) 링크만 미리보기에서 열 수 있습니다.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('삽입'),
            ),
          ],
        ),
      ),
    );
    _modal = false;
    if (result == true && mounted) {
      editor.applyEdit(
        FormattingCommands.link(
          snapshot,
          label.text.isEmpty ? (image ? '이미지' : '링크') : label.text,
          address.text,
          image: image,
        ),
      );
    }
    // Wait until route animations have detached their text fields.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    label.dispose();
    address.dispose();
    if (mounted) _focus.requestFocus();
  }

  Future<void> _link(String href) async {
    final uri = widget.policy.externalLink(href);
    if (uri == null) {
      _ui.notify('HTTP(S) 웹 링크만 열 수 있습니다.');
      return;
    }
    try {
      if (!await widget.links.open(uri) && mounted) {
        _ui.notify('기본 브라우저를 열지 못했습니다.');
      }
    } catch (_) {
      if (mounted) _ui.notify('기본 브라우저를 열지 못했습니다.');
    }
  }

  void _editMenu(String command) {
    if (_blocked || editor.transitionLocked) return;
    final state = _editorKey.currentState;
    _focus.requestFocus();
    switch (command) {
      case 'undo':
        editor.undo();
      case 'redo':
        editor.redo();
      case 'cut':
        state?.cutSelection(SelectionChangedCause.toolbar);
      case 'copy':
        state?.copySelection(SelectionChangedCause.toolbar);
      case 'paste':
        state?.pasteText(SelectionChangedCause.toolbar);
      case 'select':
        state?.selectAll(SelectionChangedCause.toolbar);
    }
  }

  KeyEventResult _keyboard(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_blocked) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final control = keyboard.isControlPressed;
    final shift = keyboard.isShiftPressed;
    final key = event.logicalKey;
    if (control && !keyboard.isAltPressed) {
      if (key == LogicalKeyboardKey.keyN) {
        unawaited(editor.newDocument(_ui));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyO) {
        unawaited(editor.openDocument(_ui));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyS) {
        unawaited(editor.save(_ui, saveAs: shift));
        return KeyEventResult.handled;
      }
      if (_focus.hasFocus && !editor.transitionLocked) {
        if (key == LogicalKeyboardKey.keyZ) {
          shift ? editor.redo() : editor.undo();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyY) {
          editor.redo();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyB) {
          _format(FormatCommand.bold);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyI) {
          _format(FormatCommand.italic);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyK) {
          unawaited(_insertLink());
          return KeyEventResult.handled;
        }
      }
    }
    if (_focus.hasFocus &&
        !control &&
        !shift &&
        key == LogicalKeyboardKey.tab) {
      _format(FormatCommand.indent);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _help(String title, String body) async {
    _modal = true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.pop(ctx),
        },
        child: AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(child: SelectableText(body)),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
    _modal = false;
  }

  MenuItemButton _menu(String title, String hint, VoidCallback? action) =>
      MenuItemButton(
        onPressed: action,
        trailingIcon: hint.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ),
        child: Text(title),
      );

  Widget _menus() {
    final idle = !editor.busy;
    final editable = !editor.transitionLocked;
    return MenuBar(
      style: const MenuStyle(
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      ),
      children: [
        SubmenuButton(
          menuChildren: [
            _menu(
              '새 문서',
              'Ctrl+N',
              idle ? () => editor.newDocument(_ui) : null,
            ),
            _menu(
              '열기…',
              'Ctrl+O',
              idle ? () => editor.openDocument(_ui) : null,
            ),
            _menu('저장', 'Ctrl+S', idle ? () => editor.save(_ui) : null),
            _menu(
              '다른 이름으로 저장…',
              'Ctrl+Shift+S',
              idle ? () => editor.save(_ui, saveAs: true) : null,
            ),
            const Divider(),
            _menu('종료', 'Alt+F4', idle ? _exit : null),
          ],
          child: const Text('파일'),
        ),
        SubmenuButton(
          menuChildren: [
            _menu(
              '실행 취소',
              'Ctrl+Z',
              editor.canUndo && editable ? () => _editMenu('undo') : null,
            ),
            _menu(
              '다시 실행',
              'Ctrl+Y',
              editor.canRedo && editable ? () => _editMenu('redo') : null,
            ),
            const Divider(),
            _menu('잘라내기', 'Ctrl+X', editable ? () => _editMenu('cut') : null),
            _menu('복사', 'Ctrl+C', () => _editMenu('copy')),
            _menu('붙여넣기', 'Ctrl+V', editable ? () => _editMenu('paste') : null),
            _menu('전체 선택', 'Ctrl+A', () => _editMenu('select')),
          ],
          child: const Text('편집'),
        ),
        SubmenuButton(
          menuChildren: [
            for (final mode in ThemeMode.values)
              _menu(
                '${widget.settings.value.theme == mode ? '✓ ' : ''}${_themeName(mode)}',
                '',
                () => widget.settings.setTheme(mode),
              ),
          ],
          child: const Text('보기'),
        ),
        SubmenuButton(
          menuChildren: [
            _menu(
              'Markdown 빠른 도움말',
              '',
              () => _help(
                'Markdown 빠른 도움말',
                '# 제목\n## 작은 제목\n\n**굵게**  *기울임*  ~~취소선~~\n\n- 글머리 목록\n1. 번호 목록\n- [ ] 할 일\n- [x] 완료\n\n> 인용문\n\n`인라인 코드`\n\n```dart\nprint("안녕하세요");\n```\n\n[링크](https://example.com)\n![이미지](images/example.png)\n\n| 제목 | 내용 |\n| --- | --- |\n| 항목 | 설명 |\n\n상대 이미지는 저장된 문서 폴더 기준입니다. 다른 폴더에 저장하면 기준 폴더가 바뀌며 이미지는 자동 복사되지 않습니다.\n원격 이미지와 원시 HTML은 렌더링하지 않습니다. 문서 자동 저장·비정상 종료 복구는 제공하지 않습니다.',
              ),
            ),
            _menu(
              '단축키 안내',
              '',
              () => _help(
                '단축키 안내',
                'Ctrl+N  새 문서\nCtrl+O  열기\nCtrl+S  저장\nCtrl+Shift+S  다른 이름으로 저장\n\nCtrl+B  굵게\nCtrl+I  기울임\nCtrl+K  링크\nCtrl+Z  실행 취소\nCtrl+Y / Ctrl+Shift+Z  다시 실행\nCtrl+X / C / V / A  잘라내기 / 복사 / 붙여넣기 / 전체 선택\nTab  본문에 스페이스 2칸\nAlt+F4  종료\nEsc  대화상자 취소',
              ),
            ),
            _menu(
              '앱 정보',
              '',
              () => _help(
                '로컬 Markdown 에디터',
                '버전 1.0.0\n\n내 컴퓨터에서 작성하고 저장하는 Markdown 편집기입니다.\n로그인·서버·DB 없이 동작합니다.\n\nFlutter 기반 Windows 데스크톱 앱\n\n사용한 오픈소스 라이선스는 아래에서 확인할 수 있습니다.',
              ),
            ),
            _menu('오픈소스 라이선스', '', () {
              showLicensePage(
                context: context,
                applicationName: '로컬 Markdown 에디터',
                applicationVersion: '1.0.0',
              );
            }),
          ],
          child: const Text('도움말'),
        ),
      ],
    );
  }

  String _themeName(ThemeMode mode) => switch (mode) {
    ThemeMode.system => '시스템',
    ThemeMode.light => '라이트',
    ThemeMode.dark => '다크',
  };

  Widget _tool(String label, IconData icon, VoidCallback? action) => IconButton(
    tooltip: label,
    onPressed: action,
    icon: Icon(icon, size: 20),
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    style: IconButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );

  Widget _toolbar() {
    final enabled = !editor.transitionLocked && !editor.composing;
    VoidCallback? format(FormatCommand command) =>
        enabled ? () => _format(command) : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Wrap(
        spacing: 3,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _tool(
            '새 문서 (Ctrl+N)',
            Icons.note_add_outlined,
            editor.busy ? null : () => editor.newDocument(_ui),
          ),
          _tool(
            '열기 (Ctrl+O)',
            Icons.folder_open_outlined,
            editor.busy ? null : () => editor.openDocument(_ui),
          ),
          _tool(
            '저장 (Ctrl+S)',
            Icons.save_outlined,
            editor.busy ? null : () => editor.save(_ui),
          ),
          const SizedBox(width: 10),
          _tool(
            '실행 취소 (Ctrl+Z)',
            Icons.undo,
            enabled && editor.canUndo ? editor.undo : null,
          ),
          _tool(
            '다시 실행 (Ctrl+Y)',
            Icons.redo,
            enabled && editor.canRedo ? editor.redo : null,
          ),
          const SizedBox(width: 10),
          PopupMenuButton<int>(
            tooltip: '제목 수준',
            enabled: enabled,
            onSelected: (level) => _format(FormatCommand.values[level - 1]),
            itemBuilder: (_) => [
              for (var i = 1; i <= 3; i++)
                PopupMenuItem(value: i, child: Text('제목 $i')),
            ],
            icon: const Icon(Icons.title, size: 20),
          ),
          _tool('굵게 (Ctrl+B)', Icons.format_bold, format(FormatCommand.bold)),
          _tool(
            '기울임 (Ctrl+I)',
            Icons.format_italic,
            format(FormatCommand.italic),
          ),
          _tool(
            '취소선',
            Icons.format_strikethrough,
            format(FormatCommand.strike),
          ),
          _tool('인라인 코드', Icons.code, format(FormatCommand.inlineCode)),
          _tool(
            '코드 블록',
            Icons.integration_instructions_outlined,
            format(FormatCommand.codeBlock),
          ),
          _tool(
            '링크 (Ctrl+K)',
            Icons.link,
            enabled ? () => _insertLink() : null,
          ),
          _tool(
            '이미지',
            Icons.image_outlined,
            enabled ? () => _insertLink(image: true) : null,
          ),
          const SizedBox(width: 10),
          _tool(
            '글머리 목록',
            Icons.format_list_bulleted,
            format(FormatCommand.bullet),
          ),
          _tool(
            '번호 목록',
            Icons.format_list_numbered,
            format(FormatCommand.number),
          ),
          _tool('체크리스트', Icons.checklist, format(FormatCommand.task)),
          _tool('인용', Icons.format_quote, format(FormatCommand.quote)),
          _tool('구분선', Icons.horizontal_rule, format(FormatCommand.rule)),
          _tool('표', Icons.table_chart_outlined, format(FormatCommand.table)),
        ],
      ),
    );
  }

  Widget _paneTitle(String title, String subtitle) => Container(
    height: 43,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
    ),
    child: Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _body() => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth - 9;
      final min = width >= 500 ? 250.0 : width * .25;
      final left = (width * widget.settings.value.split).clamp(
        min,
        width - min,
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: left,
            child: Column(
              children: [
                _paneTitle('MARKDOWN', '원문 편집'),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 16, 20),
                    child: Stack(
                      children: [
                        if (editor.text.text.isEmpty)
                          IgnorePointer(
                            child: Text(
                              '여기에 Markdown을 작성하세요…',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                        Scrollbar(
                          controller: _scroll,
                          child: Actions(
                            actions: {
                              UndoTextIntent: CallbackAction<UndoTextIntent>(
                                onInvoke: (_) {
                                  editor.undo();
                                  return null;
                                },
                              ),
                              RedoTextIntent: CallbackAction<RedoTextIntent>(
                                onInvoke: (_) {
                                  editor.redo();
                                  return null;
                                },
                              ),
                            },
                            child: EditableText(
                              key: _editorKey,
                              controller: editor.text,
                              focusNode: _focus,
                              readOnly: editor.transitionLocked,
                              scrollController: _scroll,
                              autofocus: true,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.7,
                                fontFamily: 'Consolas',
                                fontFamilyFallback: const [
                                  'Malgun Gothic',
                                  'monospace',
                                ],
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              cursorColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              backgroundCursorColor: Colors.grey,
                              selectionColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .22),
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              contextMenuBuilder: (context, state) =>
                                  AdaptiveTextSelectionToolbar.buttonItems(
                                    anchors: state.contextMenuAnchors,
                                    buttonItems: state.contextMenuButtonItems,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              key: const ValueKey('split-divider'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) =>
                  widget.settings.setSplit((left + details.delta.dx) / width),
              onHorizontalDragEnd: (_) => widget.settings.persist(),
              child: Container(
                width: 9,
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Center(
                  child: Container(
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  _paneTitle('미리보기', '실시간 · GFM'),
                  Expanded(
                    child: MarkdownPreview(
                      editor: editor,
                      policy: widget.policy,
                      onLink: _link,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _status() {
    final (line, column) = editor.cursor;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: editor.path ?? '저장 위치를 아직 선택하지 않았습니다',
                child: Text(
                  editor.path ?? '새 문서 · 저장할 위치를 선택해 주세요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text('UTF-8${editor.format.bom ? ' BOM' : ''}'),
            const SizedBox(width: 16),
            Text(editor.format.newlineLabel),
            const SizedBox(width: 16),
            Text('줄 $line, 열 $column'),
            const SizedBox(width: 16),
            SizedBox(
              width: 92,
              child: Text(
                editor.dirty &&
                        editor.status != '저장 중' &&
                        editor.status != '저장 실패'
                    ? '수정됨'
                    : editor.status,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: _keyboard,
    child: ListenableBuilder(
      listenable: Listenable.merge([editor, widget.settings]),
      builder: (context, _) => Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 15, 20, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_note,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '로컬 Markdown 에디터',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      '${editor.filename}${editor.dirty ? ' *' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.computer_outlined,
                    size: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  const Text('내 컴퓨터에 저장', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 14),
                  PopupMenuButton<ThemeMode>(
                    tooltip: '테마 선택',
                    onSelected: widget.settings.setTheme,
                    itemBuilder: (_) => [
                      for (final mode in ThemeMode.values)
                        PopupMenuItem(
                          value: mode,
                          child: Text(
                            '${widget.settings.value.theme == mode ? '✓ ' : ''}${_themeName(mode)}',
                          ),
                        ),
                    ],
                    icon: const Icon(Icons.contrast, size: 20),
                  ),
                ],
              ),
            ),
            _menus(),
            _toolbar(),
            Expanded(child: _body()),
            _status(),
          ],
        ),
      ),
    ),
  );

  @override
  void dispose() {
    editor.removeListener(_changed);
    widget.settings.removeListener(_settingsChanged);
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
