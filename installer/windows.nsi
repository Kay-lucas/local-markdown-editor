Unicode true
ManifestDPIAware true
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetCompressorDictSize 32

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"

!ifndef PAYLOAD_DIR
  !error "PAYLOAD_DIR is required"
!endif
!ifndef OUTPUT_FILE
  !error "OUTPUT_FILE is required"
!endif
!ifndef APP_VERSION
  !define APP_VERSION "1.0.0"
!endif
!define APP_NAME "로컬 Markdown 에디터"
!define APP_ID "KayLucas.LocalMarkdownEditor"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}"
!define START_MENU_FOLDER "로컬 Markdown 에디터"

Name "${APP_NAME}"
OutFile "${OUTPUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\LocalMarkdownEditor"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
BrandingText "${APP_NAME} ${APP_VERSION}"
ShowInstDetails nevershow
ShowUninstDetails nevershow
VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey /LANG=1042 "ProductName" "${APP_NAME} 설치"
VIAddVersionKey /LANG=1042 "FileDescription" "${APP_NAME} 설치 프로그램"
VIAddVersionKey /LANG=1042 "CompanyName" "Kay-lucas"
VIAddVersionKey /LANG=1042 "FileVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1042 "ProductVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1042 "LegalCopyright" "Copyright (c) 2026 Kay-lucas"

!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "${APP_NAME} 설치"
!define MUI_WELCOMEPAGE_TEXT "내 컴퓨터의 Markdown 파일을 쉽게 편집하고 미리볼 수 있습니다.$\r$\n$\r$\n필요한 실행 파일을 함께 설치합니다. Flutter 설치나 회원 가입은 필요하지 않습니다.$\r$\n$\r$\n현재 사용자 계정에 설치됩니다. 계속하려면 다음을 눌러 주세요."
!define MUI_FINISHPAGE_RUN "$INSTDIR\local_markdown_editor.exe"
!define MUI_FINISHPAGE_RUN_TEXT "${APP_NAME} 실행"
!insertmacro MUI_PAGE_WELCOME
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE VerifyInstallDirectory
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "Korean"
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${IfNot} ${IsNativeAMD64}
    MessageBox MB_OK|MB_ICONSTOP "이 설치 파일은 Windows x64 PC용입니다." /SD IDOK
    Abort
  ${EndIf}
  SetRegView 64
  SetShellVarContext current
FunctionEnd

Function VerifyInstallDirectory
  ; Never place the app in a folder containing unrelated files.
  IfFileExists "$INSTDIR\*.*" 0 directory_ok
  ClearErrors
  FileOpen $0 "$INSTDIR\.install-owner" r
  IfErrors directory_rejected
  FileRead $0 $1
  FileClose $0
  StrCmp $1 "${APP_ID}" directory_ok
directory_rejected:
  MessageBox MB_OK|MB_ICONEXCLAMATION "비어 있는 새 폴더 또는 이 앱의 기존 설치 폴더를 선택해 주세요." /SD IDOK
  Abort
directory_ok:
FunctionEnd

Section "${APP_NAME}" MainSection
  Call VerifyInstallDirectory
  SetOutPath "$INSTDIR"
  SetOverwrite on
  File /r /x "*.md" /x "*.markdown" /x "예제" "${PAYLOAD_DIR}\*"
  ; Examples and Markdown guides may have become the user's edited documents.
  SetOverwrite off
  File "${PAYLOAD_DIR}\*.md"
  SetOutPath "$INSTDIR\예제"
  File /r "${PAYLOAD_DIR}\예제\*"
  SetOutPath "$INSTDIR"
  SetOverwrite on
  FileOpen $0 "$INSTDIR\.install-owner" w
  FileWrite $0 "${APP_ID}"
  FileClose $0
  WriteUninstaller "$INSTDIR\uninstall.exe"
  CreateDirectory "$SMPROGRAMS\${START_MENU_FOLDER}"
  CreateShortcut "$SMPROGRAMS\${START_MENU_FOLDER}\${APP_NAME}.lnk" "$INSTDIR\local_markdown_editor.exe"
  CreateShortcut "$SMPROGRAMS\${START_MENU_FOLDER}\예제 문서.lnk" "$INSTDIR\예제"
  CreateShortcut "$SMPROGRAMS\${START_MENU_FOLDER}\제거.lnk" "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "Kay-lucas"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\local_markdown_editor.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\uninstall.exe$\"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '$\"$INSTDIR\uninstall.exe$\" /S'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "https://github.com/Kay-lucas/local-markdown-editor"
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" $0
SectionEnd

Function un.onInit
  SetRegView 64
  SetShellVarContext current
  ClearErrors
  FileOpen $0 "$INSTDIR\.install-owner" r
  IfErrors owner_rejected
  FileRead $0 $1
  FileClose $0
  StrCmp $1 "${APP_ID}" owner_verified
owner_rejected:
  MessageBox MB_OK|MB_ICONSTOP "앱의 설치 폴더를 확인할 수 없어 제거를 중단했습니다." /SD IDOK
  Abort
owner_verified:
FunctionEnd

Section "Uninstall"
  ; The build generates an exact file list. Never recursively delete INSTDIR.
  !include "${UNINSTALL_INCLUDE}"
  Delete "$INSTDIR\.install-owner"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  ReadRegStr $0 HKCU "${UNINSTALL_KEY}" "InstallLocation"
  StrCmp $0 "$INSTDIR" 0 registry_done
  Delete "$SMPROGRAMS\${START_MENU_FOLDER}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${START_MENU_FOLDER}\예제 문서.lnk"
  Delete "$SMPROGRAMS\${START_MENU_FOLDER}\제거.lnk"
  RMDir "$SMPROGRAMS\${START_MENU_FOLDER}"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
registry_done:
SectionEnd
