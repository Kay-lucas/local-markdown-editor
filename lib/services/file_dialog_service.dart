import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor_interaction.dart';

class EditorDialogs implements EditorInteraction {
  EditorDialogs(this.context);
  final BuildContext Function() context;
  bool modal = false;
  static const group = XTypeGroup(
    label: 'Markdown',
    extensions: ['md', 'markdown'],
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    modal = true;
    try {
      return await action();
    } finally {
      modal = false;
    }
  }

  @override
  Future<String?> chooseOpen() => _guard(
    () async => (await openFile(
      acceptedTypeGroups: [group],
      confirmButtonText: '열기',
    ))?.path,
  );
  @override
  Future<String?> chooseSave(String suggestedName) => _guard(
    () async => (await getSaveLocation(
      acceptedTypeGroups: [group],
      suggestedName: suggestedName,
      confirmButtonText: '저장',
    ))?.path,
  );

  Future<T?> _dialog<T>(Widget child) => _guard(
    () => showDialog<T>(
      context: context(),
      barrierDismissible: false,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.pop(ctx),
        },
        child: child,
      ),
    ),
  );

  @override
  Future<UnsavedChoice> askUnsaved() async =>
      await _dialog<UnsavedChoice>(
        Builder(
          builder: (ctx) => AlertDialog(
            title: const Text('저장하지 않은 변경 사항이 있습니다'),
            content: const Text('변경 사항을 저장하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, UnsavedChoice.discard),
                child: const Text('버리기'),
              ),
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(ctx, UnsavedChoice.cancel),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, UnsavedChoice.save),
                child: const Text('저장'),
              ),
            ],
          ),
        ),
      ) ??
      UnsavedChoice.cancel;

  @override
  Future<ConflictChoice> askConflict({required bool missing}) async =>
      await _dialog<ConflictChoice>(
        Builder(
          builder: (ctx) => AlertDialog(
            title: Text(missing ? '파일이 삭제되거나 이동되었습니다' : '파일이 외부에서 변경되었습니다'),
            content: const Text(
              '현재 편집 내용을 어떻게 저장할지 선택해 주세요. 취소하면 편집 내용과 디스크의 파일을 그대로 유지합니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, ConflictChoice.saveAs),
                child: const Text('다른 이름으로 저장'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, ConflictChoice.overwrite),
                child: Text(missing ? '다시 만들기' : '현재 내용으로 덮어쓰기'),
              ),
              FilledButton(
                autofocus: true,
                onPressed: () => Navigator.pop(ctx, ConflictChoice.cancel),
                child: const Text('취소'),
              ),
            ],
          ),
        ),
      ) ??
      ConflictChoice.cancel;

  @override
  Future<bool> confirmOverwrite(String path) async =>
      await _dialog<bool>(
        Builder(
          builder: (ctx) => AlertDialog(
            title: const Text('기존 파일을 덮어쓸까요?'),
            content: Text(path),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('덮어쓰기'),
              ),
            ],
          ),
        ),
      ) ??
      false;

  @override
  Future<void> showError(String message) async {
    await _dialog<void>(
      Builder(
        builder: (ctx) => AlertDialog(
          title: const Text('작업을 완료하지 못했습니다'),
          content: SingleChildScrollView(child: SelectableText(message)),
          actions: [
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void notify(String message) {
    final ctx = context();
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
