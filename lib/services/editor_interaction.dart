enum UnsavedChoice { save, discard, cancel }

enum ConflictChoice { saveAs, overwrite, cancel }

abstract class EditorInteraction {
  Future<String?> chooseOpen();
  Future<String?> chooseSave(String suggestedName);
  Future<UnsavedChoice> askUnsaved();
  Future<ConflictChoice> askConflict({required bool missing});
  Future<bool> confirmOverwrite(String path);
  Future<void> showError(String message);
  void notify(String message);
}
