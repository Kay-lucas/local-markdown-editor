import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;

import '../controllers/visual_editor_controller.dart';
import '../services/content_policy.dart';
import '../services/visual_markdown_codec.dart';
import 'markdown_preview.dart';

class VisualEditor extends StatefulWidget {
  const VisualEditor({
    super.key,
    required this.bridge,
    required this.focusNode,
    required this.editorKey,
    required this.policy,
    required this.onLink,
    required this.onSource,
    required this.onKeyEvent,
  });
  final VisualEditorController bridge;
  final FocusNode focusNode;
  final GlobalKey<q.EditorState> editorKey;
  final ContentPolicy policy;
  final void Function(String) onLink;
  final VoidCallback onSource;
  final KeyEventResult Function(KeyEvent) onKeyEvent;

  @override
  State<VisualEditor> createState() => _VisualEditorState();
}

class _VisualEditorState extends State<VisualEditor> {
  final _scroll = ScrollController();
  q.QuillRawEditorState? _raw;

  void _compositionChanged() {
    final range = _raw?.composingRange.value;
    final active = range != null && range.isValid && !range.isCollapsed;
    if (active) {
      widget.bridge.source.setVisualComposing(true);
    } else {
      // Quill announces composition completion before applying the final
      // syllable. Keep it in the same undo transaction through this microtask.
      Future.microtask(() {
        if (!mounted) return;
        final current = _raw?.composingRange.value;
        if (current == null || !current.isValid || current.isCollapsed) {
          widget.bridge.source.setVisualComposing(false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = widget.editorKey.currentState;
      if (next is q.QuillRawEditorState && !identical(_raw, next)) {
        _raw?.composingRange.removeListener(_compositionChanged);
        _raw = next;
        _raw!.composingRange.addListener(_compositionChanged);
      }
    });
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Text(
            '클릭해서 바로 수정하세요 · 표·코드·이미지는 원문에서 편집',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: q.QuillEditor(
            controller: widget.bridge.quill,
            focusNode: widget.focusNode,
            scrollController: _scroll,
            config: q.QuillEditorConfig(
              editorKey: widget.editorKey,
              expands: true,
              padding: const EdgeInsets.fromLTRB(30, 20, 30, 40),
              placeholder: '여기에서도 문서를 작성할 수 있습니다…',
              onLaunchUrl: widget.onLink,
              // Quill is pinned; intercept the app's document shortcuts here.
              // ignore: experimental_member_use
              onKeyPressed: (event, _) {
                final result = widget.onKeyEvent(event);
                return result == KeyEventResult.ignored ? null : result;
              },
              // Explicit action routing prevents a second, divergent undo history.
              customShortcuts: const {
                SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                    UndoTextIntent(SelectionChangedCause.keyboard),
                SingleActivator(LogicalKeyboardKey.keyY, control: true):
                    RedoTextIntent(SelectionChangedCause.keyboard),
                SingleActivator(
                  LogicalKeyboardKey.keyZ,
                  control: true,
                  shift: true,
                ): RedoTextIntent(
                  SelectionChangedCause.keyboard,
                ),
              },
              customActions: {
                UndoTextIntent: CallbackAction<UndoTextIntent>(
                  onInvoke: (_) {
                    widget.bridge.source.undo();
                    return null;
                  },
                ),
                RedoTextIntent: CallbackAction<RedoTextIntent>(
                  onInvoke: (_) {
                    widget.bridge.source.redo();
                    return null;
                  },
                ),
              },
              embedBuilders: [
                _PreservedMarkdownBuilder(
                  policy: widget.policy,
                  path: widget.bridge.source.path,
                  onLink: widget.onLink,
                  onSource: widget.onSource,
                ),
              ],
              // Imported clipboard HTML is intentionally not enabled: .md remains
              // the document format, and external resources are never fetched.
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _raw?.composingRange.removeListener(_compositionChanged);
    // Mode changes commit IME grouping before detaching the visual input client.
    widget.bridge.source.setVisualComposing(false);
    _scroll.dispose();
    super.dispose();
  }
}

class _PreservedMarkdownBuilder extends q.EmbedBuilder {
  const _PreservedMarkdownBuilder({
    required this.policy,
    required this.path,
    required this.onLink,
    required this.onSource,
  });
  final ContentPolicy policy;
  final String? path;
  final void Function(String) onLink;
  final VoidCallback onSource;
  @override
  String get key => VisualMarkdownCodec.embedType;

  @override
  Widget build(BuildContext context, q.EmbedContext embedContext) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 13),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('원문 보존 블록', style: TextStyle(fontSize: 11)),
              ),
              TextButton(onPressed: onSource, child: const Text('왼쪽에서 수정')),
            ],
          ),
        ),
        MarkdownContent(
          data: embedContext.node.value.data as String,
          path: path,
          policy: policy,
          onLink: onLink,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
        ),
      ],
    ),
  );
}
