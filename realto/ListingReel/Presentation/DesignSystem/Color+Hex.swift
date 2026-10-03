import SwiftUI

extension Color {
    /// SwiftUI convenience mirroring `PlatformColor(hex:)` used by the render tokens.
    init(hex: String) {
        #if os(iOS)
        self.init(uiColor: PlatformColor(hex: hex))
        #else
        self.init(nsColor: PlatformColor(hex: hex))
        #endif
    }
}

extension Image {
    /// SwiftUI convenience mirroring `Image(uiImage:)` / `Image(nsImage:)`.
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}
