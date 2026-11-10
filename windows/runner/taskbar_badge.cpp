#include "taskbar_badge.h"

#include <shobjidl.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>

namespace {

// Windows 11's critical/attention red, behind white text.
constexpr int kFillRed = 0xC4;
constexpr int kFillGreen = 0x2B;
constexpr int kFillBlue = 0x1C;

// Draws the badge: a red circle with |count| in white, "9+" above nine so
// the label stays legible at 16 px. Returns nullptr on failure.
HICON CreateBadgeIcon(int count, int size) {
  const std::wstring label = count > 9 ? L"9+" : std::to_wstring(count);

  BITMAPINFO info = {};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = size;
  info.bmiHeader.biHeight = -size;  // Top-down rows.
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  void* bits = nullptr;
  HBITMAP color =
      CreateDIBSection(nullptr, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
  if (!color) {
    return nullptr;
  }
  auto* pixels = static_cast<uint32_t*>(bits);
  const int pixel_count = size * size;
  std::fill(pixels, pixels + pixel_count, 0u);

  // GDI text has no usable alpha, so render the label white-on-black and
  // use its brightness as ink coverage.
  HDC dc = CreateCompatibleDC(nullptr);
  HGDIOBJ old_bitmap = SelectObject(dc, color);
  HFONT font = CreateFontW(-MulDiv(size, label.size() > 1 ? 62 : 72, 100), 0,
                           0, 0, FW_BOLD, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                           OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                           ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_SWISS,
                           L"Segoe UI");
  HGDIOBJ old_font = SelectObject(dc, font);
  SetTextColor(dc, RGB(255, 255, 255));
  SetBkMode(dc, TRANSPARENT);
  RECT bounds = {0, 0, size, size};
  DrawTextW(dc, label.c_str(), static_cast<int>(label.size()), &bounds,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
  GdiFlush();
  SelectObject(dc, old_font);
  DeleteObject(font);
  SelectObject(dc, old_bitmap);
  DeleteDC(dc);

  std::vector<uint8_t> ink(pixel_count);
  int min_x = size, max_x = -1, min_y = size, max_y = -1;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      const uint32_t pixel = pixels[y * size + x];
      const uint8_t coverage = static_cast<uint8_t>(
          std::max({pixel & 0xFF, (pixel >> 8) & 0xFF, (pixel >> 16) & 0xFF}));
      ink[y * size + x] = coverage;
      if (coverage > 0) {
        min_x = std::min(min_x, x);
        max_x = std::max(max_x, x);
        min_y = std::min(min_y, y);
        max_y = std::max(max_y, y);
      }
    }
  }
  // DT_VCENTER centers the font's cell, not the digits' ink, which leaves
  // them visibly off-center at this size; center the ink itself.
  const int shift_x =
      max_x < 0 ? 0 : static_cast<int>(std::lround((size - 1 - min_x - max_x) / 2.0));
  const int shift_y =
      max_y < 0 ? 0 : static_cast<int>(std::lround((size - 1 - min_y - max_y) / 2.0));

  // Compose the circle (4x4 supersampled edge) with the ink on top. Icons
  // take straight, not premultiplied, alpha.
  constexpr int kSamples = 4;
  const double radius = size / 2.0;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      int inside = 0;
      for (int sy = 0; sy < kSamples; sy++) {
        for (int sx = 0; sx < kSamples; sx++) {
          const double dx = x + (sx + 0.5) / kSamples - radius;
          const double dy = y + (sy + 0.5) / kSamples - radius;
          if (dx * dx + dy * dy <= radius * radius) {
            inside++;
          }
        }
      }
      const int source_x = x - shift_x;
      const int source_y = y - shift_y;
      const int coverage =
          source_x >= 0 && source_x < size && source_y >= 0 && source_y < size
              ? ink[source_y * size + source_x]
              : 0;
      const auto blend = [coverage](int channel) {
        return static_cast<uint32_t>(channel +
                                     (255 - channel) * coverage / 255);
      };
      const auto alpha =
          static_cast<uint32_t>(inside * 255 / (kSamples * kSamples));
      pixels[y * size + x] = alpha << 24 | blend(kFillRed) << 16 |
                             blend(kFillGreen) << 8 | blend(kFillBlue);
    }
  }

  // The mask is ignored when the color bitmap has alpha, but it must exist.
  // Monochrome rows are WORD-aligned.
  const std::vector<uint8_t> mask_bits(((size + 15) / 16) * 2 * size, 0);
  HBITMAP mask = CreateBitmap(size, size, 1, 1, mask_bits.data());
  HICON icon = nullptr;
  if (mask) {
    ICONINFO icon_info = {TRUE, 0, 0, mask, color};
    icon = CreateIconIndirect(&icon_info);
    DeleteObject(mask);
  }
  DeleteObject(color);
  return icon;
}

}  // namespace

void TaskbarBadge::Attach(HWND window) {
  window_ = window;
  button_created_message_ = RegisterWindowMessageW(L"TaskbarButtonCreated");
  // Explorer runs unelevated; let its message through when Protea doesn't.
  if (button_created_message_ != 0) {
    ChangeWindowMessageFilterEx(window, button_created_message_, MSGFLT_ALLOW,
                                nullptr);
  }
}

void TaskbarBadge::HandleMessage(UINT message) {
  if (button_created_message_ != 0 && message == button_created_message_) {
    button_ready_ = true;
    Apply();
  }
}

void TaskbarBadge::SetCount(int count) {
  count = std::max(count, 0);
  if (count == count_) {
    return;
  }
  count_ = count;
  Apply();
}

void TaskbarBadge::Apply() {
  if (!window_ || !button_ready_) {
    return;
  }
  // Created per call rather than kept: quitting runs the window's teardown
  // after main() has called CoUninitialize, which unloads the DLL a kept
  // instance would then be released into.
  Microsoft::WRL::ComPtr<ITaskbarList3> taskbar;
  if (FAILED(CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&taskbar))) ||
      FAILED(taskbar->HrInit())) {
    return;
  }
  HICON icon = count_ > 0
                   ? CreateBadgeIcon(count_, GetSystemMetrics(SM_CXSMICON))
                   : nullptr;
  // Read out by screen readers alongside the window title.
  const std::wstring description = count_ > 0 ? std::to_wstring(count_) : L"";
  taskbar->SetOverlayIcon(window_, icon, description.c_str());
  // The taskbar keeps its own copy.
  if (icon) {
    DestroyIcon(icon);
  }
}
