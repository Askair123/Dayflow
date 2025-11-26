//
//  FrameDifferenceDetector.swift
//  Dayflow
//
//  Intelligent frame difference detection to skip redundant frames
//

import Foundation
import CoreVideo
import CommonCrypto
import Accelerate

/// Configuration for frame difference detection
struct FrameDifferenceConfig {
    let enabled: Bool
    let algorithm: Algorithm
    let threshold: Double

    enum Algorithm {
        case exactHash      // MD5 hash comparison (fastest, exact match only)
        case perceptualHash // Perceptual hash (detects similar frames)
        case pixelDiff      // Direct pixel comparison (most accurate)
    }

    static let `default` = FrameDifferenceConfig(
        enabled: true,
        algorithm: .exactHash,
        threshold: 0.02  // 2% difference threshold for pixelDiff
    )

    static let disabled = FrameDifferenceConfig(
        enabled: false,
        algorithm: .exactHash,
        threshold: 0.0
    )
}

/// Statistics for frame detection
struct FrameDetectionStats {
    var totalFrames: Int = 0
    var uniqueFrames: Int = 0
    var skippedFrames: Int = 0

    var skipRate: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(skippedFrames) / Double(totalFrames)
    }

    mutating func recordFrame(wasSkipped: Bool) {
        totalFrames += 1
        if wasSkipped {
            skippedFrames += 1
        } else {
            uniqueFrames += 1
        }
    }

    mutating func reset() {
        totalFrames = 0
        uniqueFrames = 0
        skippedFrames = 0
    }
}

/// Detects differences between consecutive video frames to skip redundant recordings
final class FrameDifferenceDetector {

    private let config: FrameDifferenceConfig
    private(set) var stats = FrameDetectionStats()

    // State for different algorithms
    private var lastFrameHash: String?
    private var lastFrameSignature: [UInt8]?

    init(config: FrameDifferenceConfig = .default) {
        self.config = config
    }

    /// Determines if a frame should be recorded based on difference from previous frame
    /// - Parameter pixelBuffer: The current frame's pixel buffer
    /// - Returns: true if frame should be recorded, false if it should be skipped
    func shouldRecordFrame(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard config.enabled else {
            stats.recordFrame(wasSkipped: false)
            return true
        }

        let shouldRecord: Bool

        switch config.algorithm {
        case .exactHash:
            shouldRecord = shouldRecordUsingExactHash(pixelBuffer)
        case .perceptualHash:
            shouldRecord = shouldRecordUsingPerceptualHash(pixelBuffer)
        case .pixelDiff:
            shouldRecord = shouldRecordUsingPixelDiff(pixelBuffer)
        }

        stats.recordFrame(wasSkipped: !shouldRecord)
        return shouldRecord
    }

    // MARK: - Algorithm Implementations

    /// Fastest: Exact hash comparison using MD5
    private func shouldRecordUsingExactHash(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard let currentHash = computeMD5Hash(pixelBuffer) else {
            return true // If hash fails, record the frame
        }

        defer { lastFrameHash = currentHash }

        // First frame is always recorded
        guard let previousHash = lastFrameHash else {
            return true
        }

        // Only record if hashes differ (exact change detection)
        return currentHash != previousHash
    }

    /// Medium: Perceptual hash for detecting similar frames
    private func shouldRecordUsingPerceptualHash(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard let currentSignature = computePerceptualHash(pixelBuffer) else {
            return true
        }

        defer { lastFrameSignature = currentSignature }

        guard let previousSignature = lastFrameSignature else {
            return true
        }

        // Calculate Hamming distance
        let distance = hammingDistance(currentSignature, previousSignature)
        let maxDistance = currentSignature.count * 8 // bits
        let similarity = 1.0 - (Double(distance) / Double(maxDistance))

        // Record if frames are sufficiently different
        return similarity < (1.0 - config.threshold)
    }

    /// Most accurate: Direct pixel comparison
    private func shouldRecordUsingPixelDiff(_ pixelBuffer: CVPixelBuffer) -> Bool {
        // Not implemented in initial version due to complexity
        // Falls back to exact hash
        return shouldRecordUsingExactHash(pixelBuffer)
    }

    // MARK: - Hash Computation

    /// Computes MD5 hash of pixel buffer
    private func computeMD5Hash(_ pixelBuffer: CVPixelBuffer) -> String? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let dataSize = bytesPerRow * height

        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))

        CC_MD5(baseAddress, CC_LONG(dataSize), &digest)

        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    /// Computes perceptual hash (simplified pHash)
    /// This creates a compact signature that's resilient to minor changes
    private func computePerceptualHash(_ pixelBuffer: CVPixelBuffer) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        // Sample a small grid (8x8) for perceptual hash
        let gridSize = 8
        var samples = [UInt8]()
        samples.reserveCapacity(gridSize * gridSize)

        let xStep = width / gridSize
        let yStep = height / gridSize

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let pixelX = x * xStep
                let pixelY = y * yStep
                let offset = pixelY * bytesPerRow + pixelX * 4

                if offset + 2 < bytesPerRow * height {
                    let ptr = baseAddress.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                    // Average RGB to get grayscale (simplified)
                    let gray = (UInt16(ptr[0]) + UInt16(ptr[1]) + UInt16(ptr[2])) / 3
                    samples.append(UInt8(gray))
                }
            }
        }

        // Compute average
        let avg = samples.reduce(0, +) / samples.count

        // Create binary signature based on average
        var signature = [UInt8]()
        var byte: UInt8 = 0
        var bitPos = 0

        for sample in samples {
            if sample >= avg {
                byte |= (1 << bitPos)
            }
            bitPos += 1

            if bitPos == 8 {
                signature.append(byte)
                byte = 0
                bitPos = 0
            }
        }

        if bitPos > 0 {
            signature.append(byte)
        }

        return signature
    }

    /// Calculates Hamming distance between two byte arrays
    private func hammingDistance(_ a: [UInt8], _ b: [UInt8]) -> Int {
        guard a.count == b.count else { return Int.max }

        var distance = 0
        for i in 0..<a.count {
            var xor = a[i] ^ b[i]
            while xor != 0 {
                distance += Int(xor & 1)
                xor >>= 1
            }
        }
        return distance
    }

    // MARK: - Statistics

    /// Resets detection statistics
    func resetStats() {
        stats.reset()
    }

    /// Returns current statistics
    func getStats() -> FrameDetectionStats {
        return stats
    }
}

// MARK: - UserDefaults Extension for Config

extension FrameDifferenceConfig {
    private static let enabledKey = "frameDifferenceEnabled"
    private static let algorithmKey = "frameDifferenceAlgorithm"
    private static let thresholdKey = "frameDifferenceThreshold"

    static func load() -> FrameDifferenceConfig {
        let defaults = UserDefaults.standard

        let enabled = defaults.object(forKey: enabledKey) as? Bool ?? true
        let algorithmRaw = defaults.string(forKey: algorithmKey) ?? "exactHash"
        let threshold = defaults.double(forKey: thresholdKey)

        let algorithm: Algorithm
        switch algorithmRaw {
        case "exactHash": algorithm = .exactHash
        case "perceptualHash": algorithm = .perceptualHash
        case "pixelDiff": algorithm = .pixelDiff
        default: algorithm = .exactHash
        }

        return FrameDifferenceConfig(
            enabled: enabled,
            algorithm: algorithm,
            threshold: threshold > 0 ? threshold : 0.02
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: Self.enabledKey)

        let algorithmRaw: String
        switch algorithm {
        case .exactHash: algorithmRaw = "exactHash"
        case .perceptualHash: algorithmRaw = "perceptualHash"
        case .pixelDiff: algorithmRaw = "pixelDiff"
        }
        defaults.set(algorithmRaw, forKey: Self.algorithmKey)
        defaults.set(threshold, forKey: Self.thresholdKey)
    }
}
