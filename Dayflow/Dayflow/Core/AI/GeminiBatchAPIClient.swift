//
//  GeminiBatchAPIClient.swift
//  Dayflow
//
//  Client for Gemini Batch API - 50% cost savings with delayed processing
//

import Foundation

/// Client for interacting with Gemini Batch API
final class GeminiBatchAPIClient {

    private let apiKey: String
    private let batchEndpoint = "https://generativelanguage.googleapis.com/v1beta"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Batch Job Submission

    /// Submits a batch request to Gemini Batch API
    /// - Parameters:
    ///   - request: The batch request containing one or more generation requests
    ///   - completion: Callback with job name on success
    func submitBatchRequest(_ request: GeminiBatchRequest, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "\(batchEndpoint)/batches")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(request)

            print("[BatchAPI] Submitting batch request with \(request.requests.count) items")

            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    print("[BatchAPI] Submission failed: \(error)")
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(BatchAPIError.noData))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("[BatchAPI] Submission response status: \(httpResponse.statusCode)")

                    guard httpResponse.statusCode == 200 else {
                        if let errorBody = String(data: data, encoding: .utf8) {
                            print("[BatchAPI] Error response: \(errorBody)")
                        }
                        completion(.failure(BatchAPIError.httpError(httpResponse.statusCode)))
                        return
                    }
                }

                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let response = try decoder.decode(BatchSubmissionResponse.self, from: data)
                    print("[BatchAPI] Batch job created: \(response.name)")
                    completion(.success(response.name))
                } catch {
                    print("[BatchAPI] Failed to decode response: \(error)")
                    completion(.failure(error))
                }
            }
            task.resume()

        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Job Status Polling

    /// Polls the status of a batch job
    /// - Parameters:
    ///   - jobName: The Gemini job identifier (e.g., "batches/12345")
    ///   - completion: Callback with current status
    func pollJobStatus(_ jobName: String, completion: @escaping (Result<BatchJobStatusResponse, Error>) -> Void) {
        let url = URL(string: "\(batchEndpoint)/\(jobName)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(BatchAPIError.noData))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                if let errorBody = String(data: data, encoding: .utf8) {
                    print("[BatchAPI] Poll error: \(errorBody)")
                }
                completion(.failure(BatchAPIError.httpError(httpResponse.statusCode)))
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let statusResponse = try decoder.decode(BatchJobStatusResponse.self, from: data)
                completion(.success(statusResponse))
            } catch {
                print("[BatchAPI] Failed to decode status: \(error)")
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Result Retrieval

    /// Retrieves the results of a completed batch job
    /// - Parameters:
    ///   - jobName: The Gemini job identifier
    ///   - completion: Callback with batch response
    func retrieveResults(_ jobName: String, completion: @escaping (Result<GeminiBatchResponse, Error>) -> Void) {
        // First, get the output URI from the job status
        pollJobStatus(jobName) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let status):
                guard status.state == "COMPLETED" else {
                    completion(.failure(BatchAPIError.jobNotCompleted(status.state)))
                    return
                }

                guard let outputUri = status.outputUri else {
                    completion(.failure(BatchAPIError.noOutputUri))
                    return
                }

                // Download the results from Cloud Storage
                self.downloadResults(from: outputUri, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func downloadResults(from uri: String, completion: @escaping (Result<GeminiBatchResponse, Error>) -> Void) {
        guard let url = URL(string: uri) else {
            completion(.failure(BatchAPIError.invalidOutputUri))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(BatchAPIError.noData))
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let batchResponse = try decoder.decode(GeminiBatchResponse.self, from: data)
                print("[BatchAPI] Retrieved \(batchResponse.responses.count) results")
                completion(.success(batchResponse))
            } catch {
                print("[BatchAPI] Failed to decode results: \(error)")
                completion(.failure(error))
            }
        }
        task.resume()
    }

    // MARK: - Job Cancellation

    /// Cancels a pending or processing batch job
    func cancelJob(_ jobName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "\(batchEndpoint)/\(jobName):cancel")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let task = URLSession.shared.dataTask(with: urlRequest) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                print("[BatchAPI] Job cancelled: \(jobName)")
                completion(.success(()))
            } else {
                completion(.failure(BatchAPIError.cancellationFailed))
            }
        }
        task.resume()
    }
}

// MARK: - Response Models

struct BatchSubmissionResponse: Codable {
    let name: String            // e.g., "batches/abc123"
    let state: String           // "PENDING", "PROCESSING", etc.
    let createTime: String?
    let updateTime: String?
}

struct BatchJobStatusResponse: Codable {
    let name: String
    let state: String           // "PENDING", "PROCESSING", "COMPLETED", "FAILED"
    let createTime: String?
    let updateTime: String?
    let outputUri: String?      // Cloud Storage URI for results
    let errorMessage: String?
    let processedRecordCount: Int?
    let totalRecordCount: Int?
}

// MARK: - Errors

enum BatchAPIError: Error, LocalizedError {
    case noData
    case httpError(Int)
    case jobNotCompleted(String)
    case noOutputUri
    case invalidOutputUri
    case cancellationFailed

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data received from Batch API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .jobNotCompleted(let state):
            return "Job not completed. Current state: \(state)"
        case .noOutputUri:
            return "No output URI in completed job"
        case .invalidOutputUri:
            return "Invalid output URI format"
        case .cancellationFailed:
            return "Failed to cancel batch job"
        }
    }
}
