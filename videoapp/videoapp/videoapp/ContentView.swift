//
//  ContentView.swift
//  videoapp
//
//  Created by Ho Yeung, Lee on 2/4/2026.
//

import SwiftUI
import AVKit
import Combine

// MARK: - Models
struct Video: Identifiable, Hashable {
    let id: UUID
    var title: String
    var url: URL?
    var thumbnailURL: URL?
    var author: String
    var duration: TimeInterval
    var uploadedAt: Date
    var viewCount: Int
    var comments: [Comment]

    init(
        id: UUID = UUID(),
        title: String,
        url: URL? = nil,
        thumbnailURL: URL? = nil,
        author: String = "Channel",
        duration: TimeInterval = 0,
        uploadedAt: Date = .now,
        viewCount: Int = 0,
        comments: [Comment] = []
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.author = author
        self.duration = duration
        self.uploadedAt = uploadedAt
        self.viewCount = viewCount
        self.comments = comments
    }
}

struct Comment: Identifiable, Hashable {
    let id: UUID
    var author: String
    var text: String
    var date: Date

    init(id: UUID = UUID(), author: String, text: String, date: Date = .now) {
        self.id = id
        self.author = author
        self.text = text
        self.date = date
    }
}

fileprivate func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

fileprivate func timeAgoString(from date: Date) -> String {
    let interval = Int(Date().timeIntervalSince(date))
    let minute = 60, hour = 3600, day = 86400, week = 604800, month = 2592000, year = 31536000
    switch interval {
    case 0..<minute: return "just now"
    case minute..<hour: return "\(interval / minute)m ago"
    case hour..<day: return "\(interval / hour)h ago"
    case day..<week: return "\(interval / day)d ago"
    case week..<month: return "\(interval / week)w ago"
    case month..<year: return "\(interval / month)mo ago"
    default: return "\(interval / year)y ago"
    }
}

// MARK: - Security & Privacy

struct PrivacySettings {
    static let blockedSchemes: Set<String> = ["javascript", "data", "file", "about", "ws", "wss", "ftp"]
    static let trackingQueryPrefixes: [String] = ["utm_", "gclid", "fbclid", "mc_eid", "mc_cid"]
    static let suspiciousHostSubstrings: [String] = ["doubleclick", "googlesyndication", "adservice", "adsystem", "ads.", ".ads", "tracking", "pixel"]
    static let allowedVideoExtensions: Set<String> = ["mp4", "m4v", "mov", "webm", "mkv"]
    static let maxDownloadBytes: Int64 = 500 * 1024 * 1024 // 500 MB

    static let allowedImageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "heic"]
    static let maxImageBytes: Int64 = 20 * 1024 * 1024 // 20 MB
    static let maxUploadBytes: Int64 = 500 * 1024 * 1024 // 500 MB
}

fileprivate func sanitizeAndValidateURL(_ url: URL) -> URL? {
    // Only allow http/https
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
    guard let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return nil }

    // Block suspicious hosts
    guard let host = components.host?.lowercased(), !host.isEmpty else { return nil }
    for s in PrivacySettings.suspiciousHostSubstrings where host.contains(s) { return nil }

    // Drop fragment and strip common tracking query parameters
    components.fragment = nil
    if let items = components.queryItems, !items.isEmpty {
        components.queryItems = items.filter { item in
            let name = item.name.lowercased()
            return !PrivacySettings.trackingQueryPrefixes.contains { prefix in name.hasPrefix(prefix) }
        }
        if components.queryItems?.isEmpty == true { components.queryItems = nil }
    }

    return components.url
}

fileprivate func isLikelyVideoResponse(contentType: String?, url: URL) -> Bool {
    if let ct = contentType?.lowercased() {
        if ct.hasPrefix("video/") { return true }
        if ct == "application/octet-stream" { return true }
        if ct.contains("text/html") || ct.contains("javascript") { return false }
    }
    let ext = url.pathExtension.lowercased()
    return PrivacySettings.allowedVideoExtensions.contains(ext)
}

fileprivate func isLikelyImageResponse(contentType: String?, url: URL) -> Bool {
    if let ct = contentType?.lowercased() {
        if ct.hasPrefix("image/") { return true }
        if ct.contains("text/html") || ct.contains("javascript") { return false }
    }
    let ext = url.pathExtension.lowercased()
    return PrivacySettings.allowedImageExtensions.contains(ext)
}

actor SecureVideoLoader {
    static let shared = SecureVideoLoader()

    func fetchPlayableURL(from original: URL) async throws -> URL {
        guard let safeURL = sanitizeAndValidateURL(original) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: safeURL)
        request.httpMethod = "GET"
        request.setValue("video/*,application/octet-stream;q=0.9", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 60

        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpCookieAcceptPolicy = .never
        cfg.httpShouldSetCookies = false
        cfg.httpCookieStorage = nil
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        cfg.waitsForConnectivity = false

        let session = URLSession(configuration: cfg)
        let (tempURL, response) = try await session.download(for: request)

        // Enforce size limit even if Content-Length was missing
        let fmCheck = FileManager.default
        if let attrs = try? fmCheck.attributesOfItem(atPath: tempURL.path),
           let fileSize = attrs[.size] as? NSNumber,
           fileSize.int64Value > PrivacySettings.maxDownloadBytes {
            throw URLError(.dataLengthExceedsMaximum)
        }

        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...206).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        if let host = safeURL.host?.lowercased() {
            for s in PrivacySettings.suspiciousHostSubstrings where host.contains(s) {
                throw URLError(.cannotLoadFromNetwork)
            }
        }

        let contentType = http.value(forHTTPHeaderField: "Content-Type")
        guard isLikelyVideoResponse(contentType: contentType, url: safeURL) else {
            throw URLError(.cannotDecodeContentData)
        }

        if let lenStr = http.value(forHTTPHeaderField: "Content-Length"),
           let len = Int64(lenStr), len > PrivacySettings.maxDownloadBytes {
            throw URLError(.dataLengthExceedsMaximum)
        }

        // Persist to a stable temp location
        let fm = FileManager.default
        let ext = safeURL.pathExtension.isEmpty ? "mp4" : safeURL.pathExtension
        let dest = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        do {
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: tempURL, to: dest)
        } catch {
            try fm.copyItem(at: tempURL, to: dest)
        }
        return dest
    }
}

actor SecureImageLoader {
    static let shared = SecureImageLoader()

    func fetchImageData(from original: URL) async throws -> Data {
        guard let safeURL = sanitizeAndValidateURL(original) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: safeURL)
        request.httpMethod = "GET"
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 30

        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpCookieAcceptPolicy = .never
        cfg.httpShouldSetCookies = false
        cfg.httpCookieStorage = nil
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        cfg.waitsForConnectivity = false

        let session = URLSession(configuration: cfg)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...206).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type")
        guard isLikelyImageResponse(contentType: contentType, url: safeURL) else {
            throw URLError(.cannotDecodeContentData)
        }
        if data.count > Int(PrivacySettings.maxImageBytes) {
            throw URLError(.dataLengthExceedsMaximum)
        }
        return data
    }
}

fileprivate func cleanUserText(_ text: String, maxLength: Int = 500) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let filteredScalars = trimmed.unicodeScalars.filter { scalar in
        // Remove control characters and non-characters
        return !CharacterSet.controlCharacters.contains(scalar)
    }
    let cleaned = String(String.UnicodeScalarView(filteredScalars))
    if cleaned.count > maxLength {
        let idx = cleaned.index(cleaned.startIndex, offsetBy: maxLength)
        return String(cleaned[..<idx])
    }
    return cleaned
}

// MARK: - Services (Mock AWS Upload)
@MainActor
final class CloudUploadService: ObservableObject {
    enum UploadState: Equatable { case idle, uploading(progress: Double), success(URL), failure(String) }
    @Published var state: UploadState = .idle

    func upload(data: Data, fileName: String) async {
        // Placeholder for AWS S3 integration. Simulate progress.
        self.state = .uploading(progress: 0)
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            self.state = .uploading(progress: Double(i) / 10.0)
        }
        // Simulate a remote URL after uploading (sanitize filename and avoid force-unwrap)
        let safeName = fileName.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        if let url = URL(string: "https://example-bucket.s3.amazonaws.com/\(safeName)") {
            self.state = .success(url)
        } else {
            self.state = .failure("Invalid file name")
        }
    }

    func reset() { state = .idle }
}

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
    @Published var videos: [Video] = [
        Video(
            title: "Welcome to Vanilla Video Exhitbition App",
            url: nil,
            thumbnailURL: nil,
            author: "Ho Yeung, Lee",
            duration: 245,
            uploadedAt: .now.addingTimeInterval(-3 * 24 * 3600),
            viewCount: 42,
            comments: [
                Comment(author: "Martin", text: "Nice intro!"),
                Comment(author: "Priscilla", text: "Looking forward to more.")
            ]
        ),
        Video(
            title: "Sample Video",
            url: nil,
            thumbnailURL: nil,
            author: "demo",
            duration: 95,
            uploadedAt: .now.addingTimeInterval(-5 * 3600),
            viewCount: 7
        )
    ]
    @Published var isLoggedIn: Bool = false
    @Published var privacyModeEnabled: Bool = true
}

// MARK: - Reusable Confirm Transition
struct ConfirmTransitionModifier: ViewModifier {
    @Binding var isPresenting: Bool
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresenting) {
                Button(cancelTitle, role: .cancel) { }
                Button(confirmTitle) { onConfirm() }
            } message: {
                Text(message)
            }
    }
}

extension View {
    func confirmTransition(isPresenting: Binding<Bool>, title: String = "Confirm", message: String = "Are you sure?", confirmTitle: String = "Continue", cancelTitle: String = "Cancel", onConfirm: @escaping () -> Void) -> some View {
        modifier(ConfirmTransitionModifier(isPresenting: isPresenting, title: title, message: message, confirmTitle: confirmTitle, cancelTitle: cancelTitle, onConfirm: onConfirm))
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        NavigationStack {
            HomeView()
                .environmentObject(appState)
                .navigationTitle("Videos")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        PrivacyToggle()
                            .environmentObject(appState)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        LoginLink()
                            .environmentObject(appState)
                    }
                    ToolbarItem(placement: .bottomBar) {
                        UploadLink()
                    }
                }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var pendingNavigation: Video?
    @State private var showConfirm = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(appState.videos) { video in
                    VideoCardView(video: video)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            pendingNavigation = video
                            showConfirm = true
                        }
                }
                .padding(.horizontal)
            }
        }
        .navigationDestination(item: $pendingNavigation) { video in
            VideoDetailView(video: video)
                .environmentObject(appState)
        }
        .confirmTransition(isPresenting: $showConfirm, title: "Open Video", message: "Do you want to open this video?", confirmTitle: "Open", cancelTitle: "Cancel") {
            if let v = pendingNavigation { pendingNavigation = v }
        }
    }
}

struct SecureAsyncImage: View {
    let url: URL
    let placeholder: AnyView
    @State private var image: Image? = nil

    var body: some View {
        Group {
            if let img = image {
                img.resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        do {
            let data = try await SecureImageLoader.shared.fetchImageData(from: url)
            #if canImport(UIKit)
            if let ui = UIImage(data: data) {
                image = Image(uiImage: ui)
            }
            #elseif canImport(AppKit)
            if let ns = NSImage(data: data) {
                image = Image(nsImage: ns)
            }
            #endif
        } catch {
            // keep placeholder
        }
    }
}

struct VideoCardView: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let thumb = video.thumbnailURL {
                        SecureAsyncImage(url: thumb, placeholder: AnyView(placeholder.redacted(reason: .placeholder)))
                    } else {
                        placeholder
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()

                Text(formatDuration(video.duration))
                    .font(.caption2).bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(6)
            }

            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .overlay(Text(String(video.author.prefix(1))).font(.subheadline).bold())
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(video.author) • \(video.viewCount) views • \(timeAgoString(from: video.uploadedAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var placeholder: some View {
        LinearGradient(colors: [.gray.opacity(0.35), .gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct VideoDetailView: View {
    @EnvironmentObject var appState: AppState
    @State var video: Video

    @State private var player: AVPlayer? = nil
    @State private var isBlockingAlert = false
    @State private var blockingMessage = ""

    @State private var newComment: String = ""
    @State private var showBackConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            if let p = player {
                VideoPlayer(player: p)
                    .frame(height: 220)
            } else {
                ZStack {
                    Rectangle().fill(.gray.opacity(0.2)).frame(height: 220)
                    Image(systemName: "play.rectangle.fill").font(.system(size: 56)).foregroundStyle(.secondary)
                }
            }

            Text(video.title).font(.headline)
            HStack {
                Text("Views: \(video.viewCount)")
                Spacer()
                Button("+1 View") { incrementViewCount() }
                    .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Comments").font(.headline)
                ForEach(video.comments) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.author).font(.subheadline).bold()
                        Text(c.text)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
                HStack {
                    TextField("Add a comment", text: $newComment)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") { addComment() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showBackConfirm = true
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
        .confirmTransition(isPresenting: $showBackConfirm, title: "Leave Video", message: "Go back to the list?", confirmTitle: "Back", cancelTitle: "Stay") {
            // Pop by setting an empty path via environment; here we rely on default back behavior
            // Workaround: use dismiss
            dismiss()
        }
        .onAppear { Task { await preparePlayer() } }
        .onChange(of: appState.privacyModeEnabled) { _ in Task { await preparePlayer() } }
        .onChange(of: video.url) { _ in Task { await preparePlayer() } }
        .onChange(of: newComment) { newValue in
            newComment = cleanUserText(newValue)
        }
        .alert("Cannot Play", isPresented: $isBlockingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(blockingMessage)
        }
    }

    @Environment(\.dismiss) private var dismiss

    private func preparePlayer() async {
        guard let original = video.url else { return }
        guard let sanitized = sanitizeAndValidateURL(original) else {
            await MainActor.run {
                blockingMessage = "Blocked potentially unsafe or non-video link."
                isBlockingAlert = true
                player = nil
            }
            return
        }
        do {
            let urlToPlay: URL
            if appState.privacyModeEnabled {
                urlToPlay = try await SecureVideoLoader.shared.fetchPlayableURL(from: sanitized)
            } else {
                urlToPlay = sanitized
            }
            await MainActor.run {
                player = AVPlayer(url: urlToPlay)
            }
        } catch {
            await MainActor.run {
                blockingMessage = "Blocked or failed to load video. \(error.localizedDescription)"
                isBlockingAlert = true
                player = nil
            }
        }
    }

    private func incrementViewCount() {
        if let index = appState.videos.firstIndex(where: { $0.id == video.id }) {
            if appState.videos[index].viewCount < Int.max {
                appState.videos[index].viewCount += 1
            }
            video.viewCount = appState.videos[index].viewCount
        }
    }

    private func addComment() {
        let cleaned = cleanUserText(newComment)
        guard !cleaned.isEmpty else { return }
        let comment = Comment(author: appState.isLoggedIn ? "You" : "Guest", text: cleaned)
        if let index = appState.videos.firstIndex(where: { $0.id == video.id }) {
            appState.videos[index].comments.append(comment)
            video.comments.append(comment)
        }
        newComment = ""
    }
}

struct UploadLink: View {
    @State private var showConfirm = false
    @State private var go = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up"); Text("Upload")
        }
        .onTapGesture { showConfirm = true }
        .background(
            NavigationLink("", destination: UploadView(), isActive: $go).opacity(0)
        )
        .confirmTransition(isPresenting: $showConfirm, title: "Upload Video", message: "Proceed to upload a video?", confirmTitle: "Proceed", cancelTitle: "Cancel") {
            go = true
        }
    }
}

struct UploadView: View {
    @StateObject private var uploader = CloudUploadService()
    @State private var pickedVideoData: Data? = nil
    @State private var title: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var showBackConfirm = false

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $title)
            }
            Section("Video") {
                Button {
                    // In a real app, present a PHPicker to pick a video file
                    // For now, simulate a small data blob
                    pickedVideoData = Data(repeating: 0xFF, count: 1024 * 1024)
                } label: {
                    Label(pickedVideoData == nil ? "Pick Video" : "Replace Video", systemImage: "film")
                }
            }
            Section("Upload") {
                switch uploader.state {
                case .idle:
                    Button("Upload to Cloud") {
                        guard let data = pickedVideoData else { return }
                        if data.count > Int(PrivacySettings.maxUploadBytes) {
                            uploader.state = .failure("File too large")
                            return
                        }
                        Task { await uploader.upload(data: data, fileName: (title.isEmpty ? "untitled" : title) + ".mp4") }
                    }
                    .disabled(pickedVideoData == nil)
                case .uploading(let progress):
                    ProgressView(value: progress) { Text("Uploading...") }
                case .success(let url):
                    Label("Uploaded: \(url.lastPathComponent)", systemImage: "checkmark.seal")
                        .foregroundStyle(.green)
                case .failure(let message):
                    Label("Failed: \(message)", systemImage: "xmark.octagon").foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Upload")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showBackConfirm = true } label: { Label("Back", systemImage: "chevron.left") }
            }
        }
        .confirmTransition(isPresenting: $showBackConfirm, title: "Cancel Upload", message: "Discard and go back?", confirmTitle: "Discard", cancelTitle: "Stay") {
            dismiss()
        }
    }
}

struct LoginLink: View {
    @EnvironmentObject var appState: AppState
    @State private var showConfirm = false
    @State private var go = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.crop.circle")
            Text(appState.isLoggedIn ? "Account" : "Login")
        }
        .onTapGesture { showConfirm = true }
        .background(
            NavigationLink("", destination: LoginView().environmentObject(appState), isActive: $go).opacity(0)
        )
        .confirmTransition(isPresenting: $showConfirm, title: appState.isLoggedIn ? "Open Account" : "Sign In", message: appState.isLoggedIn ? "Open account screen?" : "Go to sign-in screen?", confirmTitle: "Open", cancelTitle: "Cancel") {
            go = true
        }
    }
}

struct PrivacyToggle: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Menu {
            Toggle(isOn: $appState.privacyModeEnabled) {
                Label("Privacy Mode", systemImage: appState.privacyModeEnabled ? "lock.shield.fill" : "lock.shield")
            }
            Text("When enabled, the app downloads videos using an ephemeral session (no cookies), strips tracking parameters, and blocks non-video/advertising links.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } label: {
            Image(systemName: appState.privacyModeEnabled ? "lock.shield.fill" : "lock.shield")
        }
        .accessibilityLabel("Privacy Mode")
    }
}

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var username: String = ""
    @State private var password: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var showBackConfirm = false

    var body: some View {
        Form {
            Section("Account") {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .autocorrectionDisabled(true)
            }
            Section {
                Button(appState.isLoggedIn ? "Sign Out" : "Sign In") {
                    if appState.isLoggedIn {
                        appState.isLoggedIn = false
                    } else {
                        appState.isLoggedIn = true
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle(appState.isLoggedIn ? "Account" : "Login")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showBackConfirm = true } label: { Label("Back", systemImage: "chevron.left") }
            }
        }
        .confirmTransition(isPresenting: $showBackConfirm, title: "Leave", message: "Go back without changes?", confirmTitle: "Back", cancelTitle: "Stay") {
            dismiss()
        }
    }
}

#Preview {
    ContentView()
}

