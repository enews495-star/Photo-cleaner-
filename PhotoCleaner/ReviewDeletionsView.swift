import Photos
import SwiftUI

/// Grid of every photo marked for deletion. Tap a photo to un-mark it,
/// then delete the rest in one batch.
struct ReviewDeletionsView: View {
    @Environment(PhotoLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss

    @State private var isDeleting = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        NavigationStack {
            Group {
                if library.markedForDeletion.isEmpty {
                    ContentUnavailableView(
                        "Nothing to delete",
                        systemImage: "trash.slash",
                        description: Text("Swipe left on photos to mark them for deletion.")
                    )
                } else {
                    ScrollView {
                        Text("Tap a photo to keep it instead.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(library.markedForDeletion, id: \.localIdentifier) { asset in
                                Button {
                                    withAnimation { library.unmark(asset) }
                                } label: {
                                    AssetImageView(asset: asset, contentMode: .fill)
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipped()
                                        .overlay(alignment: .topTrailing) {
                                            Image(systemName: "trash.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .red)
                                                .font(.title3)
                                                .padding(4)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Keep this photo instead")
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .navigationTitle("\(library.markedForDeletion.count) to delete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !library.markedForDeletion.isEmpty {
                    Button(role: .destructive) {
                        Task { await deleteAll() }
                    } label: {
                        Group {
                            if isDeleting {
                                ProgressView()
                            } else {
                                Text("Delete \(library.markedForDeletion.count) Photos")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .disabled(isDeleting)
                    .padding()
                    .background(.bar)
                }
            }
            .alert("Couldn't delete photos", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func deleteAll() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            if try await library.deleteMarked() {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
