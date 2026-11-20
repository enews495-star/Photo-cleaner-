import Photos
import SwiftUI

struct ContentView: View {
    @Environment(PhotoLibrary.self) private var library

    var body: some View {
        NavigationStack {
            Group {
                switch library.authorization {
                case .authorized, .limited:
                    SwipeScreen()
                case .notDetermined:
                    PermissionPrompt()
                default:
                    AccessDeniedView()
                }
            }
            .navigationTitle("Photo Cleaner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Main swipe screen

private struct SwipeScreen: View {
    @Environment(PhotoLibrary.self) private var library

    @State private var programmaticSwipe: SwipeAction?
    @State private var showingReview = false

    var body: some View {
        VStack(spacing: 16) {
            header

            ZStack {
                if library.isLoading {
                    ProgressView("Loading photos…")
                } else if let current = library.currentAsset {
                    if let next = library.nextAsset {
                        AssetImageView(asset: next)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .scaleEffect(0.95)
                            .opacity(0.6)
                            .allowsHitTesting(false)
                    }
                    SwipeCardView(asset: current, programmaticSwipe: $programmaticSwipe) { action in
                        library.decide(action)
                    }
                    .id(current.localIdentifier)
                } else {
                    DoneView(showingReview: $showingReview)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)

            controls
        }
        .padding(.bottom)
        .sensoryFeedback(.impact(weight: .light), trigger: library.history.count)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingReview = true
                } label: {
                    Label("Review deletions", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(library.markedForDeletion.isEmpty)
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Reload library", systemImage: "arrow.clockwise") {
                        library.loadAssets()
                    }
                    Button("Show kept photos again", systemImage: "arrow.counterclockwise", role: .destructive) {
                        library.startOver()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingReview) {
            ReviewDeletionsView()
        }
    }

    private var header: some View {
        HStack {
            Text("\(library.remainingCount) left")
            Spacer()
            Text("\(library.markedForDeletion.count) to delete")
                .foregroundStyle(.red)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    private var controls: some View {
        HStack(spacing: 32) {
            circleButton("xmark", color: .red, label: "Delete") {
                programmaticSwipe = .delete
            }
            .disabled(library.currentAsset == nil)

            circleButton("arrow.uturn.backward", color: .gray, label: "Undo", size: 48) {
                withAnimation { library.undo() }
            }
            .disabled(!library.canUndo)

            circleButton("heart.fill", color: .green, label: "Keep") {
                programmaticSwipe = .keep
            }
            .disabled(library.currentAsset == nil)
        }
    }

    private func circleButton(
        _ systemImage: String,
        color: Color,
        label: String,
        size: CGFloat = 64,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Circle().fill(Color(.secondarySystemBackground)))
                .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Finished

private struct DoneView: View {
    @Environment(PhotoLibrary.self) private var library
    @Binding var showingReview: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("All caught up!")
                .font(.title2.bold())
            Text("You kept \(library.keptThisSessionCount) and marked \(library.markedForDeletion.count) for deletion.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if !library.markedForDeletion.isEmpty {
                Button("Review & delete \(library.markedForDeletion.count) photos") {
                    showingReview = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
    }
}

// MARK: - Permissions

private struct PermissionPrompt: View {
    @Environment(PhotoLibrary.self) private var library

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Clean up your photos")
                .font(.title.bold())
            Text("Swipe right to keep a photo, left to delete it. Nothing is deleted until you confirm, and deleted photos stay in Recently Deleted for 30 days.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Allow Photo Access") {
                Task { await library.requestAccess() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
    }
}

private struct AccessDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label("No Photo Access", systemImage: "lock.circle")
        } description: {
            Text("Photo Cleaner needs access to your photo library. You can turn it on in Settings.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
