#ifndef RUNNER_TASKBAR_BADGE_H_
#define RUNNER_TASKBAR_BADGE_H_

#include <windows.h>

// The unread count as an overlay icon (a red dot with the number) on the
// window's taskbar button, driven by lib/src/dock_badge.dart.
//
// The taskbar ignores overlays until it has created the button, and it
// creates the button anew whenever the window is shown again after hiding
// to the tray or Explorer restarts, dropping the overlay each time. So the
// count is kept here and reapplied on every TaskbarButtonCreated.
class TaskbarBadge {
 public:
  // Starts listening for |window|'s taskbar button.
  void Attach(HWND window);

  // Feeds a top-level window message; reapplies the overlay when it is
  // TaskbarButtonCreated. Never consumes the message.
  void HandleMessage(UINT message);

  // Shows |count| on the taskbar button, or nothing when it is 0.
  void SetCount(int count);

 private:
  void Apply();

  HWND window_ = nullptr;
  UINT button_created_message_ = 0;
  bool button_ready_ = false;
  int count_ = 0;
};

#endif  // RUNNER_TASKBAR_BADGE_H_
