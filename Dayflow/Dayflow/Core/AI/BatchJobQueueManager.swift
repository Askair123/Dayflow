//
//  BatchJobQueueManager.swift
//  Dayflow
//
//  Manages batch job queue, polling, and result processing
//

import Foundation
import GRDB

/// Manages the queue of batch API jobs and their lifecycle
final class BatchJobQueueManager {

    static let shared = BatchJobQueueManager()

    private let client: GeminiBatchAPIClient?
    private var pollingTimer: Timer?
    private let pollInterval: TimeInterval = 120  // Poll every 2 minutes
    private let queue = DispatchQueue(label: "com.dayflow.batchqueue", qos: .utility)

    private init() {
        // Initialize client if API key is available
        if let apiKey = KeychainManager.shared.retrieve(for: "gemini"), !apiKey.isEmpty {
            client = GeminiBatchAPIClient(apiKey: apiKey)
        } else {
            client = nil
        }
    }

    // MARK: - Queue Management

    /// Starts the polling timer to check pending batch jobs
    func startPolling() {
        guard client != nil else {
            print("[BatchQueue] No API client available, skipping polling")
            return
        }

        stopPolling()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pollingTimer = Timer.scheduledTimer(
                timeInterval: self.pollInterval,
                target: self,
                selector: #selector(self.pollPendingJobs),
                userInfo: nil,
                repeats: true
            )
            print("[BatchQueue] Polling started (interval: \(self.pollInterval)s)")

            // Immediate poll
            self.pollPendingJobs()
        }
    }

    /// Stops the polling timer
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("[BatchQueue] Polling stopped")
    }

    @objc private func pollPendingJobs() {
        queue.async { [weak self] in
            self?.checkPendingJobs()
        }
    }

    private func checkPendingJobs() {
        guard let client = client else { return }

        // Get all pending/submitted/processing jobs from database
        let pendingJobs = fetchPendingBatchJobs()

        guard !pendingJobs.isEmpty else { return }

        print("[BatchQueue] Checking \(pendingJobs.count) pending jobs")

        for job in pendingJobs {
            guard let geminiJobName = job.geminiJobName else {
                print("[BatchQueue] Job \(job.jobId) has no Gemini job name, skipping")
                continue
            }

            // Poll status
            client.pollJobStatus(geminiJobName) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let status):
                    self.handleJobStatusUpdate(job: job, status: status)

                case .failure(let error):
                    print("[BatchQueue] Failed to poll job \(job.jobId): \(error)")
                    // Don't mark as failed yet - might be temporary network error
                }
            }
        }
    }

    private func handleJobStatusUpdate(job: BatchJobMetadata, status: BatchJobStatusResponse) {
        print("[BatchQueue] Job \(job.jobId) status: \(status.state)")

        switch status.state {
        case "PENDING", "PROCESSING":
            // Still in progress, update poll count
            updateJobMetadata(
                jobId: job.jobId,
                status: status.state,
                pollCount: job.pollCount + 1
            )

        case "COMPLETED":
            // Retrieve results and process
            processCompletedJob(job: job, status: status)

        case "FAILED":
            // Mark as failed
            markJobFailed(
                jobId: job.jobId,
                error: status.errorMessage ?? "Unknown error"
            )

        default:
            print("[BatchQueue] Unknown status: \(status.state)")
        }
    }

    private func processCompletedJob(job: BatchJobMetadata, status: BatchJobStatusResponse) {
        guard let client = client else { return }

        print("[BatchQueue] Processing completed job \(job.jobId)")

        client.retrieveResults(job.geminiJobName!) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let batchResponse):
                // Find our batch's response
                if let item = batchResponse.responses.first(where: { $0.customId == String(job.batchId) }) {
                    if let apiResponse = item.response {
                        // Extract the generated content
                        self.saveBatchResult(
                            jobId: job.jobId,
                            batchId: job.batchId,
                            response: apiResponse
                        )
                    } else if let error = item.error {
                        self.markJobFailed(
                            jobId: job.jobId,
                            error: "API error: \(error.message)"
                        )
                    }
                } else {
                    self.markJobFailed(
                        jobId: job.jobId,
                        error: "Response not found in batch results"
                    )
                }

            case .failure(let error):
                print("[BatchQueue] Failed to retrieve results for \(job.jobId): \(error)")
                self.markJobFailed(jobId: job.jobId, error: error.localizedDescription)
            }
        }
    }

    // MARK: - Database Operations

    private func fetchPendingBatchJobs() -> [BatchJobMetadata] {
        // TODO: Implement database query for pending jobs
        // For now, return empty array
        return []
    }

    private func updateJobMetadata(jobId: String, status: String, pollCount: Int) {
        // TODO: Update job metadata in database
        print("[BatchQueue] Updated job \(jobId): status=\(status), polls=\(pollCount)")
    }

    private func markJobFailed(jobId: String, error: String) {
        // TODO: Mark job as failed in database
        print("[BatchQueue] Marked job \(jobId) as failed: \(error)")

        // Also mark the corresponding analysis batch as failed
        // This will trigger the batch to be retried or skipped
    }

    private func saveBatchResult(jobId: String, batchId: Int64, response: GeminiBatchResponse.BatchResponseItem.APIResponse) {
        print("[BatchQueue] Saving result for batch \(batchId)")

        // Extract text from response
        guard let firstCandidate = response.candidates?.first,
              let text = firstCandidate.content.parts.first?.text else {
            markJobFailed(jobId: jobId, error: "No text in response")
            return
        }

        // TODO: Parse the JSON response and create activity cards
        // This should follow the same logic as the realtime API processing
        // For now, just log
        print("[BatchQueue] Response text length: \(text.count) chars")

        // Mark batch as analyzed
        StorageManager.shared.updateBatch(batchId, status: "analyzed")
    }

    // MARK: - Job Submission

    /// Submits a new batch job for processing
    /// - Parameters:
    ///   - batchId: The analysis batch ID
    ///   - request: The Gemini batch request
    ///   - completion: Callback with job ID on success
    func submitBatchJob(batchId: Int64, request: GeminiBatchRequest, completion: @escaping (Result<String, Error>) -> Void) {
        guard let client = client else {
            completion(.failure(BatchAPIError.noData))
            return
        }

        let jobId = UUID().uuidString

        print("[BatchQueue] Submitting batch job for batch \(batchId)")

        client.submitBatchRequest(request) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let geminiJobName):
                // Save job metadata
                self.saveJobMetadata(
                    jobId: jobId,
                    batchId: batchId,
                    geminiJobName: geminiJobName
                )
                completion(.success(jobId))

            case .failure(let error):
                print("[BatchQueue] Failed to submit job: \(error)")
                completion(.failure(error))
            }
        }
    }

    private func saveJobMetadata(jobId: String, batchId: Int64, geminiJobName: String) {
        // TODO: Save to database
        print("[BatchQueue] Saved job metadata: \(jobId) -> \(geminiJobName)")

        // Mark batch as processing
        StorageManager.shared.updateBatch(batchId, status: "batch_processing")
    }
}

// MARK: - Convenience Methods

extension BatchJobQueueManager {

    /// Gets statistics about the batch queue
    func getQueueStats() -> (pending: Int, processing: Int, completed: Int, failed: Int) {
        // TODO: Query database for stats
        return (pending: 0, processing: 0, completed: 0, failed: 0)
    }

    /// Retries a failed batch job
    func retryFailedJob(jobId: String) {
        // TODO: Implement retry logic
        print("[BatchQueue] Retrying job \(jobId)")
    }

    /// Cancels a pending job
    func cancelJob(jobId: String) {
        guard let client = client else { return }

        // TODO: Get job metadata from database
        // client.cancelJob(geminiJobName) { ... }
        print("[BatchQueue] Cancelling job \(jobId)")
    }
}
