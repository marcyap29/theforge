import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Set by MainFlutterWindow once the engine exists. Used to forward
  /// theforge://paste URLs to Flutter.
  static var pasteChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Handles the `theforge://paste` URL scheme (dictation from Sabihin).
  /// We come to the foreground so the previously-focused text field regains
  /// key focus, then tell Flutter to paste the clipboard at the caret.
  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where url.scheme == "theforge" {
      NSApp.activate(ignoringOtherApps: true)
      AppDelegate.pasteChannel?.invokeMethod("paste", arguments: url.absoluteString)
    }
  }
}
