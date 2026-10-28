# Third-party components

The original application code and installer scripts are licensed under the MIT License in the accompanying `LICENSE` file. That license does not replace the licenses for the third-party components below.

## Flutter, Dart and packages

Flutter, Dart, flutter_markdown_plus, markdown, file_selector, path_provider_windows, url_launcher, path, characters and ffi are distributed under their respective licenses, principally BSD-3-Clause. window_manager and screen_retriever are distributed under their respective MIT licenses. Additional transitive package notices are bundled with the application.

The complete notices collected by Flutter are in `data/flutter_assets/NOTICES.Z`. They can also be read inside the application through **도움말 → 오픈소스 라이선스**. Preserve that file and the notices when distributing the app.

## Microsoft Visual C++ runtime

The installer bundles unmodified x64 release runtime DLLs from the `VC/Redist/MSVC/14.51.36231/x64/Microsoft.VC145.CRT` directory of Visual Studio Build Tools 2026. These Microsoft components are governed by Microsoft's terms, not by this project's application license.

Distribution reference: https://learn.microsoft.com/en-us/visualstudio/releases/2026/redistribution

The runtime files are installed beside this application. The installer does not replace Windows system DLLs or install a system-wide runtime package. Runtime updates require a new application package.

## NSIS installer

The installer is built with unmodified NSIS 3.13. The installer engine and standard components are covered by the NSIS zlib/libpng license. Its LZMA component has a linking exception permitting use in installers without changing the license of the application.

NSIS source and license: https://nsis.sourceforge.io/Docs/AppendixI.html

NSIS compiler download SHA-256:

`ba63dffc4410ee89193e1cb5a41989991bd77c61068da17e3156d136b7b0b3d8`

Only the generated installer is distributed with this application; the compiler is not bundled.
