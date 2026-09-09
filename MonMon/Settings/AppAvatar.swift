import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum AppAvatar {
    static let storageKey = "profile.avatar"

    nonisolated static func normalizedData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 512,
                ] as CFDictionary
            )
        else { return nil }

        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(
            destination, image,
            [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

struct AvatarImage: View {
    @AppStorage(AppAvatar.storageKey) private var data = Data()
    @State private var image: CGImage?
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(MonMonTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
        .task(id: data) {
            image = CGImageSourceCreateWithData(data as CFData, nil).flatMap {
                CGImageSourceCreateImageAtIndex($0, 0, nil)
            }
        }
    }
}

struct AvatarSettingsContent: View {
    @AppStorage(AppAvatar.storageKey) private var data = Data()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoading = false
    @State private var hasLoadError = false

    var body: some View {
        HStack(spacing: 20) {
            AvatarImage(size: 72)
            VStack(alignment: .leading, spacing: 8) {
                Text("Avatar")
                    .font(.headline)
                    .foregroundStyle(MonMonTheme.textPrimary)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Text("Change avatar")
                }
                .disabled(isLoading)
                .accessibilityIdentifier("change-avatar")

                if isLoading {
                    ProgressView()
                        .accessibilityLabel("Loading avatar")
                } else if !data.isEmpty {
                    Button("Remove photo", role: .destructive) {
                        data = Data()
                    }
                    .accessibilityIdentifier("remove-avatar")
                }
            }
            Spacer(minLength: 0)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MonMonTheme.accent)
        .task(id: selectedPhoto) {
            guard let selectedPhoto else { return }
            isLoading = true
            defer {
                isLoading = false
                self.selectedPhoto = nil
            }
            do {
                guard let original = try await selectedPhoto.loadTransferable(type: Data.self)
                else { throw AvatarLoadError.invalidImage }
                let normalized = await Task.detached(priority: .userInitiated) {
                    AppAvatar.normalizedData(from: original)
                }.value
                try Task.checkCancellation()
                guard let normalized else { throw AvatarLoadError.invalidImage }
                data = normalized
            } catch {
                if !Task.isCancelled { hasLoadError = true }
            }
        }
        .alert("Could not load avatar", isPresented: $hasLoadError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose another photo or try again. Your current avatar has not changed.")
        }
    }

    private enum AvatarLoadError: Error {
        case invalidImage
    }
}
