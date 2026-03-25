#include "my_application.h"

#include <cstdlib>

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new();
  const int code = g_application_run(G_APPLICATION(app), argc, argv);
  // If Dart did not shut down bundled processes, avoid leaving them running.
  std::system("pkill -TERM -x core-manager 2>/dev/null");
  std::system("pkill -TERM -x xray 2>/dev/null");
  return code;
}
