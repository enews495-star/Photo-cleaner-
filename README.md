# Photo Cleaner

A simple iOS app (SwiftUI, iOS 17+) for tidying up your photo library, one photo at a time:

- **Swipe right** (or tap ♥) to **keep** a photo
- **Swipe left** (or tap ✕) to mark it for **deletion**
- **Undo** button to take back the last swipe

Nothing is deleted while you swipe. Tap the **trash** button (top right) to review everything you marked, tap any photo to rescue it, then delete them all at once. iOS asks you to confirm, and deleted photos stay in **Recently Deleted** for 30 days.

Photos you keep are remembered, so next time you open the app you only see photos you haven't reviewed yet. Use the **⋯** menu → *Show kept photos again* to start over.

## Running it on your iPhone

1. On a Mac, install **Xcode 16 or newer** from the App Store.
2. Open `PhotoCleaner.xcodeproj`.
3. Select the **PhotoCleaner** target → **Signing & Capabilities**:
   - Choose your **Team** (sign in with your Apple ID; a free account works).
   - Change the **Bundle Identifier** to something unique, e.g. `com.yourname.PhotoCleaner`.
4. Plug in your iPhone (or pick it from the device list if it's on the same Wi-Fi), select it as the run destination, and press **Run** (⌘R).
5. First time only, on the iPhone: enable **Settings → Privacy & Security → Developer Mode**, and trust your developer certificate under **Settings → General → VPN & Device Management**.

> With a free Apple ID, the app expires after 7 days and needs to be re-run from Xcode. A paid Apple Developer account removes that limit.

You can also try it in the iOS Simulator (drag some images into the simulator's Photos app first).

## Project layout

| File | What it does |
| --- | --- |
| `PhotoLibrary.swift` | Photo permissions, loading photos, keep/delete decisions, batch delete |
| `ContentView.swift` | Main screen: card stack, buttons, permission screens |
| `SwipeCardView.swift` | The draggable card with KEEP / DELETE stamps |
| `AssetImageView.swift` | Loads a photo (including from iCloud) at screen resolution |
| `ReviewDeletionsView.swift` | Grid of photos marked for deletion, with the final Delete button |
