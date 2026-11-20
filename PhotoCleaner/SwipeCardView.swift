import Photos
import SwiftUI

/// A draggable photo card. Drag right to keep, left to delete.
struct SwipeCardView: View {
    let asset: PHAsset
    /// Set from outside (the Keep / Delete buttons) to fling the card programmatically.
    @Binding var programmaticSwipe: SwipeAction?
    let onSwipe: (SwipeAction) -> Void

    @State private var offset: CGSize = .zero
    @State private var isFlying = false

    private let swipeThreshold: CGFloat = 110

    var body: some View {
        AssetImageView(asset: asset)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .topLeading) {
                stamp("KEEP", color: .green)
                    .rotationEffect(.degrees(-15))
                    .padding(28)
                    .opacity(Double(max(offset.width, 0) / swipeThreshold))
            }
            .overlay(alignment: .topTrailing) {
                stamp("DELETE", color: .red)
                    .rotationEffect(.degrees(15))
                    .padding(28)
                    .opacity(Double(max(-offset.width, 0) / swipeThreshold))
            }
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width / 20)), anchor: .bottom)
            .gesture(drag)
            .onChange(of: programmaticSwipe) { _, action in
                guard let action else { return }
                programmaticSwipe = nil
                fling(action)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Photo")
            .accessibilityHint("Swipe right to keep, left to delete")
            .accessibilityAction(named: "Keep") { fling(.keep) }
            .accessibilityAction(named: "Delete") { fling(.delete) }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isFlying else { return }
                offset = value.translation
            }
            .onEnded { value in
                guard !isFlying else { return }
                let dx = value.translation.width
                let predicted = value.predictedEndTranslation.width
                if dx > swipeThreshold || predicted > swipeThreshold * 3 {
                    fling(.keep)
                } else if dx < -swipeThreshold || predicted < -swipeThreshold * 3 {
                    fling(.delete)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        offset = .zero
                    }
                }
            }
    }

    private func fling(_ action: SwipeAction) {
        guard !isFlying else { return }
        isFlying = true
        let direction: CGFloat = action == .keep ? 1 : -1
        withAnimation(.easeOut(duration: 0.22)) {
            offset = CGSize(width: direction * 700, height: offset.height + 40)
        } completion: {
            onSwipe(action)
        }
    }

    private func stamp(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 4)
            )
    }
}
