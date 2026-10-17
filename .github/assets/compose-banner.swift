// Composes .github/assets/banner.png from a text-free background illustration
// (banner-background.png), exact text, and OpenRouter's official glyph
// (openrouter-glyph-volt@2x.png, unmodified, from https://openrouter.ai/brand).
//
//   swift .github/assets/compose-banner.swift .github/assets/banner-background.png \
//       .github/assets/openrouter-glyph-volt@2x.png .github/assets/banner.png
//
// Keep the code sample in sync with the public API.

import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 4,
    let background = NSImage(contentsOfFile: arguments[1]),
    let glyph = NSImage(contentsOfFile: arguments[2])
else {
    FileHandle.standardError.write(Data("usage: compose-banner.swift <background.png> <glyph.png> <out.png>\n".utf8))
    exit(1)
}

let width = 1280.0
let height = 640.0
guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    exit(1)
}
NSGraphicsContext.current = context

/// Converts top-left based coordinates (as used in the illustration brief) to AppKit's.
func rect(x: Double, y: Double, width rectWidth: Double, height rectHeight: Double) -> NSRect {
    NSRect(x: x, y: height - y - rectHeight, width: rectWidth, height: rectHeight)
}

func color(_ hex: UInt32, alpha: Double = 1) -> NSColor {
    NSColor(
        srgbRed: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255, alpha: alpha
    )
}

func draw(_ text: String, at point: NSPoint, font: NSFont, color: NSColor) {
    NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        .draw(at: NSPoint(x: point.x, y: height - point.y - font.ascender))
}

background.draw(in: NSRect(x: 0, y: 0, width: width, height: height))

// Title.
draw(
    "swift-openrouter", at: NSPoint(x: 64, y: 44),
    font: .systemFont(ofSize: 46, weight: .bold), color: color(0xF4F6FB)
)
draw(
    "Type-safe OpenRouter client for Swift · Apple platforms & Linux", at: NSPoint(x: 66, y: 104),
    font: .systemFont(ofSize: 19, weight: .regular), color: color(0xA9B1CC)
)

// Code inside the editor window (x 60…640, y 160…590).
let mono = NSFont.monospacedSystemFont(ofSize: 17, weight: .regular)
let keyword = color(0xFF7AB2)
let type = color(0x7AE7FF)
let call = color(0xC8FF00)
let string = color(0xFFA066)
let plain = color(0xE6E9F2)
let comment = color(0x6C7693)

let code: [[(String, NSColor)]] = [
    [("import", keyword), (" OpenRouter", plain)],
    [],
    [
        ("let", keyword), (" client = ", plain), ("try", keyword), (" OpenRouterClient", type),
        (".fromEnvironment()", plain),
    ],
    [("let", keyword), (" request = ", plain), ("ChatRequest", type), ("(", plain)],
    [("    messages: [.", plain), ("user", call), ("(", plain), ("\"Hello!\"", string), (")],", plain)],
    [("    model: ", plain), ("\"anthropic/claude-sonnet-4\"", string)],
    [(")", plain)],
    [],
    [("for", keyword), (" try await", keyword), (" chunk ", plain), ("in", keyword)],
    [("    try await", keyword), (" client.chat.", plain), ("stream", call), ("(request) {", plain)],
    [
        ("    print", call), ("(chunk.textDelta ?? ", plain), ("\"\"", string), (", terminator: ", plain),
        ("\"\"", string), (")", plain),
    ],
    [("}", plain)],
    [],
    [("// streamed tokens, any model, one API", comment)],
]
var lineY = 204.0
for line in code {
    var x = 92.0
    for (text, tint) in line {
        draw(text, at: NSPoint(x: x, y: lineY), font: mono, color: tint)
        x += NSAttributedString(string: text, attributes: [.font: mono]).size().width
    }
    lineY += 24.5
}

// Official glyph, unmodified apart from uniform scaling, centered in the hub
// (the hub sits at (838, 323) in banner-background.png).
let glyphWidth = 104.0
let glyphHeight = glyphWidth * glyph.size.height / glyph.size.width
glyph.draw(in: rect(x: 838 - glyphWidth / 2, y: 323 - glyphHeight / 2, width: glyphWidth, height: glyphHeight))

NSGraphicsContext.current = nil
guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(filePath: arguments[3]))
print("wrote \(arguments[3])")
