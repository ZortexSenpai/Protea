import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Unread badge on the Dock icon, driven by lib/src/dock_badge.dart.
    let dockChannel = FlutterMethodChannel(
      name: "protea/dock",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    dockChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "setBadgeCount":
        let count = call.arguments as? Int ?? 0
        NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Clipboard reads pasteboard gets wrong, driven by
    // lib/src/attachment_actions.dart.
    let clipboardChannel = FlutterMethodChannel(
      name: "protea/clipboard",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    clipboardChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "files":
        // File URLs only: a copied web link is an NSURL too. filePathURL
        // resolves file reference URLs (file:///.file/id=…) to real paths.
        let urls = NSPasteboard.general.readObjects(
          forClasses: [NSURL.self],
          options: [.urlReadingFileURLsOnly: true]) ?? []
        result(urls.compactMap { ($0 as? NSURL)?.filePathURL?.path })
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
