import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = LimitStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var observer: NSObjectProtocol?
    private var statusHostingView: StatusItemHostingView?
    private var popoverHostingController: NSHostingController<PopoverView>?
    private var isPopoverPresented = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        configurePopover()
        configureStatusItem()

        observer = NotificationCenter.default.addObserver(
            forName: LimitStore.didChangeNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateUI()
            }
        }

        store.startRefreshing()
        updateUI()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopRefreshing()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        isPopoverPresented = false
        updateStatusItemContent()
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            isPopoverPresented = false
        } else {
            isPopoverPresented = true
            updatePopoverContent()
            updateStatusItemContent()
            Task {
                await store.refresh()
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        }

        updateStatusItemContent()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 326, height: 420)

        let controller = NSHostingController(rootView: makePopoverView())
        popover.contentViewController = controller
        popoverHostingController = controller
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.image = nil
        button.title = ""
        button.imagePosition = .imageOnly

        let hostingView = StatusItemHostingView(rootView: AnyView(makeStatusItemView()))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        statusHostingView = hostingView
    }

    private func updateUI() {
        updateStatusItemContent()
        updatePopoverContent()
    }

    private func updateStatusItemContent() {
        guard let button = statusItem?.button else {
            return
        }

        statusHostingView?.rootView = AnyView(makeStatusItemView())
        button.toolTip = "Codex: \(store.heroSnapshot.percentText) weekly remaining"
        button.needsLayout = true
        button.layoutSubtreeIfNeeded()
    }

    private func updatePopoverContent() {
        popoverHostingController?.rootView = makePopoverView()
    }

    private func makeStatusItemView() -> StatusItemView {
        StatusItemView(snapshot: store.heroSnapshot, isActive: isPopoverPresented)
    }

    private func makePopoverView() -> PopoverView {
        PopoverView(
            store: store,
            onRefresh: { [weak self] in
                guard let self else {
                    return
                }

                Task {
                    await self.store.refresh()
                }
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
    }
}

private final class StatusItemHostingView: NSHostingView<AnyView> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
