import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    self.title = "DOKUNYA"
    let channel = FlutterMethodChannel(name: "dev.artpulse/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "fullscreen", let enabled = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      if let window = self, window.styleMask.contains(.fullScreen) != enabled {
        window.toggleFullScreen(nil)
      }
      result(nil)
    }
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
