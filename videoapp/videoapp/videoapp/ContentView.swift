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
        // Simulate a remote URL after uploading
        let url = URL(string: "https://example-bucket.s3.amazonaws.com/\(fileName)")!
        self.state = .success(url)
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

struct VideoCardView: View {
    let video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let thumb = video.thumbnailURL {
                        AsyncImage(url: thumb) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure(_):
                                placeholder
                            case .empty:
                                placeholder.redacted(reason: .placeholder)
                            @unknown default:
                                placeholder
                            }
                        }
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

    @State private var newComment: String = ""
    @State private var showBackConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            if let url = video.url {
                VideoPlayer(player: AVPlayer(url: url))
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
    }

    @Environment(\.dismiss) private var dismiss

    private func incrementViewCount() {
        if let index = appState.videos.firstIndex(where: { $0.id == video.id }) {
            appState.videos[index].viewCount += 1
            video.viewCount = appState.videos[index].viewCount
        }
    }

    private func addComment() {
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = Comment(author: appState.isLoggedIn ? "You" : "Guest", text: trimmed)
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
                SecureField("Password", text: $password)
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

