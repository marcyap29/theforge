import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Channel used to deliver dictated text (theforge://paste) to Flutter,
    // which inserts it into the focused field at the caret.
    AppDelegate.pasteChannel = FlutterMethodChannel(
      name: "theforge/paste",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
