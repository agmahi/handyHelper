import Foundation
import UIKit
import MWDATCore
import MWDATCamera
import Vision

// MARK: - CardMax Service

/// Shared service that handles the full detection + recommendation pipeline.
/// Used by both CardMaxViewModel (in-app) and WhichCardIntent (Siri).
@MainActor
class CardMaxService {
    static let shared = CardMaxService()

    let recommendationEngine = RecommendationEngine()

    // User's card portfolio (shared state)
    var userCards: [CreditCard] = CreditCard.presets

    // Meta SDK (lazily configured)
    private var wearables: WearablesInterface?
    private var streamSession: StreamSession?
    private var latestFrame: UIImage?
    private var videoFrameToken: AnyListenerToken?
    private var isCapturing = false

    private init() {}

    // MARK: - Configuration

    func configure(wearables: WearablesInterface) {
        guard self.wearables == nil else { return }
        self.wearables = wearables

        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: .high,
            frameRate: 10
        )
        let deviceSelector = AutoDeviceSelector(wearables: wearables)
        streamSession = StreamSession(
            streamSessionConfig: config,
            deviceSelector: deviceSelector
        )
    }

    /// Starts the frame listener only when actively capturing. Stops it after.
    private func startFrameListener() {
        guard videoFrameToken == nil else { return }
        isCapturing = true
        videoFrameToken = streamSession?.videoFramePublisher.listen { [weak self] videoFrame in
            Task { @MainActor [weak self] in
                guard let self, self.isCapturing else { return }
                if let image = videoFrame.makeUIImage() {
                    self.latestFrame = image
                }
            }
        }
    }

    private func stopFrameListener() {
        isCapturing = false
        videoFrameToken = nil
        latestFrame = nil
    }

    // MARK: - Full Detection + Recommendation

    /// Runs the full pipeline: camera capture -> OCR -> merchant match -> card recommendation.
    /// Returns a recommendation with a spoken response, or nil if detection fails.
    func detectAndRecommend() async -> CardRecommendation? {
        guard let merchant = await detectMerchantFromCamera() else {
            return nil
        }
        return recommendationEngine.recommend(for: merchant, from: userCards)
    }

    /// Recommends the best card for a given category (no camera needed).
    func recommendForCategory(_ category: MerchantCategory) -> CardRecommendation? {
        return recommendationEngine.recommend(forCategory: category, from: userCards)
    }

    // MARK: - Photo Capture (receipts)

    /// Captures a single photo via the glasses camera. Returns the image or nil.
    func capturePhoto() async -> UIImage? {
        guard let wearables, let session = streamSession else {
            print("CardMax: Service not configured")
            return nil
        }

        // Check camera permission
        do {
            let status = try await wearables.checkPermissionStatus(.camera)
            if status != .granted {
                let requested = try await wearables.requestPermission(.camera)
                guard requested == .granted else { return nil }
            }
        } catch {
            print("CardMax: Camera permission error - \(error)")
            return nil
        }

        // Listen for photo data before triggering capture
        return await withCheckedContinuation { continuation in
            var photoToken: AnyListenerToken?
            var didResume = false

            photoToken = session.photoDataPublisher.listen { photoData in
                Task { @MainActor in
                    guard !didResume else { return }
                    didResume = true
                    photoToken = nil
                    await session.stop()
                    let image = UIImage(data: photoData.data)
                    continuation.resume(returning: image)
                }
            }

            Task { @MainActor in
                await session.start()
                try? await Task.sleep(nanoseconds: 500_000_000)
                session.capturePhoto(format: .jpeg)

                // Timeout after 8 seconds
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !didResume else { return }
                didResume = true
                photoToken = nil
                await session.stop()
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Visual Merchant Detection

    func detectMerchantFromCamera() async -> Merchant? {
        guard let wearables, let session = streamSession else {
            print("CardMax: Service not configured")
            return nil
        }

        // Check camera permission
        do {
            let status = try await wearables.checkPermissionStatus(.camera)
            if status != .granted {
                let requestStatus = try await wearables.requestPermission(.camera)
                guard requestStatus == .granted else {
                    print("CardMax: Camera permission denied")
                    return nil
                }
            }
        } catch {
            print("CardMax: Camera permission error - \(error)")
            return nil
        }

        // Start stream and frame listener on-demand
        print("CardMax: Starting camera stream...")
        startFrameListener()
        await session.start()

        // Wait for stream to produce a frame (up to 8 seconds)
        let startTime = Date()
        while latestFrame == nil && Date().timeIntervalSince(startTime) < 8.0 {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        guard let capturedImage = latestFrame else {
            print("CardMax: No frame received after 8s")
            stopFrameListener()
            await session.stop()
            return nil
        }

        print("CardMax: Frame captured! (\(capturedImage.size.width)x\(capturedImage.size.height))")
        stopFrameListener()
        await session.stop()

        guard let cgImage = capturedImage.cgImage else {
            print("CardMax: Failed to get CGImage from UIImage")
            return nil
        }

        #if DEBUG
        UIImageWriteToSavedPhotosAlbum(capturedImage, nil, nil, nil)
        print("CardMax: Debug frame saved to Photos")
        #endif

        // Run OCR
        let detectedText = await recognizeText(in: cgImage)
        print("CardMax: OCR detected text: '\(detectedText)'")

        // Match merchant
        if let merchant = Merchant.findByKeyword(detectedText) {
            print("CardMax: Matched merchant by keyword: \(merchant.displayName)")
            return merchant
        }
        if let merchant = Merchant.findByDomain(detectedText) {
            print("CardMax: Matched merchant by domain: \(merchant.displayName)")
            return merchant
        }

        print("CardMax: No merchant match found in text")
        return nil
    }

    // MARK: - OCR

    func recognizeText(in cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
