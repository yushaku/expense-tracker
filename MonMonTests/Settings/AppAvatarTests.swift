import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import MonMon

struct AppAvatarTests {
    @Test("Invalid image data is rejected")
    func invalidImage() {
        #expect(AppAvatar.normalizedData(from: Data("invalid".utf8)) == nil)
    }

    @Test("Large photos are reduced while preserving their aspect ratio")
    func downsample() throws {
        let data = try sourceImage(orientation: 1)
        let result = try #require(AppAvatar.normalizedData(from: data))
        let source = try #require(CGImageSourceCreateWithData(result as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 512)
        #expect(image.height == 256)
        #expect(result.count < 200_000)
    }

    @Test("Photo orientation is baked into the saved avatar")
    func orientation() throws {
        let data = try sourceImage(orientation: 6)
        let result = try #require(AppAvatar.normalizedData(from: data))
        let source = try #require(CGImageSourceCreateWithData(result as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 256)
        #expect(image.height == 512)
    }

    private func sourceImage(orientation: Int) throws -> Data {
        let context = try #require(
            CGContext(
                data: nil, width: 1200, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(
            destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
