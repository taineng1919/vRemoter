#if DEBUG
import AppKit
import Foundation

/// A text target attached to the COMPLETE App, not a replacement voice harness.
/// Enabled only by an explicit workspace data profile in a debug build.
final class DevelopmentValidation: NSObject, NSTextViewDelegate {
    private var window: NSWindow!
    private var textView: NSTextView!
    private var timer: Timer?
    private let root: URL
    private let snapshot: () -> String
    private let stop: () -> Void

    init(root: URL, snapshot: @escaping () -> String, stop: @escaping () -> Void) {
        self.root = root
        self.snapshot = snapshot
        self.stop = stop
        super.init()
        window = NSWindow(
            contentRect: NSRect(x: 180, y: 180, width: 820, height: 440),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.title = "vRemoter 9451 完整 App 验收（独立数据）"
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        textView = NSTextView(frame: scroll.bounds)
        textView.font = .systemFont(ofSize: 22)
        textView.isRichText = false
        textView.delegate = self
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView
        window.contentView!.addSubview(scroll)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        NSApp.activate(ignoringOtherApps: true)
        print("[ACCEPTANCE] Full App profile=\(root.path); \(snapshot())")
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) {
            [weak self] _ in self?.poll()
        }
    }

    func textDidChange(_ notification: Notification) {
        try? textView.string.write(
            to: root.appendingPathComponent("transcript.txt"), atomically: true,
            encoding: .utf8
        )
        print("[ACCEPTANCE] TEXT_CHANGE marked=\(textView.hasMarkedText()) text=\(textView.string.debugDescription)")
    }

    private func poll() {
        let file = root.appendingPathComponent("command.txt")
        guard let command = try? String(contentsOf: file, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: file)
        switch command.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "focus":
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(textView)
            NSApp.activate(ignoringOtherApps: true)
        case "snapshot": print("[ACCEPTANCE] SNAPSHOT \(snapshot())")
        case "stop": stop()
        case "quit": NSApp.terminate(nil)
        default: break
        }
    }

    func close() { timer?.invalidate(); timer = nil }
}
#endif
