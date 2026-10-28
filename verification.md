# 구현 및 검증 결과

검증일: 2026-10-28 (한국 시간)

## 1. 현재 상태

첫 버전 기능의 소스 구현, Git 초기화, 자동 테스트, 코드 검사, Windows Debug 실행과 Release 빌드를 완료했다. Release 실행 파일도 별도로 실행해 실제 창과 초기 화면을 확인했다.

**실제 Windows에서 모든 수동 수용 기준을 통과한 상태는 아니다.** 창 표시 이후 컴퓨터 조작 도구의 입력 연결이 실패해 네이티브 파일 대화상자·실제 두벌식 IME·Alt+F4 저장 경고 등을 끝까지 조작하지 못했다. 아래에서 자동 검증과 실제 앱 조작을 구분한다.

## 2. 개발 환경과 명령 결과

| 항목 | 결과 |
| --- | --- |
| OS | Windows 11 Home 26H2, Build 26300, x64 |
| Flutter / Dart | stable 3.44.4 / 3.12.2 |
| Visual Studio / SDK | Build Tools 2026 18.6.0 / Windows SDK 10.0.26100.0 |
| Git | 2.55.0.windows.3 |
| doctor | Windows·Visual Studio·Windows 기기·네트워크 확인 정상. Android 도구 경고는 Windows 앱 범위 밖 |
| 패키지 준비 | `pub get` 최종 성공. 실제 의존성은 `pubspec.lock`에 고정 |
| 자동 테스트 | 전체 73개 통과, 실패 0개 |
| 코드 검사 | `dart analyze lib test tool`: No issues found |
| 코드 형식 | `dart format --output=none --set-exit-if-changed lib test tool`: 변경 없음 |
| Windows Debug | `run -d windows` 빌드·실행 성공, 실제 창 표시 확인 |
| Windows Release | `build windows --release` 성공, 배포 실행 파일 별도 실행·초기 화면 확인 |
| Git | 앱 루트에서 초기화. 이후 사용자의 GitHub 업로드 요청에 따라 소스 커밋·원격 연결·push 진행 |

설치된 Flutter의 배치 실행기가 빌드 단계를 정상적으로 이어가지 못해, SDK의 Dart와 Flutter tool snapshot을 직접 실행하는 `tool/flutter.ps1` 및 `tool/windows_backend.dart`를 사용했다. SDK 설치 파일과 Windows 설정은 수정하지 않았다.

플러그인 연결은 프로젝트 내부의 디렉터리 junction으로 준비했다. 긴 원본 경로에서는 C++ 헤더 탐색이 실패해 짧은 프로젝트 경로를 연결해 빌드했다. 배포본 exe는 소스 경로에 의존하지 않는다. 새로 빌드할 때는 소스를 짧은 경로에 풀어 사용하는 것이 권장된다.

실행한 검증 명령의 의미는 일반 Flutter 명령과 같으며, 이 환경에서는 다음 보조 경로를 사용했다.

```powershell
.\tool\flutter.ps1 doctor -v
.\tool\flutter.ps1 pub get
.\tool\flutter.ps1 test --no-pub
dart analyze lib test tool
dart format --output=none --set-exit-if-changed lib test tool
.\tool\flutter.ps1 run --no-pub -d windows
.\tool\flutter.ps1 build windows --release --no-pub
```

## 3. 자동 검증 범위

| 요구사항 ID | 결과 | 실제로 확인한 내용 |
| --- | --- | --- |
| UT-01 | 통과 | 새 문서·dirty 비교, 저장 기준, undo/redo, 저장 중 추가 편집, 문서 전환 |
| UT-02 | 통과 | 실제 Windows 임시 폴더에서 한글 경로, UTF-8 한글·영문·이모지·결합 문자, BOM, LF/CRLF, 공백·마지막 개행·빈 파일 왕복 |
| UT-03 | 통과 | 잘못된 UTF-8, 읽기·쓰기 실패, 교체 실패, 외부 변경·삭제, 원본·복구 임시 파일 보존 |
| UT-04 | 통과 | 인라인·여러 줄·행 경계 선택, 제목 수준 교체, 백틱 fence, 링크 이스케이프, 한글·이모지 경계 |
| UT-05 | 통과 | 저장/버리기/취소, 저장 위치 취소, 저장 실패, 추가 입력 시 종료 취소, 중복 요청, 종료 완료까지 입력 잠금 |
| UT-06 | 통과 | 상대 경로 기준, 새 문서, 로컬 절대·file URI, 원격·UNC·매핑 드라이브·미지원 형식 차단, HTTP(S) 링크 정책 |
| UT-07 | 통과 | JSON 설정 저장·복원, 손상·누락·잘못된 값의 기본값, 실패 후 재시도 |
| WT-01 | 통과 | 입력·미리보기, 컨트롤러 유지, 툴바 선택·포커스·단일 undo, Ctrl+B/Z |
| WT-02 | 통과 | 900×600 레이아웃, 다크 테마·분할 드래그, 실제 Flutter 경고창의 취소/버리기/Esc, 링크 창의 전역 단축키 차단 |
| GFM | 통과 | 표·정렬, 체크리스트, 취소선, 일반 URL 자동 링크, 원시 HTML 텍스트 표시 |
| 원격 요청 방지 | 통과 | 원격 이미지가 포함된 미리보기를 HTTP 클라이언트 생성 금지 상태에서 렌더링, 요청 시도 0회 |
| 실제 파일 잠금 | 통과 | Windows `CreateFileW`의 공유 금지 핸들로 원본을 잠근 뒤 저장 실패와 원본 보존 확인 |

자동 테스트는 `flutter test`의 Windows 테스트 엔진에서 실행했다. Flutter 위젯 테스트의 가상 키보드·가상 종료 콜백은 실제 OS 입력기나 실제 창 닫기 이벤트와 동일한 검증이 아니다.

## 4. Windows 수동 수용 기준 상태

| ID | 상태 | 확인한 것 / 남은 것 |
| --- | --- | --- |
| AC-01 | 일부 확인 | Debug·Release 실제 창과 빈 문서·분할 화면 표시 확인. 실제 타이핑과 갱신 조작은 미검증 |
| AC-02 | 자동 통과 / 수동 미검증 | 실제 파일 서비스의 한글·공백 경로 확인. Windows 열기 대화상자에서의 선택은 미검증 |
| AC-03 | 수동 미검증 | 조합 중 모델 보존과 조합 단위 undo는 자동 통과. 실제 두벌식 받침·한영 전환은 확인 필요 |
| AC-04 | 자동 통과 / 수동 미검증 | 툴바·선택·포커스·undo는 위젯 검증. 실제 마우스 조작은 확인 필요 |
| AC-05 | 자동 통과 / 수동 미검증 | GFM parser와 위젯 렌더링 통과. 실제 문서 열기 후 전체 화면 검토 필요 |
| AC-06 | 자동 통과 / 수동 미검증 | 실제 파일 IO와 컨트롤러 저장 통과. 앱에서 Ctrl+S로 저장 후 다시 열기는 확인 필요 |
| AC-07 | 자동 통과 / 수동 미검증 | 경로·확장자·덮어쓰기·현재 경로 전환 로직 통과. 실제 네이티브 저장 창 확인 필요 |
| AC-08 | 자동 통과 / 수동 미검증 | 취소·실패의 상태 보존 통과. 네이티브 대화상자 취소는 확인 필요 |
| AC-09 | 자동 통과 / 수동 미검증 | 경고창과 종료 콜백 분기 통과. 실제 X·Alt+F4·메뉴 종료는 확인 필요 |
| AC-10 | 자동 통과 / 수동 미검증 | 외부 수정·삭제 충돌 분기 통과. 다른 편집기와 함께 사용하는 실제 시나리오는 확인 필요 |
| AC-11 | 일부 확인 | 실제 공유 금지 Windows 핸들에서 실패와 보존 확인. 실제 읽기 전용 속성·UI 안내는 확인 필요 |
| AC-12 | 자동 통과 / 수동 미검증 | 이미지 경로 정책과 원격 요청 방지 통과. 앱에서 로컬 이미지 파일의 시각적 표시 확인 필요 |
| AC-13 | 일부 확인 | 원격 요청 차단 및 오프라인 구조 확인. OS 네트워크를 끊은 실제 실행은 미검증 |
| AC-14 | 자동 통과 / 수동 미검증 | 테마 UI와 JSON 저장·복원 통과. Release 재실행과 OS 테마 변경 동작은 확인 필요 |
| AC-15 | 일부 확인 | 실제 초기 창과 900×600 위젯 레이아웃 확인. 실제 OS 150% 배율은 미검증 |
| AC-16 | 일부 확인 | 아래 AOT 파일·파서 측정과 1MB 왕복 보존 확인. 실제 Release 전체 UI 입력 지연·시작 시간은 미측정 |

컴퓨터 조작 도구에서 관측한 오류는 `coordinate input geometry is unavailable`, `window is not a usable app window`이다. 창 선택·활성화·상태를 새로 조회한 뒤에도 입력을 안정적으로 전달하지 못했다. 이 오류를 앱의 파일 선택 기능이 실패했다는 증거로 해석하지 않았으며, 해당 기능을 수동 통과로 표시하지도 않았다.

## 5. 성능 측정

`tool/benchmark.dart`를 `dart compile exe`로 AOT 컴파일하고 Windows에서 실행했다. 문서는 한글·이모지·표·체크리스트가 반복되는 fixture다. 두 번 예열한 뒤 5회 측정 중앙값이다.

| 실제 문서 크기 | GFM 파싱 중앙값 | 읽기·인코딩·안전 저장 중앙값 | 원문 보존 |
| --- | ---: | ---: | --- |
| 102,416 bytes (약 100KB) | 111.523ms | 21.736ms | 확인 |
| 1,048,726 bytes (약 1MB) | 832.696ms | 102.597ms | 확인 |

이 값은 **Dart AOT의 파일 IO와 파서만** 측정한다. Flutter 위젯 배치·화면 갱신과 200ms 디바운스를 포함한 전체 입력 지연이 아니다. 따라서 요구사항의 `500ms 이내 미리보기` 및 `5초 이내 시작` 목표 달성을 선언하지 않는다. 측정은 Windows 빌드 작업과 같은 환경에서 진행해 부하의 영향을 받을 수 있다. RAM·디스크 사양을 별도로 확인하지 않았다.

전체 UI 성능이 목표에 미달하면 파싱 중복 제거와 큰 문서의 렌더링 범위 축소를 우선 검토한다. 정밀 스크롤 동기화 등의 P1 기능은 아직 추가하지 않는다.

## 6. 배포 구성과 다음 점검

배포본에는 exe, Flutter 엔진 DLL, 플러그인 DLL, `data` 폴더 전체를 포함한다. 예제 Markdown·이미지와 간단한 사용 안내를 함께 제공한다. 개발용 SDK·Git·Flutter가 없어도 배포 폴더의 실행 파일로 시작할 수 있는 구성이며, SDK가 설치되지 않은 별도 PC에서의 검증은 수행하지 않았다.

Microsoft Visual C++ x64 런타임은 현재 검증 PC에 설치되어 있다. 다른 PC에는 해당 런타임이 필요할 수 있으며, 이번 압축에 Microsoft 런타임 설치 프로그램을 재배포하지 않는다.

다음은 사용자 또는 후속 검증에서 우선 확인할 항목이다.

1. 예제 Markdown을 Windows 열기 창으로 선택하고 두벌식 한글·받침·한영 전환을 입력한다.
2. Ctrl+S·다른 이름 저장·저장 창 취소와 실제 읽기 전용 파일에서의 안내를 확인한다.
3. 수정 후 X·Alt+F4를 눌러 저장/버리기/취소를 확인한다.
4. 다크 모드 재실행, 실제 OS 150% 배율, 로컬 이미지와 네트워크를 끊은 상태를 확인한다.
5. Release 앱에서 시작 시간과 100KB 문서의 입력부터 프레임까지 걸린 시간을 측정한다.

그 외 범위와 정책은 [requirements.md](requirements.md), 실행·개발 방법은 [README.md](README.md)를 따른다.

## 7. GitHub 전달

사용자의 명시적 업로드 요청에 따라 비공개 저장소 [Kay-lucas/local-markdown-editor](https://github.com/Kay-lucas/local-markdown-editor)에 소스를 관리하고, 버전 `v1.0.0`의 Windows 실행 파일 ZIP과 소스 ZIP은 [Releases](https://github.com/Kay-lucas/local-markdown-editor/releases/tag/v1.0.0)에 제공한다. 업로드를 위해 앱 코드나 기존 검증 결과를 바꾸지는 않는다.
