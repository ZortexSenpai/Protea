#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdint>
#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  // Quitting with the window still open (window_manager's destroy() posts
  // WM_QUIT) leaves the teardown to the destructors, and the member
  // destructor would delete the controller without clearing
  // flutter_controller_ first. Deleting it destroys the Flutter view's
  // window, which notifies this window (WM_PARENTNOTIFY), and MessageHandler
  // would hand that to the half-destroyed controller: an access violation
  // on every quit. Tear down the way closing the window does instead,
  // Flutter first (OnDestroy) and then the window.
  Destroy();
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Unread badge on the taskbar button, driven by lib/src/dock_badge.dart.
  taskbar_badge_.Attach(GetHandle());
  dock_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "protea/dock",
          &flutter::StandardMethodCodec::GetInstance());
  dock_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "setBadgeCount") {
          result->NotImplemented();
          return;
        }
        // Dart ints arrive as int32 when they fit, int64 otherwise.
        int count = 0;
        if (const auto* int32_arg = std::get_if<int32_t>(call.arguments())) {
          count = *int32_arg;
        } else if (const auto* int64_arg =
                       std::get_if<int64_t>(call.arguments())) {
          count =
              static_cast<int>(std::clamp<int64_t>(*int64_arg, 0, INT32_MAX));
        }
        taskbar_badge_.SetCount(count);
        result->Success();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // The channel talks through the engine's messenger, so it goes first.
  dock_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Watched ahead of the plugins, which could otherwise swallow it.
  taskbar_badge_.HandleMessage(message);

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
