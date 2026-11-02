// Headless icon export using Core Graphics. No AppKit drawing context required.
import Foundation
import CoreGraphics
import ImageIO

struct IconManifest: Decodable {
  struct Icon: Decodable {
    let size: String
    let scale: String
    let filename: String
  }
  let images: [Icon]
}

struct BrandingError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

func exportIcons() throws {
  let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  let sourceURL = root.appendingPathComponent("assets/branding/app_logo.png")
  guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
        let logo = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    throw BrandingError(message: "Cannot read assets/branding/app_logo.png. Upload this asset before building.")
  }
  let directory = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
  let manifest = try JSONDecoder().decode(IconManifest.self,
    from: Data(contentsOf: directory.appendingPathComponent("Contents.json")))
  guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    throw BrandingError(message: "Cannot create sRGB color space.")
  }
  for icon in manifest.images {
    guard let sizeText = icon.size.split(separator: "x").first,
          let size = Double(sizeText), let scale = Double(icon.scale.dropLast()),
          size.isFinite, scale.isFinite, size > 0, scale > 0,
          size * scale <= 4096,
          !icon.filename.contains("/"), !icon.filename.contains("..") else {
      throw BrandingError(message: "Invalid icon specification: \(icon.filename)")
    }
    let pixels = Int((size * scale).rounded())
    // Four bytes per pixel with an unused alpha byte: supported by bitmap
    // contexts while producing an opaque image for App Store validation.
    guard let context = CGContext(data: nil, width: pixels, height: pixels,
      bitsPerComponent: 8, bytesPerRow: pixels * 4, space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
      throw BrandingError(message: "Cannot allocate icon canvas: \(pixels) pixels.")
    }
    let canvas = CGFloat(pixels)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
    context.interpolationQuality = .high
    let ratio = min(canvas * 0.86 / CGFloat(logo.width), canvas * 0.86 / CGFloat(logo.height))
    let width = CGFloat(logo.width) * ratio
    let height = CGFloat(logo.height) * ratio
    context.draw(logo, in: CGRect(x: (canvas - width) / 2,
      y: (canvas - height) / 2, width: width, height: height))
    let outputURL = directory.appendingPathComponent(icon.filename)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil) else {
      throw BrandingError(message: "Cannot create PNG: \(icon.filename)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination),
          let checkSource = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
          let check = CGImageSourceCreateImageAtIndex(checkSource, 0, nil),
          check.width == pixels, check.height == pixels,
          [.none, .noneSkipFirst, .noneSkipLast].contains(check.alphaInfo) else {
      throw BrandingError(message: "PNG dimensions or opacity validation failed: \(icon.filename)")
    }
  }
  print("App icons exported and verified without transparency.")
}

do {
  try exportIcons()
} catch {
  FileHandle.standardError.write(Data("Branding export failed: \(error.localizedDescription)\n".utf8))
  exit(1)
}
