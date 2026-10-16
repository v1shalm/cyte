import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LiquidLayer<Blobs: View>: View {
    var blur: CGFloat = 7
    var threshold: Double = 0.5
    var softness: Double = 0.06
    var fill: Color = Theme.ink
    var shadow: Bool = true
    @ViewBuilder var blobs: () -> Blobs

    var body: some View {
        blobs()
            .padding(blur * 3)
            .blur(radius: blur)
            .layerEffect(
                ShaderLibrary.goo(.float(Float(threshold)), .float(Float(softness)), .color(fill)),
                maxSampleOffset: .zero
            )
            .padding(-blur * 3)
            .shadow(color: .black.opacity(shadow ? 0.16 : 0), radius: 12, y: 6)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension Animation {
    static var liquid: Animation { .spring(duration: 0.55, bounce: 0.32) }
    static var liquidQuick: Animation { .spring(duration: 0.34, bounce: 0.18) }
}
