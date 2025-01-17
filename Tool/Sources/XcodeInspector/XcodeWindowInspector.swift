import AppKit
import AXExtension
import AXNotificationStream
import Combine
import Foundation

public class XcodeWindowInspector: ObservableObject {
    let uiElement: AXUIElement

    init(uiElement: AXUIElement) {
        self.uiElement = uiElement
    }
}

public final class WorkspaceXcodeWindowInspector: XcodeWindowInspector {
    let app: NSRunningApplication
    @Published var documentURL: URL = .init(fileURLWithPath: "/")
    @Published var workspaceURL: URL = .init(fileURLWithPath: "/")
    @Published var projectRootURL: URL = .init(fileURLWithPath: "/")
    private var updateTabsTask: Task<Void, Error>?
    private var focusedElementChangedTask: Task<Void, Error>?

    deinit {
        updateTabsTask?.cancel()
        focusedElementChangedTask?.cancel()
    }

    public func refresh() {
        updateURLs()
    }

    public init(app: NSRunningApplication, uiElement: AXUIElement) {
        self.app = app
        super.init(uiElement: uiElement)

        focusedElementChangedTask = Task { @MainActor in
            updateURLs()

            Task { @MainActor in
                // prevent that documentURL may not be available yet
                try await Task.sleep(nanoseconds: 500_000_000)
                if documentURL == .init(fileURLWithPath: "/") {
                    updateURLs()
                }
            }

            let notifications = AXNotificationStream(
                app: app,
                notificationNames: kAXFocusedUIElementChangedNotification
            )

            for await _ in notifications {
                try Task.checkCancellation()
                updateURLs()
            }
        }
    }

    func updateURLs() {
        let documentURL = Self.extractDocumentURL(windowElement: uiElement)
        if let documentURL {
            self.documentURL = documentURL
        }
        let workspaceURL = Self.extractWorkspaceURL(windowElement: uiElement)
        if let workspaceURL {
            self.workspaceURL = workspaceURL
        }
        let projectURL = Self.extractProjectURL(
            workspaceURL: workspaceURL,
            documentURL: documentURL
        )
        if let projectURL {
            projectRootURL = projectURL
        }
    }

    static func extractDocumentURL(
        windowElement: AXUIElement
    ) -> URL? {
        // fetch file path of the frontmost window of Xcode through Accessibility API.
        let path = windowElement.document
        if let path = path?.removingPercentEncoding {
            let url = URL(
                fileURLWithPath: path
                    .replacingOccurrences(of: "file://", with: "")
            )
            return url
        }
        return nil
    }

    static func extractWorkspaceURL(
        windowElement: AXUIElement
    ) -> URL? {
        for child in windowElement.children {
            if child.description.starts(with: "/"), child.description.count > 1 {
                let path = child.description
                let trimmedNewLine = path.trimmingCharacters(in: .newlines)
                let url = URL(fileURLWithPath: trimmedNewLine)
                return url
            }
        }
        return nil
    }

    public static func extractProjectURL(
        workspaceURL: URL?,
        documentURL: URL?
    ) -> URL? {
        guard var currentURL = workspaceURL ?? documentURL else { return nil }
        var firstDirectoryURL: URL?
        var lastGitDirectoryURL: URL?
        while currentURL.pathComponents.count > 1 {
            defer { currentURL.deleteLastPathComponent() }
            guard FileManager.default.fileIsDirectory(atPath: currentURL.path) else { continue }
            guard currentURL.pathExtension != "xcodeproj" else { continue }
            guard currentURL.pathExtension != "xcworkspace" else { continue }
            guard currentURL.pathExtension != "playground" else { continue }
            if firstDirectoryURL == nil { firstDirectoryURL = currentURL }
            let gitURL = currentURL.appendingPathComponent(".git")
            if FileManager.default.fileIsDirectory(atPath: gitURL.path) {
                lastGitDirectoryURL = currentURL
            } else if let text = try? String(contentsOf: gitURL) {
                if !text.hasPrefix("gitdir: ../"), // it's not a sub module
                   text.range(of: "/.git/worktrees/") != nil // it's a git worktree
                {
                    lastGitDirectoryURL = currentURL
                }
            }
        }

        return lastGitDirectoryURL ?? firstDirectoryURL ?? workspaceURL
    }
}

