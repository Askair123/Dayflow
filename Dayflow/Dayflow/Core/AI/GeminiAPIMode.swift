//
//  GeminiAPIMode.swift
//  Dayflow
//
//  API mode configuration for Gemini API usage
//

import Foundation

/// Gemini API operation mode
enum GeminiAPIMode: String, Codable, CaseIterable {
    case realtime  // Files API - immediate processing
    case batch     // Batch API - delayed but cheaper (50% cost)
    case smart     // Intelligent hybrid - realtime during work hours, batch otherwise

    var displayName: String {
        switch self {
        case .realtime: return "Realtime"
        case .batch: return "Batch"
        case .smart: return "Smart Mix"
        }
    }

    var description: String {
        switch self {
        case .realtime:
            return "Process immediately using Files API. Cards generated within 1-2 minutes. Standard cost."
        case .batch:
            return "Process using Batch API. Cards generated within 5-30 minutes. 50% cost savings."
        case .smart:
            return "Automatic: Uses realtime during work hours (8am-8pm), batch otherwise. Balanced speed & cost."
        }
    }

    var estimatedDelay: String {
        switch self {
        case .realtime: return "1-2 minutes"
        case .batch: return "5-30 minutes"
        case .smart: return "Variable"
        }
    }

    var costMultiplier: Double {
        switch self {
        case .realtime: return 1.0
        case .batch: return 0.5  // 50% cheaper
        case .smart: return 0.7  // ~30% savings (assuming 60% batch usage)
        }
    }

    /// Determines if should use batch API based on mode and context
    func shouldUseBatch(currentTime: Date = Date()) -> Bool {
        switch self {
        case .realtime:
            return false
        case .batch:
            return true
        case .smart:
            // Smart mode: use batch outside work hours (8am-8pm)
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: currentTime)
            let isWorkHours = hour >= 8 && hour < 20
            return !isWorkHours
        }
    }
}

/// Configuration persistence
extension GeminiAPIMode {
    private static let storageKey = "geminiAPIMode"

    static func load() -> GeminiAPIMode {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let mode = GeminiAPIMode(rawValue: raw) else {
            return .smart  // Default to smart mode
        }
        return mode
    }

    func save() {
        UserDefaults.standard.set(self.rawValue, forKey: Self.storageKey)
    }
}

/// Batch API job models
struct BatchAPIJob: Codable {
    let jobId: String
    let batchId: Int64
    let createdAt: Date
    let status: BatchJobStatus
    let requestPayload: String  // JSON string of the request
    let responseData: String?   // JSON string of the response (when completed)
    let errorMessage: String?

    enum BatchJobStatus: String, Codable {
        case pending    // Job created, not yet submitted
        case submitted  // Submitted to Gemini Batch API
        case processing // Being processed by Gemini
        case completed  // Completed successfully
        case failed     // Failed with error
        case expired    // Job expired (>24h)
    }
}

/// Gemini Batch API request format
struct GeminiBatchRequest: Codable {
    let requests: [BatchRequestItem]

    struct BatchRequestItem: Codable {
        let customId: String        // Our batch ID
        let method: String          // "POST"
        let uri: String             // "/v1beta/models/gemini-2.0-flash-exp:generateContent"
        let body: RequestBody

        struct RequestBody: Codable {
            let contents: [Content]
            let generationConfig: GenerationConfig?

            struct Content: Codable {
                let parts: [Part]

                struct Part: Codable {
                    let text: String?
                    let fileData: FileData?

                    struct FileData: Codable {
                        let mimeType: String
                        let fileUri: String
                    }
                }
            }

            struct GenerationConfig: Codable {
                let temperature: Double?
                let topP: Double?
                let topK: Int?
                let maxOutputTokens: Int?
            }
        }
    }
}

/// Gemini Batch API response format
struct GeminiBatchResponse: Codable {
    let responses: [BatchResponseItem]

    struct BatchResponseItem: Codable {
        let customId: String
        let response: APIResponse?
        let error: APIError?

        struct APIResponse: Codable {
            let candidates: [Candidate]?

            struct Candidate: Codable {
                let content: Content

                struct Content: Codable {
                    let parts: [Part]

                    struct Part: Codable {
                        let text: String
                    }
                }
            }
        }

        struct APIError: Codable {
            let code: Int
            let message: String
            let status: String
        }
    }
}

/// Batch job metadata for tracking
struct BatchJobMetadata {
    let jobId: String
    let batchId: Int64
    let geminiJobName: String?  // Gemini's job identifier
    let submittedAt: Date
    let estimatedCompletion: Date
    let pollCount: Int
    let lastPolledAt: Date?
}
