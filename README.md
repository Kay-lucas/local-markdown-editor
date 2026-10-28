# 로컬 Markdown 에디터

내 컴퓨터의 Markdown 파일을 열어 왼쪽에서 편집하고 오른쪽에서 결과를 확인하는 Windows 데스크톱 앱입니다. 로그인·서버·DB 없이 동작합니다.

## 1. 배포본 실행

**일반 사용자에게는 [설치 파일 하나](https://github.com/Kay-lucas/local-markdown-editor/releases/download/v1.0.0/LocalMarkdownEditor-Setup-1.0.0-x64.exe)를 권장합니다.** 내려받아 실행하고 **다음 → 설치 → 마침**을 누른 뒤 시작 메뉴의 **로컬 Markdown 에디터**를 실행하세요. 압축 해제나 Flutter 설치는 필요하지 않습니다.

설치 파일은 Windows x64용이며, 현재 사용자 계정의 `%LOCALAPPDATA%/Programs/LocalMarkdownEditor`에 설치합니다. 필요한 Microsoft Visual C++ x64 런타임을 앱 폴더에 함께 넣으므로 추가 다운로드·관리자 권한을 요구하지 않습니다. 시작 메뉴 바로가기와 Windows의 앱 제거 항목을 제공합니다. 재설치·제거 때 Markdown·예제 문서는 보존합니다.

현재 배포자 코드 서명은 없습니다. Windows와 브라우저의 평판 확인에 따라 다운로드·실행 경고가 표시될 수 있습니다. 관련 동작은 [Microsoft 공식 안내](https://learn.microsoft.com/en-us/windows/security/operating-system-security/virus-and-threat-protection/microsoft-defender-smartscreen/)를 참고하세요. 실제 검증 내역과 남은 확인 사항은 [verification.md](verification.md)에 기록합니다.

### 압축 파일 방식

배포 폴더의 `local_markdown_editor.exe`를 더블클릭합니다. 압축 파일을 받았다면 먼저 전체를 풀어 주세요. exe와 같은 폴더의 DLL, `data` 폴더는 함께 있어야 합니다. exe만 따로 이동하면 실행되지 않을 수 있습니다.

기존 ZIP에는 Microsoft 런타임을 넣지 않아 다른 PC에서는 런타임이 별도로 필요할 수 있습니다. 처음 사용하는 사람에게는 위의 설치 파일을 전달하세요. 자동 업데이트는 포함하지 않습니다.

## 2. 사용 방법

1. **열기** 또는 `Ctrl+O`로 `.md`·`.markdown` 파일을 선택합니다.
2. 왼쪽에 글을 쓰면 약 200ms의 입력 대기 후 오른쪽 미리보기가 갱신됩니다.
3. 서식 버튼은 선택한 글에 Markdown 문법을 적용합니다. 선택이 없으면 예시 글을 넣습니다.
4. **저장** 또는 `Ctrl+S`로 같은 파일에 저장합니다. 처음 저장할 때는 위치를 선택합니다.
5. **다른 이름으로 저장** 또는 `Ctrl+Shift+S`는 새 파일을 저장하고 이후 그 파일을 편집합니다.
6. 파일명 옆 `*`와 아래의 **수정됨**은 아직 저장되지 않은 변경입니다.
7. 분할선을 드래그해 두 영역의 크기를 바꾸고, 오른쪽 위 테마 버튼이나 **보기** 메뉴에서 시스템·라이트·다크를 선택합니다.

예제는 `test/fixtures/sample.md`입니다. 예제 폴더의 `images/local.png`도 함께 유지하면 로컬 이미지 표시를 확인할 수 있습니다.

## 3. 단축키

| 키 | 동작 |
| --- | --- |
| Ctrl+N | 새 문서 |
| Ctrl+O | 파일 열기 |
| Ctrl+S | 같은 파일 저장 / 새 문서 저장 위치 선택 |
| Ctrl+Shift+S | 다른 이름으로 저장 |
| Ctrl+B / Ctrl+I | 굵게 / 기울임 |
| Ctrl+K | 링크 삽입 |
| Ctrl+Z | 실행 취소 |
| Ctrl+Y / Ctrl+Shift+Z | 다시 실행 |
| Ctrl+X / Ctrl+C / Ctrl+V / Ctrl+A | 잘라내기 / 복사 / 붙여넣기 / 전체 선택 |
| Tab | 본문에 스페이스 2칸 삽입 |
| Alt+F4 | 종료 및 미저장 확인 |
| Esc | 대화상자 취소 |

문서 서식과 실행 취소 단축키는 본문 입력 영역에서 동작합니다. 링크 입력 창 등의 입력 필드는 자체 선택·클립보드 동작을 유지합니다. 한글 조합 중에는 서식 삽입을 보류하므로 글자 조합을 마친 뒤 버튼을 눌러 주세요.

## 4. 문서와 저장 정책

- UTF-8과 UTF-8 BOM을 지원합니다. CP949 등 다른 인코딩을 자동 추측하지 않으며, 잘못된 UTF-8은 현재 문서를 유지한 채 오류로 안내합니다.
- 새 문서는 UTF-8 BOM 없음·LF로 저장합니다. 기존 파일의 BOM·LF/CRLF를 유지하고 마지막 개행·의미 있는 공백을 임의로 바꾸지 않습니다.
- 혼합 줄바꿈은 첫 줄바꿈을 기준으로 통일하며 열 때 안내합니다.
- 저장할 이름에 확장자가 없으면 `.md`를 붙입니다. `.md`·`.markdown` 이외의 확장자는 수정하도록 안내합니다.
- 새 문서·열기·정상 종료 전 변경이 있으면 **저장 / 버리기 / 취소**를 묻습니다. 저장 창 취소·쓰기 실패는 전환이나 종료도 취소합니다.
- 저장 중 입력한 내용은 계속 수정 상태로 남습니다. 문서를 전환하거나 닫는 과정에서는 본문 입력을 잠급니다.
- 같은 폴더의 임시 파일을 완전히 쓴 뒤 이름을 교체합니다. 교체에 실패하면 원본과 복구 가능한 임시 파일을 남깁니다. 오류에 표시된 임시 경로를 확인할 수 있습니다.
- 저장 직전 디스크의 바이트를 마지막 읽기/저장 기준과 비교합니다. 외부 변경·삭제가 있으면 명시적으로 선택하게 합니다. 자동 병합은 없습니다.
- 비교와 교체 사이의 다른 프로그램 동시 쓰기, 전원 차단·강제 종료, 네트워크 파일시스템까지 무손실을 보장하는 방식은 아닙니다. 자동 저장·비정상 종료 복구는 없습니다.
- 실행 취소는 최대 100단계이며, 큰 문서는 과거 원문 합계 약 8백만 UTF-16 단위 이내로 제한해 메모리 사용을 줄입니다. 문서를 바꾸면 실행 취소 기록을 비웁니다.

## 5. 미리보기와 오프라인 동작

제목 H1~H6, 문단, 목록·중첩 목록, 인용, 코드, 링크, 로컬 이미지, 구분선 및 GFM 표·체크리스트·취소선·URL 자동 링크를 지원합니다. 체크리스트는 미리보기에서 읽기 전용입니다.

- 상대 이미지는 현재 Markdown 파일의 폴더를 기준으로 찾습니다. 저장하지 않은 문서는 상대 이미지 대신 저장 안내를 표시합니다.
- 다른 폴더에 저장하면 상대 이미지의 기준도 바뀝니다. 이미지를 자동 복사하거나 원문의 경로를 변경하지 않습니다.
- 로컬 드라이브의 PNG·JPEG·GIF·WebP 및 호스트 없는 `file:` 이미지 URI를 지원합니다.
- 원격 이미지, UNC·매핑된 네트워크 드라이브는 지원하지 않습니다. 이미지가 없거나 손상되면 자리표시자로 안내합니다.
- HTTP(S) 텍스트 링크는 클릭한 경우에만 기본 브라우저에서 엽니다. 자동 페이지 요청이나 이미지 다운로드는 없습니다.
- 원시 HTML은 텍스트로 표시하며 실행하지 않습니다. 수식·Mermaid·SVG 렌더링은 포함하지 않습니다.
- 글 편집·저장·미리보기·설정에는 네트워크가 필요하지 않습니다. 개발 도구와 패키지를 처음 준비할 때의 다운로드는 별개입니다.
- 테마와 분할 비율만 앱 전용 사용자 지원 폴더의 `settings.json`에 저장합니다. 경로 조회에 실패하면 `%LOCALAPPDATA%/LocalMarkdownEditor`를 사용합니다. 본문·최근 파일·계정 데이터는 설정에 저장하지 않습니다.

## 6. 개발 환경

이번 구현에 사용한 환경입니다. Flutter를 임의로 업그레이드하지 않고 설치된 stable SDK로 검증했습니다.

| 도구 | 사용 버전 |
| --- | --- |
| Windows | Windows 11 Home 26H2, Build 26300, x64 |
| Flutter | stable 3.44.4 |
| Dart | 3.12.2 |
| Visual Studio | Build Tools 2026 18.6.0 |
| Windows SDK | 10.0.26100.0 |
| Git | 2.55.0.windows.3 |

Flutter SDK와 Visual Studio의 **C++를 사용한 데스크톱 개발** 도구가 필요합니다. VS Code만 설치한 경우 C++ 빌드 도구가 별도로 필요합니다. Android 관련 doctor 경고는 이 Windows 전용 앱에 영향을 주지 않습니다.

Windows C++ 도구의 경로 길이 제한을 피하려면 소스 압축을 `C:/dev/local_markdown_editor`처럼 짧은 경로에 푸는 것을 권장합니다. 생성된 `build` 폴더는 다른 경로로 재사용하지 말고 해당 위치에서 새로 빌드하세요.

### 일반 명령

앱 루트에서 실행합니다.

```powershell
flutter doctor -v
flutter devices
flutter pub get
dart format lib test tool
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```

### 설치된 Flutter 배치 실행기가 작동하지 않을 때

이 프로젝트에는 설치된 SDK 안의 Dart와 Flutter 도구를 직접 실행하는 보조 명령이 있습니다. SDK 파일과 Windows 설정을 바꾸지 않습니다. Flutter의 `bin`이 PATH에 등록되어 있어야 합니다.

```powershell
.\tool\flutter.ps1 doctor -v
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 analyze
.\tool\flutter.ps1 test
.\tool\flutter.ps1 run -d windows
.\tool\flutter.ps1 build windows --release
```

개발자 모드가 꺼져 플러그인 연결 오류가 나는 경우, 보조 `pub get` 명령은 프로젝트 안의 디렉터리 연결을 준비한 뒤 재시도합니다. 일반 명령을 사용 중이라면 아래 순서로 같은 준비를 할 수 있습니다.

```powershell
.\tool\prepare_windows_plugins.ps1
flutter pub get
```

`windows/flutter/CMakeLists.txt`의 빌드 단계는 `tool/windows_backend.dart`를 사용합니다. Flutter가 생성한 표준 환경 변수를 그대로 받아 SDK의 도구 snapshot을 직접 호출하므로 이 컴퓨터의 배치 실행기 문제를 우회합니다. 현재 앱의 일반 Debug·Release 빌드 범위를 지원하며, 커스텀 엔진·난독화·분리 디버그 심볼은 이 앱의 범위가 아닙니다.

빌드 결과 기본 위치는 `build/windows/x64/runner/Release`입니다. 전체 폴더를 함께 배포합니다.

### 설치 파일 제작

NSIS 3.13 공식 Windows ZIP을 내려받아 압축을 풉니다. 별도의 NSIS 설치는 필요하지 않습니다. 공식 배포 파일의 SHA-256은 `THIRD_PARTY_NOTICES.md`에 기록했습니다. VS Build Tools의 x64 **release** CRT 경로를 지정합니다.

```powershell
.\tool\build_installer.ps1 `
  -NsisCompiler C:\tools\nsis-3.13\makensis.exe `
  -PayloadDirectory C:\release\LocalMarkdownEditor-Windows-x64 `
  -OutputDirectory C:\release `
  -MsvcRuntimeDirectory 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Redist\MSVC\14.51.36231\x64\Microsoft.VC145.CRT'
```

`installer/windows.nsi`가 사용자별 설치와 제거를 정의하고, 제작 스크립트가 정확한 앱 파일 목록을 생성합니다. 제거할 때 설치 폴더 전체를 재귀 삭제하지 않습니다. Markdown·예제 문서는 제거 목록에서 제외하며, 기존 문서가 있는 관련 없는 폴더에는 설치하지 않습니다. 새 버전 설치 파일을 만들 때는 앱과 함께 제공하는 런타임도 갱신해야 합니다.

`tool/test_installer.ps1`은 기존 앱 설치가 없는 경우에만 새 검증 폴더에서 설치·재설치·제거·사용자 문서 보존을 검사합니다. 사용자 계정의 앱 설치 기록과 시작 메뉴를 잠시 만들었다가 검증 후 제거하므로, 실제 설치가 이미 있다면 실행하지 않습니다.

## 7. 구조와 검증

| 경로 | 역할 |
| --- | --- |
| `lib/models` | 인코딩·BOM·줄바꿈 |
| `lib/controllers` | 문서 상태, 편집 이력, 저장·전환 제어 |
| `lib/commands` | 선택 영역에 적용하는 순수 서식 변환 |
| `lib/services` | 파일 IO, 대화상자, 로컬 경로 정책, 설정, 창 제어, 링크 실행 |
| `lib/widgets` | 편집 화면과 지연 갱신 미리보기 |
| `test` | 단위·위젯 테스트, 예제 Markdown과 이미지 |
| `tool` | Windows 빌드 보조 명령과 AOT 성능 측정 |

단위·위젯 테스트와 실제 Windows 조작 결과를 [verification.md](verification.md)에 구분해 기록합니다. 도구나 자동 테스트만으로 실제 한글 IME·네이티브 대화상자를 검증했다고 표현하지 않습니다.

성능 보조 측정은 다음과 같습니다. Flutter 화면 전체의 입력 지연 측정과는 구분합니다.

```powershell
dart compile exe tool/benchmark.dart -o benchmark.exe
.\benchmark.exe
```

## 8. 의존성과 라이선스

실제 해석 버전은 `pubspec.lock`을 기준으로 합니다. 최신 버전이 있다는 이유만으로 자동 업그레이드하지 않습니다.

| 직접 의존성 | 버전 | 용도 |
| --- | --- | --- |
| flutter_markdown_plus | 1.0.12 | Flutter 위젯 미리보기 |
| markdown | 7.3.1 | GFM 파싱 |
| file_selector | 1.1.0 | 네이티브 파일 선택 |
| window_manager | 0.5.2 | 창 크기·제목·정상 종료 제어 |
| path_provider_windows | 2.3.0 | Windows 앱 전용 설정 경로 |
| url_launcher | 6.3.3 | 명시적으로 클릭한 웹 링크 열기 |
| path | 1.9.1 | 파일 경로 처리 |
| characters | 1.4.1 | 한글·이모지의 표시 문자 경계 |
| ffi | 2.2.0 | 매핑된 네트워크 드라이브 식별 |

앱의 **도움말 → 오픈소스 라이선스**에서 Flutter에 포함된 고지문을 확인할 수 있습니다. 배포할 때 `data/flutter_assets/NOTICES.Z` 등 빌드가 생성한 라이선스 파일도 함께 유지하세요.

공식 참고: [Flutter Windows 설정](https://docs.flutter.dev/platform-integration/windows/setup), [Flutter 테스트](https://docs.flutter.dev/cookbook/testing), [GFM 사양](https://github.github.com/gfm/), [Flutter Markdown Plus](https://pub.dev/packages/flutter_markdown_plus), [파일 선택](https://pub.dev/packages/file_selector), [창 제어](https://pub.dev/packages/window_manager).

## 9. Git과 다음 범위

GitHub 저장소: [Kay-lucas/local-markdown-editor](https://github.com/Kay-lucas/local-markdown-editor)

소스·테스트·문서·잠금 파일은 Git으로 관리하고 빌드·캐시·임시 파일은 제외합니다. Windows 실행 파일 ZIP과 소스 ZIP은 [Releases](https://github.com/Kay-lucas/local-markdown-editor/releases)에서 제공합니다. 저장소는 비공개로 시작하며, 접근 가능한 GitHub 계정으로 로그인해야 볼 수 있습니다.

다중 탭, 자동 저장, 최근 파일, 문법 색상 강조, 스크롤 동기화, 찾기·바꾸기, PDF·HTML 내보내기는 이번 버전 범위에 포함하지 않습니다. 설치 파일은 이후 배포 편의 요청으로 추가한 산출물입니다. 원래 요구사항의 설치 프로그램 제외 항목보다 이 후속 요청을 우선합니다.
