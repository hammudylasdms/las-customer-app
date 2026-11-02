// Export the existing LAS logo into Apple's required opaque icon sizes.
// Run from the repository root on the macOS build runner.
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
guard let logo = NSImage(contentsOf: root.appendingPathComponent("assets/branding/app_logo.png")) else {
  fatalError("LAS branding asset is missing")
}
let directory = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("Contents.json"))) as! [String: Any]
for item in manifest["images"] as! [[String: String]] {
  let size = Double(item["size"]!.split(separator: "x")[0])!
  let scale = Double(item["scale"]!.dropLast())!
  let pixels = Int(size * scale)
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
    bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  let context = NSGraphicsContext(bitmapImageRep: bitmap)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  context.imageInterpolation = .high
  NSColor.white.setFill()
  let canvas: CGFloat = CGFloat(pixels)
  NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()
  let width: CGFloat = canvas * 0.86
  let height: CGFloat = width * logo.size.height / logo.size.width
  logo.draw(in: NSRect(x: (canvas - width) / 2,
                      y: (canvas - height) / 2,
                      width: width, height: height))
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using: .png, properties: [:])!.write(
    to: directory.appendingPathComponent(item["filename"]!))
}
print("LAS app icons exported without alpha.")
