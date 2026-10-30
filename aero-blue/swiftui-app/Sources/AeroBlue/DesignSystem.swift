import AppKit
import SwiftUI

enum AeroPalette {
    static let sky = Color(hex: 0xA8D8FF)
    static let crystal = Color(hex: 0x65C7F7)
    static let aqua = Color(hex: 0x48DCE6)
    static let ice = Color(hex: 0xF4FBFF)
    static let glass = Color(hex: 0xCDEEFF)
    static let leaf = Color(hex: 0x9AD96B)
    static let ocean = Color(hex: 0x2478B8)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct GlassPanel<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 22).fill(scheme == .dark ? Color(nsColor: .windowBackgroundColor) : AeroPalette.ice)
                } else {
                    RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(scheme == .dark ? 0.14 : 0.8), lineWidth: 1))
            .shadow(color: AeroPalette.ocean.opacity(0.07), radius: 14, x: 0, y: 6)
    }
}

struct SectionHeading: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 30, weight: .semibold, design: .rounded))
            Text(detail).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }
}

struct AssetImage: View {
    let url: URL?
    var contentMode: ContentMode = .fit
    var body: some View {
        if let url, let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: contentMode)
        } else {
            ZStack {
                AeroPalette.sky.opacity(0.25)
                Image(systemName: "photo").font(.title).foregroundStyle(.secondary)
            }
        }
    }
}

struct FeatureLine: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol).font(.title3).foregroundStyle(AeroPalette.ocean).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.semibold)
                Text(detail).foregroundStyle(.secondary).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CursorTestArea: NSViewRepresentable {
    let imageURL: URL?
    let hotspot: [Double]
    func makeNSView(context: Context) -> CursorSurface {
        let view = CursorSurface()
        view.setAccessibilityElement(true)
        view.setAccessibilityLabel("Cursor preview area")
        return view
    }
    func updateNSView(_ nsView: CursorSurface, context: Context) {
        if let imageURL, let image = NSImage(contentsOf: imageURL), hotspot.count == 2 {
            image.size = NSSize(width: 32, height: 32)
            nsView.themeCursor = NSCursor(image: image, hotSpot: NSPoint(x: hotspot[0], y: hotspot[1]))
        } else { nsView.themeCursor = .arrow }
        nsView.window?.invalidateCursorRects(for: nsView)
        nsView.needsDisplay = true
    }
}

final class CursorSurface: NSView {
    var themeCursor = NSCursor.arrow
    override var isFlipped: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: themeCursor) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16).fill()
        let text = "Move your pointer here to try this cursor"
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: style
        ]
        text.draw(in: NSRect(x: 12, y: bounds.midY - 10, width: bounds.width - 24, height: 30), withAttributes: attributes)
    }
}
