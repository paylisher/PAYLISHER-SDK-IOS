//
//  PaylisherFileBackedQueue.swift
//  Paylisher
//
//  Created by Manoel Aranda Neto on 13.10.23.
//

import Foundation

class PaylisherFileBackedQueue {
    let queue: URL
    @ReadWriteLock
    private var items = [String]()

    var depth: Int {
        items.count
    }

    init(queue: URL, oldQueue: URL? = nil) {
        self.queue = queue
        setup(oldQueue: oldQueue)
    }

    private func setup(oldQueue: URL?) {
        do {
            try FileManager.default.createDirectory(atPath: queue.path, withIntermediateDirectories: true)
        } catch {
            hedgeLog("Error trying to create caching folder \(error)")
        }

        if oldQueue != nil {
            migrateOldQueue(queue: queue, oldQueue: oldQueue!)
        }

        do {
            // Filenames are timestamps we wrote ourselves, but the directory is on
            // disk and anything else that lands there (a .DS_Store, a backup artifact,
            // a partially restored file) would make a force-unwrapped Double()
            // conversion trap. Ignore what we cannot order instead of crashing.
            let contents = try FileManager.default.contentsOfDirectory(atPath: queue.path)
            items = contents
                .compactMap { name -> (String, Double)? in
                    guard let timestamp = Double(name) else {
                        hedgeLog("Ignoring unrecognised file in queue: \(name)")
                        return nil
                    }
                    return (name, timestamp)
                }
                .sorted { $0.1 < $1.1 }
                .map { $0.0 }
        } catch {
            hedgeLog("Failed to load files for queue \(error)")
            // failed to read directory – bad permissions, perhaps?
        }
    }

    func peek(_ count: Int) -> [Data] {
        loadFiles(count)
    }

    func delete(index: Int) {
        // Read-modify-write has to happen under a single write lock. Checking
        // `items.isEmpty` and then calling `items.remove(at:)` takes the lock twice,
        // so a concurrent flush could empty the array in between — or shift it, so
        // that `index` removes the wrong entry (or traps on an out-of-range index).
        if let removed: String = _items.mutate({ items in
            guard index >= 0, index < items.count else {
                return nil
            }
            return items.remove(at: index)
        }) {
            deleteSafely(queue.appendingPathComponent(removed))
        }
    }

    func pop(_ count: Int) {
        deleteFiles(count)
    }

    func add(_ contents: Data) {
        do {
            let filename = "\(Date().timeIntervalSince1970)"
            try contents.write(to: queue.appendingPathComponent(filename))
            // `items.append(_:)` through the wrapper is a get followed by a set, i.e.
            // two separate lock acquisitions: a concurrent append could read the same
            // array and write back a copy missing the other entry, orphaning the file
            // on disk. Mutate under one write lock instead.
            _items.mutate { $0.append(filename) }
        } catch {
            hedgeLog("Could not write file \(error)")
        }
    }

    func clear() {
        deleteSafely(queue)
        setup(oldQueue: nil)
    }

    private func loadFiles(_ count: Int) -> [Data] {
        var results = [Data]()

        for item in items {
            let itemURL = queue.appendingPathComponent(item)
            do {
                if !FileManager.default.fileExists(atPath: itemURL.path) {
                    hedgeLog("File \(itemURL) does not exist")
                    continue
                }
                let contents = try Data(contentsOf: itemURL)

                results.append(contents)
            } catch {
                hedgeLog("File \(itemURL) is corrupted \(error)")

                deleteSafely(itemURL)
            }

            if results.count == count {
                return results
            }
        }

        return results
    }

    private func deleteFiles(_ count: Int) {
        for _ in 0 ..< count {
            if let removed: String = _items.mutate({ items in
                if items.isEmpty {
                    return nil
                }
                return items.remove(at: 0) // We always remove from the top of the queue
            }) {
                deleteSafely(queue.appendingPathComponent(removed))
            }
        }
    }
}
