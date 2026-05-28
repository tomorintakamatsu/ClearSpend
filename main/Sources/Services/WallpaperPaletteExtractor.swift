import SwiftUI
import UIKit

struct WallpaperPalette: Codable, Equatable, Sendable {
    var primaryHex: String
    var accentHex: String
    var backgroundHex: String

    var primaryColor: Color { Color(hex: primaryHex) }
    var accentColor: Color { Color(hex: accentHex) }
    var backgroundColor: Color { Color(hex: backgroundHex) }
}

enum WallpaperPaletteError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "Could not read that image. Try another wallpaper."
    }
}

enum WallpaperPaletteExtractor {
    static func prepareWallpaper(from data: Data) throws -> (imageData: Data, palette: WallpaperPalette) {
        guard let image = UIImage(data: data) else {
            throw WallpaperPaletteError.invalidImage
        }

        let displayImage = resized(image, maxDimension: 1400)
        let palette = extractPalette(from: displayImage)
        let imageData = displayImage.jpegData(compressionQuality: 0.84) ?? data

        return (imageData, palette)
    }

    private static func extractPalette(from image: UIImage) -> WallpaperPalette {
        let samples = colorSamples(from: image)
        guard !samples.isEmpty else {
            return WallpaperPalette(primaryHex: "0d9488", accentHex: "5eead4", backgroundHex: "f4f7f7")
        }

        let candidates = rankedCandidates(from: samples)
        let primary = candidates.first(where: { $0.saturation > 0.22 && $0.brightness > 0.18 }) ?? candidates[0]
        let accent = candidates.first {
            hueDistance($0.hue, primary.hue) > 0.10 && $0.saturation > 0.18
        } ?? adjustedAccent(from: primary)
        let average = averageColor(from: samples)

        return WallpaperPalette(
            primaryHex: adjustedColor(primary, saturation: 0.62...0.90, brightness: 0.42...0.68).hexString,
            accentHex: adjustedColor(accent, saturation: 0.42...0.74, brightness: 0.68...0.88).hexString,
            backgroundHex: adjustedColor(average, saturation: 0.10...0.28, brightness: 0.90...0.97).hexString
        )
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private static func colorSamples(from image: UIImage) -> [PaletteColor] {
        let sampleSize = CGSize(width: 72, height: 72)
        guard let cgImage = resized(image, maxDimension: 72).cgImage else { return [] }

        let width = Int(sampleSize.width)
        let height = Int(sampleSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(origin: .zero, size: sampleSize))

        return stride(from: 0, to: pixels.count, by: bytesPerPixel).compactMap { index in
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.85 else { return nil }

            return PaletteColor(
                red: Double(pixels[index]) / 255,
                green: Double(pixels[index + 1]) / 255,
                blue: Double(pixels[index + 2]) / 255,
                count: 1
            )
        }
    }

    private static func rankedCandidates(from samples: [PaletteColor]) -> [PaletteColor] {
        var buckets: [Int: PaletteBucket] = [:]

        for sample in samples {
            let r = Int((sample.red * 7).rounded())
            let g = Int((sample.green * 7).rounded())
            let b = Int((sample.blue * 7).rounded())
            let key = (r << 6) | (g << 3) | b
            buckets[key, default: PaletteBucket()].add(sample)
        }

        let candidates = buckets.values.map(\.average).filter { color in
            color.brightness > 0.08 && color.brightness < 0.96
        }

        return candidates.sorted { left, right in
            score(left) > score(right)
        }
    }

    private static func averageColor(from samples: [PaletteColor]) -> PaletteColor {
        let bucket = samples.reduce(into: PaletteBucket()) { partial, color in
            partial.add(color)
        }
        return bucket.average
    }

    private static func score(_ color: PaletteColor) -> Double {
        let brightnessFit = 1 - abs(color.brightness - 0.58)
        return Double(color.count) * (0.35 + color.saturation) * max(0.25, brightnessFit)
    }

    private static func adjustedColor(
        _ color: PaletteColor,
        saturation saturationRange: ClosedRange<Double>,
        brightness brightnessRange: ClosedRange<Double>
    ) -> PaletteColor {
        PaletteColor(
            hue: color.hue,
            saturation: min(max(color.saturation, saturationRange.lowerBound), saturationRange.upperBound),
            brightness: min(max(color.brightness, brightnessRange.lowerBound), brightnessRange.upperBound),
            count: color.count
        )
    }

    private static func adjustedAccent(from color: PaletteColor) -> PaletteColor {
        PaletteColor(
            hue: color.hue + 0.08 > 1 ? color.hue - 0.18 : color.hue + 0.18,
            saturation: max(color.saturation, 0.46),
            brightness: max(color.brightness, 0.72),
            count: color.count
        )
    }

    private static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let distance = abs(a - b)
        return min(distance, 1 - distance)
    }
}

private struct PaletteBucket {
    var red: Double = 0
    var green: Double = 0
    var blue: Double = 0
    var count: Int = 0

    mutating func add(_ color: PaletteColor) {
        red += color.red
        green += color.green
        blue += color.blue
        count += color.count
    }

    var average: PaletteColor {
        guard count > 0 else {
            return PaletteColor(red: 0.05, green: 0.58, blue: 0.53, count: 1)
        }
        return PaletteColor(red: red / Double(count), green: green / Double(count), blue: blue / Double(count), count: count)
    }
}

private struct PaletteColor {
    var red: Double
    var green: Double
    var blue: Double
    var count: Int

    init(red: Double, green: Double, blue: Double, count: Int) {
        self.red = red
        self.green = green
        self.blue = blue
        self.count = count
    }

    init(hue: Double, saturation: Double, brightness: Double, count: Int) {
        let color = UIColor(hue: CGFloat(hue), saturation: CGFloat(saturation), brightness: CGFloat(brightness), alpha: 1)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)

        self.red = Double(red)
        self.green = Double(green)
        self.blue = Double(blue)
        self.count = count
    }

    var hue: Double {
        hsba.hue
    }

    var saturation: Double {
        hsba.saturation
    }

    var brightness: Double {
        hsba.brightness
    }

    var hexString: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "%02x%02x%02x", r, g, b)
    }

    private var hsba: (hue: Double, saturation: Double, brightness: Double) {
        let color = UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        return (Double(hue), Double(saturation), Double(brightness))
    }
}
