import AppKit

/// Custom-drawn menu bar icons: a five-bar voice waveform. Template images,
/// so they adapt to light/dark menu bars and can be tinted (red = recording).
enum MenuBarIcon {
    static let size = NSSize(width: 18, height: 18)
    private static let idleHeights: [CGFloat] = [0.35, 0.7, 1.0, 0.55, 0.3]

    static let idle = waveform(heights: idleHeights)
    static let loading = waveform(heights: idleHeights, alpha: 0.35)
    static let transcribingBright = waveform(heights: [0.5, 0.5, 0.5, 0.5, 0.5], alpha: 0.9)
    static let transcribingDim = waveform(heights: [0.5, 0.5, 0.5, 0.5, 0.5], alpha: 0.4)

    /// Recording icon; bars dance with the current mic level (0…1).
    static func recording(level: CGFloat) -> NSImage {
        let base: [CGFloat] = [0.45, 0.75, 1.0, 0.65, 0.5]
        let energy = 0.25 + min(1.0, max(0, level)) * 0.75
        let heights: [CGFloat] = base.map { min(1.0, $0 * energy * CGFloat.random(in: 0.8...1.2)) }
        return waveform(heights: heights)
    }

    static let error: NSImage = {
        let image = NSImage(size: size, flipped: false) { rect in
            drawBars(in: rect, heights: idleHeights, alpha: 0.45)
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 3, y: 2.5))
            slash.line(to: NSPoint(x: rect.width - 3, y: rect.height - 2.5))
            slash.lineWidth = 1.8
            slash.lineCapStyle = .round
            NSColor.black.setStroke()
            slash.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()

    private static func waveform(heights: [CGFloat], alpha: CGFloat = 1.0) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            drawBars(in: rect, heights: heights, alpha: alpha)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawBars(in rect: NSRect, heights: [CGFloat], alpha: CGFloat) {
        let barWidth: CGFloat = 2.2
        let gap: CGFloat = 1.5
        let count = CGFloat(heights.count)
        let totalWidth = count * barWidth + (count - 1) * gap
        var x = (rect.width - totalWidth) / 2
        let maxHeight: CGFloat = 13
        NSColor.black.withAlphaComponent(alpha).setFill()
        for height in heights {
            let barHeight = max(3, maxHeight * height)
            let y = (rect.height - barHeight) / 2
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barWidth, height: barHeight),
                         xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
            x += barWidth + gap
        }
    }
}
