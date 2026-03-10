import AppKit

@MainActor
enum AppAssets {
    static func appIcon() -> NSImage? {
        guard let image = NSApp.applicationIconImage.copy() as? NSImage else {
            return nil
        }
        image.size = NSSize(width: 30, height: 30)
        return image
    }
}
