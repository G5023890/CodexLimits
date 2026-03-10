import Foundation

@MainActor
final class LimitStore: ObservableObject {
    static let didChangeNotification = Notification.Name("CodexLimits.didChange")

    @Published private(set) var primarySnapshot = UsageSnapshot(
        title: "5h window",
        remainingPercent: 0,
        usedPercent: 100,
        resetDate: nil,
        windowDurationMinutes: 300
    )
    @Published private(set) var weeklySnapshot = UsageSnapshot(
        title: "Weekly",
        remainingPercent: 0,
        usedPercent: 100,
        resetDate: nil,
        windowDurationMinutes: 10080
    )
    @Published private(set) var usageDetails = UsageDetails(tokensUsed: nil, tokensRemaining: nil, requestsUsed: nil)
    @Published private(set) var planType = "Unknown"
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var lastError: String?

    private let calendar: Calendar
    private let client = CodexAppServerClient()
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 60
    private let notificationScheduler = NotificationScheduler.shared
    private lazy var relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    var heroSnapshot: UsageSnapshot {
        weeklySnapshot
    }

    var planName: String {
        planType.capitalized
    }

    var heroResetSummary: String {
        resetSummary(for: weeklySnapshot.resetDate)
    }

    var primaryResetSummary: String {
        resetSummary(for: primarySnapshot.resetDate)
    }

    var lastUpdatedText: String? {
        guard let lastUpdatedAt else {
            return nil
        }

        return lastUpdatedAt.formatted(date: .omitted, time: .shortened)
    }

    var tokensUsedText: String {
        formattedMetric(usageDetails.tokensUsed)
    }

    var tokensRemainingText: String {
        formattedMetric(usageDetails.tokensRemaining)
    }

    var requestsUsedText: String {
        formattedMetric(usageDetails.requestsUsed.map(Int64.init))
    }

    func startRefreshing() {
        Task {
            await notificationScheduler.requestAuthorizationIfNeeded()
        }

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }

            Task { @MainActor in
                await self.refresh()
            }
        }

        Task {
            await refresh()
        }
    }

    func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() async {
        do {
            let response = try await client.fetchRateLimits()
            let snapshot = response.rateLimits

            primarySnapshot = UsageSnapshot(
                title: "5h window",
                remainingPercent: max(0, 100 - snapshot.primary.usedPercent),
                usedPercent: snapshot.primary.usedPercent,
                resetDate: snapshot.primary.resetsAt,
                windowDurationMinutes: snapshot.primary.windowDurationMins
            )
            weeklySnapshot = UsageSnapshot(
                title: "Weekly",
                remainingPercent: max(0, 100 - snapshot.secondary.usedPercent),
                usedPercent: snapshot.secondary.usedPercent,
                resetDate: snapshot.secondary.resetsAt,
                windowDurationMinutes: snapshot.secondary.windowDurationMins
            )
            usageDetails = response.usageDetails ?? snapshot.usageDetails ?? UsageDetails(
                tokensUsed: nil,
                tokensRemaining: nil,
                requestsUsed: nil
            )
            planType = snapshot.planType.capitalized
            lastUpdatedAt = Date()
            lastError = nil
            await notificationScheduler.scheduleWeeklyResetNotification(at: weeklySnapshot.resetDate)
            notifyChange()
        } catch {
            lastError = error.localizedDescription
            notifyChange()
        }
    }

    func daysUntilWeeklyReset(from now: Date = Date()) -> Int {
        guard let weeklyResetDate = weeklySnapshot.resetDate else {
            return 0
        }

        if weeklyResetDate <= now {
            return 0
        }

        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: weeklyResetDate)
        let delta = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(delta, 0)
    }

    func resetSummary(for date: Date?, relativeTo now: Date = .now) -> String {
        guard let date else {
            return "Reset unavailable"
        }

        if date <= now {
            return "Resetting now"
        }

        let components = calendar.dateComponents([.day, .hour, .minute], from: now, to: date)
        if let day = components.day, day > 0 {
            return "Resets in \(day)d \(max(0, components.hour ?? 0))h"
        }

        if let hour = components.hour, hour > 0 {
            return "Resets in \(hour)h \(max(0, components.minute ?? 0))m"
        }

        if let minute = components.minute, minute > 0 {
            return "Resets in \(minute)m"
        }

        return "Resets soon"
    }

    func relativeResetText(for date: Date?, relativeTo now: Date = .now) -> String {
        guard let date else {
            return "Unavailable"
        }

        return relativeFormatter.localizedString(for: date, relativeTo: now)
    }

    func applyPreviewData(_ data: LimitsPreviewData) {
        primarySnapshot = data.primary
        weeklySnapshot = data.hero
        usageDetails = data.details
        planType = data.planName
        lastUpdatedAt = data.lastUpdated
        lastError = data.lastError
        notifyChange()
    }

    private func formattedMetric(_ value: Int64?) -> String {
        guard let value else {
            return "Unavailable"
        }

        if value >= 1_000_000_000 {
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        }

        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }

        if value >= 1_000 {
            return String(format: "%.0fK", Double(value) / 1_000)
        }

        return "\(value)"
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}

private struct AppServerResponse: Decodable {
    let id: Int?
    let result: ResultPayload?
    let error: AppServerError?
}

private struct ResultPayload: Decodable {
    let rateLimits: RateLimitSnapshot
    let usageDetails: UsageDetails?

    enum CodingKeys: String, CodingKey {
        case rateLimits
        case usageDetails
        case totalTokenUsage
        case tokenUsage
        case usage
        case requestsUsed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rateLimits = try container.decode(RateLimitSnapshot.self, forKey: .rateLimits)

        let totalUsage = try container.decodeIfPresent(TokenUsagePayload.self, forKey: .totalTokenUsage)
            ?? container.decodeIfPresent(TokenUsagePayload.self, forKey: .tokenUsage)
            ?? container.decodeIfPresent(TokenUsagePayload.self, forKey: .usage)
        let requestsUsed = try container.decodeIfPresent(Int.self, forKey: .requestsUsed)
        if totalUsage != nil || requestsUsed != nil {
            usageDetails = UsageDetails(
                tokensUsed: totalUsage?.inputTokens ?? totalUsage?.totalTokens,
                tokensRemaining: totalUsage?.remainingTokens,
                requestsUsed: requestsUsed
            )
        } else {
            usageDetails = nil
        }
    }
}

private struct AppServerError: Decodable {
    let code: Int
    let message: String
}

private struct RateLimitSnapshot: Decodable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow
    let secondary: RateLimitWindow
    let credits: CreditSnapshot?
    let planType: String
    let usageDetails: UsageDetails?

    enum CodingKeys: String, CodingKey {
        case limitId
        case limitName
        case primary
        case secondary
        case credits
        case planType
        case usageDetails
        case tokenUsage
        case totalTokenUsage
        case requestsUsed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        limitId = try container.decodeIfPresent(String.self, forKey: .limitId)
        limitName = try container.decodeIfPresent(String.self, forKey: .limitName)
        primary = try container.decode(RateLimitWindow.self, forKey: .primary)
        secondary = try container.decode(RateLimitWindow.self, forKey: .secondary)
        credits = try container.decodeIfPresent(CreditSnapshot.self, forKey: .credits)
        planType = try container.decodeIfPresent(String.self, forKey: .planType) ?? "unknown"

        let totalUsage = try container.decodeIfPresent(TokenUsagePayload.self, forKey: .totalTokenUsage)
            ?? container.decodeIfPresent(TokenUsagePayload.self, forKey: .tokenUsage)
        let requestsUsed = try container.decodeIfPresent(Int.self, forKey: .requestsUsed)
        if totalUsage != nil || requestsUsed != nil {
            usageDetails = UsageDetails(
                tokensUsed: totalUsage?.inputTokens ?? totalUsage?.totalTokens,
                tokensRemaining: totalUsage?.remainingTokens,
                requestsUsed: requestsUsed
            )
        } else {
            usageDetails = nil
        }
    }
}

private struct RateLimitWindow: Decodable {
    let usedPercent: Int
    let windowDurationMins: Int?
    let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case usedPercent
        case windowDurationMins
        case resetsAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try container.decode(Int.self, forKey: .usedPercent)
        windowDurationMins = try container.decodeIfPresent(Int.self, forKey: .windowDurationMins)

        if let timestamp = try container.decodeIfPresent(Int64.self, forKey: .resetsAt) {
            resetsAt = Date(timeIntervalSince1970: TimeInterval(timestamp))
        } else {
            resetsAt = nil
        }
    }
}

private struct CreditSnapshot: Decodable {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String
}

private struct TokenUsagePayload: Decodable {
    let inputTokens: Int64?
    let cachedInputTokens: Int64?
    let outputTokens: Int64?
    let reasoningOutputTokens: Int64?
    let totalTokens: Int64?
    let remainingTokens: Int64?

    enum CodingKeys: String, CodingKey {
        case inputTokens
        case cachedInputTokens
        case outputTokens
        case reasoningOutputTokens
        case totalTokens
        case remainingTokens
    }
}

private actor CodexAppServerClient {
    private let codexExecutable = "/Applications/Codex.app/Contents/Resources/codex"

    func fetchRateLimits() async throws -> ResultPayload {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", pythonBridgeScript, codexExecutable]
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
        environment["CODEX_HOME"] = environment["CODEX_HOME"] ?? "\(NSHomeDirectory())/.codex"
        environment["PATH"] = environment["PATH"] ?? "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["TERM"] = "xterm-256color"
        process.environment = environment
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            let message = stderr.isEmpty ? "Failed to read Codex rate limits" : stderr
            throw NSError(domain: "CodexAppServer", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
        }

        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !stdout.isEmpty else {
            let message = stderr.isEmpty ? "Codex rate limit bridge returned no output" : stderr
            throw NSError(domain: "CodexAppServer", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        let response = try JSONDecoder().decode(AppServerResponse.self, from: Data(stdout.utf8))
        if let error = response.error {
            throw NSError(domain: "CodexAppServer", code: error.code, userInfo: [NSLocalizedDescriptionKey: error.message])
        }
        guard let result = response.result else {
            throw NSError(domain: "CodexAppServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Codex returned an empty rate limit response"])
        }

        return result
    }

    private var pythonBridgeScript: String {
        #"""
        import json
        import os
        import pty
        import select
        import subprocess
        import sys
        import time

        codex = sys.argv[1]
        env = os.environ.copy()
        master, slave = pty.openpty()

        proc = subprocess.Popen(
            [codex, "app-server", "--listen", "stdio://"],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            env=env,
            close_fds=True,
        )
        os.close(slave)

        def write_line(payload):
            os.write(master, payload.encode("utf-8") + b"\n")

        def read_until(expected_id, timeout=8.0):
            buffer = b""
            deadline = time.time() + timeout
            transcript = []
            while time.time() < deadline:
                remaining = max(0.1, deadline - time.time())
                readable, _, _ = select.select([master], [], [], min(0.25, remaining))
                if master not in readable:
                    continue
                chunk = os.read(master, 4096)
                if not chunk:
                    break
                buffer += chunk
                while b"\n" in buffer:
                    line, buffer = buffer.split(b"\n", 1)
                    text = line.decode("utf-8", "ignore").strip()
                    if not text:
                        continue
                    transcript.append(text)
                    try:
                        obj = json.loads(text)
                    except Exception:
                        continue
                    if obj.get("id") == expected_id and ("result" in obj or "error" in obj):
                        return obj
            raise SystemExit(f"Timed out waiting for response {expected_id}. Log: {' | '.join(transcript[-8:])}")

        write_line('{"id":1,"method":"initialize","params":{"clientInfo":{"name":"CodexLimits","version":"1.0"},"capabilities":{"experimentalApi":true}}}')
        read_until(1)
        write_line('{"method":"initialized"}')
        write_line('{"id":2,"method":"account/rateLimits/read"}')
        result = read_until(2)
        print(json.dumps(result), end="")

        try:
            proc.terminate()
        except Exception:
            pass
        """#
    }
}
