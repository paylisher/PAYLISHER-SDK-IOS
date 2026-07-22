//
//  PaylisherQueue.swift
//  Paylisher
//
//  Created by Ben White on 06.02.23.
//

import Foundation

/**
 # Queue

 The queue uses File persistence. This allows us to
 1. Only send events when we have a network connection
 2. Ensure that we can survive app closing or offline situations
 3. Not hold too much in mempory

 */

class PaylisherQueue {
    enum PaylisherApiEndpoint: Int {
        case batch
        case snapshot
    }

    private let config: PaylisherConfig
    private let storage: PaylisherStorage
    private let api: PaylisherApi
    private var paused: Bool = false
    private let pausedLock = NSLock()
    private var pausedUntil: Date?
    private var retryCount: TimeInterval = 0
    #if !os(watchOS)
        private let reachability: Reachability?
    #endif

    private var isFlushing = false
    private let isFlushingLock = NSLock()
    private var timer: Timer?
    private let timerLock = NSLock()
    /// Whether `stop()` has been called. Guarded by `timerLock`. Needed because the
    /// timer is installed on a later main-queue hop, so a `stop()` in between would
    /// otherwise be undone by that pending block.
    private var isStopped = false
    private let endpoint: PaylisherApiEndpoint
    private let dispatchQueue: DispatchQueue

    var depth: Int {
        fileQueue.depth
    }

    private let fileQueue: PaylisherFileBackedQueue

    #if !os(watchOS)
        init(_ config: PaylisherConfig, _ storage: PaylisherStorage, _ api: PaylisherApi, _ endpoint: PaylisherApiEndpoint, _ reachability: Reachability?) {
            self.config = config
            self.storage = storage
            self.api = api
            self.reachability = reachability
            self.endpoint = endpoint

            switch endpoint {
            case .batch:
                fileQueue = PaylisherFileBackedQueue(queue: storage.url(forKey: .queue), oldQueue: storage.url(forKey: .oldQeueue))
                dispatchQueue = DispatchQueue(label: "com.paylisher.Queue", target: .global(qos: .utility))
            case .snapshot:
                fileQueue = PaylisherFileBackedQueue(queue: storage.url(forKey: .replayQeueue))
                dispatchQueue = DispatchQueue(label: "com.paylisher.ReplayQueue", target: .global(qos: .utility))
            }
        }
    #else
        init(_ config: PaylisherConfig, _ storage: PaylisherStorage, _ api: PaylisherApi, _ endpoint: PaylisherApiEndpoint) {
            self.config = config
            self.storage = storage
            self.api = api
            self.endpoint = endpoint

            switch endpoint {
            case .batch:
                fileQueue = PaylisherFileBackedQueue(queue: storage.url(forKey: .queue), oldQueue: storage.url(forKey: .oldQeueue))
                dispatchQueue = DispatchQueue(label: "com.paylisher.Queue", target: .global(qos: .utility))
            case .snapshot:
                fileQueue = PaylisherFileBackedQueue(queue: storage.url(forKey: .replayQeueue))
                dispatchQueue = DispatchQueue(label: "com.paylisher.ReplayQueue", target: .global(qos: .utility))
            }
        }
    #endif

    private func eventHandler(_ payload: PaylisherConsumerPayload) {
        hedgeLog("Sending batch of \(payload.events.count) events to Paylisher")

        switch endpoint {
        case .batch:
            api.batch(events: payload.events) { result in
                self.handleResult(result, payload)
            }
        case .snapshot:
            api.snapshot(events: payload.events) { result in
                self.handleResult(result, payload)
            }
        }
    }

    private func handleResult(_ result: PaylisherBatchUploadInfo, _ payload: PaylisherConsumerPayload) {
        // -1 means its not anything related to the API but rather network or something else, so we try again
        let statusCode = result.statusCode ?? -1

        var shouldRetry = false
        if 300 ... 399 ~= statusCode || statusCode == -1 {
            shouldRetry = true
        }

        // 413 Payload Too Large: halve maxBatchSize / flushAt (down to 1) and retry,
        // mirroring paylisher-android. Without this, large media payloads (e.g. PNG snapshots
        // exceeding the broker limit) would either loop forever as 5xx-style retries or be
        // silently dropped. Once batch size is already 1 and we still get 413, fall through to
        // the drop branch — there's nothing we can do at that point.
        if statusCode == 413, config.maxBatchSize > 1 {
            config.maxBatchSize = calcFloor(config.maxBatchSize)
            config.flushAt = calcFloor(config.flushAt)
            hedgeLog("Flushing failed with 413, retrying with smaller batch (maxBatchSize=\(config.maxBatchSize), flushAt=\(config.flushAt)).")
            shouldRetry = true
        }

        // 5xx is a transient server error; keep events and retry rather than drop.
        if 500 ... 599 ~= statusCode {
            shouldRetry = true
        }

        if shouldRetry {
            retryCount += 1
            let delay = min(retryCount * retryDelay, maxRetryDelay)
            pauseFor(seconds: delay)
            hedgeLog("Pausing queue consumption for \(delay) seconds due to \(retryCount) API failure(s).")
        } else {
            retryCount = 0
        }

        payload.completion(!shouldRetry)
    }

    private func calcFloor(_ value: Int) -> Int {
        max(value / 2, 1)
    }

    func start(disableReachabilityForTesting: Bool,
               disableQueueTimerForTesting: Bool)
    {
        timerLock.lock()
        isStopped = false
        timerLock.unlock()

        if !disableReachabilityForTesting {
            // Setup the monitoring of network status for the queue
            #if !os(watchOS)
                reachability?.whenReachable = { [weak self] reachability in
                    guard let self = self else { return }
                    self.pausedLock.withLock {
                        if self.config.dataMode == .wifi, reachability.connection != .wifi {
                            hedgeLog("Queue is paused because its not in WiFi mode")
                            self.paused = true
                        } else {
                            self.paused = false
                        }
                    }

                    // Always trigger a flush when we are on wifi
                    if reachability.connection == .wifi {
                        if !self.isFlushing {
                            self.flush()
                        }
                    }
                }

                reachability?.whenUnreachable = { [weak self] _ in
                    guard let self = self else { return }
                    self.pausedLock.withLock {
                        hedgeLog("Queue is paused because network is unreachable")
                        self.paused = true
                    }
                }

                do {
                    try reachability?.startNotifier()
                } catch {
                    hedgeLog("Error: Unable to monitor network reachability: \(error)")
                }
            #endif
        }

        if !disableQueueTimerForTesting {
            // The lock cannot guard the assignment: it is released as soon as the
            // async block is *scheduled*, long before `self.timer` is written on the
            // main queue. A `stop()` racing in between invalidated a nil timer and
            // then this block installed a fresh repeating one — a flush timer that
            // outlived close(), firing after the SDK was shut down.
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.timerLock.lock()
                defer { self.timerLock.unlock() }

                // Someone stopped us while this hop was queued — stay stopped.
                guard !self.isStopped else { return }

                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(withTimeInterval: self.config.flushIntervalSeconds, repeats: true, block: { [weak self] _ in
                    guard let self = self else { return }
                    if !self.isFlushing {
                        self.flush()
                    }
                })
            }
        }
    }

    func clear() {
        fileQueue.clear()
    }

    func stop() {
        timerLock.withLock {
            isStopped = true
            timer?.invalidate()
            timer = nil
        }
    }

    func flush() {
        if !canFlush() {
            return
        }

        take(config.maxBatchSize) { payload in
            if !payload.events.isEmpty {
                self.eventHandler(payload)
            } else {
                // there's nothing to be sent
                payload.completion(true)
            }
        }
    }

    private func flushIfOverThreshold() {
        if fileQueue.depth >= config.flushAt {
            flush()
        }
    }

    func add(_ event: PaylisherEvent) {
        if fileQueue.depth >= config.maxQueueSize {
            hedgeLog("Queue is full, dropping oldest event")
            // first is always oldest
            fileQueue.delete(index: 0)
        }

        var data: Data?
        do {
            data = try JSONSerialization.data(withJSONObject: event.toJSON())
        } catch {
            hedgeLog("Tried to queue unserialisable PaylisherEvent \(error)")
            return
        }

        fileQueue.add(data!)
        hedgeLog("Queued event '\(event.event)'. Depth: \(fileQueue.depth)")
        flushIfOverThreshold()
    }

    private func take(_ count: Int, completion: @escaping (PaylisherConsumerPayload) -> Void) {
        dispatchQueue.async {
            // The re-entrancy guard has to return from THIS closure. Written as
            // `isFlushingLock.withLock { if isFlushing { return } ... }` the return
            // only exits the lock closure, so a second flush fell straight through
            // and ran concurrently with the first — peeking the same items, sending
            // them twice, and popping entries the other flush had not delivered yet.
            self.isFlushingLock.lock()
            if self.isFlushing {
                self.isFlushingLock.unlock()
                return
            }
            self.isFlushing = true
            self.isFlushingLock.unlock()

            let items = self.fileQueue.peek(count)

            var processing = [PaylisherEvent]()

            for item in items {
                // each element is a PaylisherEvent if fromJSON succeeds
                guard let event = PaylisherEvent.fromJSON(item) else {
                    continue
                }
                processing.append(event)
            }

            completion(PaylisherConsumerPayload(events: processing) { success in
                if success, items.count > 0 {
                    self.fileQueue.pop(items.count)
                    hedgeLog("Completed!")
                }

                self.isFlushingLock.withLock {
                    self.isFlushing = false
                }
            })
        }
    }

    private func pauseFor(seconds: TimeInterval) {
        pausedUntil = Date().addingTimeInterval(seconds)
    }

    private func canFlush() -> Bool {
        if isFlushing {
            hedgeLog("Already flushing")
            return false
        }

        if paused {
            // We don't flush data if the queue is paused
            hedgeLog("The queue is paused due to the reachability check")
            return false
        }

        if pausedUntil != nil, pausedUntil! > Date() {
            // We don't flush data if the queue is temporarily paused
            hedgeLog("The queue is paused until `\(pausedUntil!)`")
            return false
        }

        return true
    }
}
