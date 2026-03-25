#include <cstdlib>
#include <string>

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Troodi VPN", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // If Dart did not shut down the bundled processes, avoid leaving them running.
  char sysdir[MAX_PATH];
  if (GetSystemDirectoryA(sysdir, MAX_PATH) > 0) {
    std::string tk = std::string(sysdir) + "\\taskkill.exe";
    std::string a = "\"" + tk + "\" /F /IM core-manager.exe /T >nul 2>&1";
    std::string b = "\"" + tk + "\" /F /IM xray.exe /T >nul 2>&1";
    std::system(a.c_str());
    std::system(b.c_str());
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
