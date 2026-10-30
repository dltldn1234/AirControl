import AppKit
import Foundation

struct RunningAppInfo: Equatable, Identifiable {
    let bundleIdentifier: String
    let localizedName: String

    var id: String { bundleIdentifier }
}

final class RunningAppSwitcher {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    var visibleApplications: [NSRunningApplication] {
        workspace.runningApplications.filter { application in
            application.activationPolicy == .regular
                && !application.isHidden
                && !application.isTerminated
                && application.bundleIdentifier != Bundle.main.bundleIdentifier
        }
    }

    var visibleApplicationInfo: [RunningAppInfo] {
        visibleApplications.compactMap { application in
            guard let bundleIdentifier = application.bundleIdentifier else { return nil }
            return RunningAppInfo(
                bundleIdentifier: bundleIdentifier,
                localizedName: application.localizedName ?? bundleIdentifier
            )
        }
    }

    @discardableResult
    func activateNext(direction: Int) -> Bool {
        let applications = visibleApplications
        guard !applications.isEmpty else { return false }
        let frontmostBundle = workspace.frontmostApplication?.bundleIdentifier
        let currentIndex = applications.firstIndex { $0.bundleIdentifier == frontmostBundle } ?? 0
        let step = direction >= 0 ? 1 : -1
        let nextIndex = (currentIndex + step + applications.count) % applications.count
        let application = applications[nextIndex]
        DispatchQueue.main.async {
            _ = application.activate(options: [.activateAllWindows])
        }
        return true
    }
}
