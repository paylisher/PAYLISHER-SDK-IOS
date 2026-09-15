//
//  DefaultErrorHandler.swift
//  Paylisher
//
//  Created by Business on 1.11.2024.
//
import Foundation

// Default error handler implementation
class DefaultErrorHandler: ErrorHandler {
    func handleError(error: Error) {
        hedgeLog("Error occurred: \(error.localizedDescription)")
    }
}

/// The handler that was installed BEFORE the SDK's (Crashlytics, Sentry, the host's
/// own). Kept so the SDK chains to it instead of silently replacing it: a crash
/// reporter that loses its NSException hook only sees a bare SIGABRT afterwards.
private var previousUncaughtExceptionHandler: NSUncaughtExceptionHandler?

/// Global uncaught exception handler. Records the exception as a Paylisher event,
/// then forwards it to whatever handler was installed before ours.
public func uncaughtExceptionHandler(_ exception: NSException) {
    let stackTrace = exception.callStackSymbols.joined(separator: "\n")
    let exceptionType = String(describing: exception.name)
    let message = exception.reason ?? "No message available"
    let threadName = Thread.isMainThread ? "Main Thread" : "Background Thread"

    let data = """
    # Type of exception: \(exceptionType)
    # Exception message: \(message)
    # Thread name: \(threadName)
    # Stacktrace: \(stackTrace)
    """

    // Limit the data length to 8192 characters
    let truncatedData = data.count > 8192 ? String(data.prefix(8192)) : data

    let properties: [String: Any] = [
        "exceptionType": exceptionType,
        "message": message,
        "threadName": threadName,
        "stackTrace": truncatedData,
    ]

    PaylisherSDK.shared.capture("Error", properties: properties)

    // Chain: the host's crash reporter must still see the exception.
    previousUncaughtExceptionHandler?(exception)
}

/// Installs the global handler at most once per process and remembers the previous
/// one so it keeps receiving exceptions. Opt-in via
/// `PaylisherConfig.installUncaughtExceptionHandler` (default off).
@objc public class ErrorHandlerRegistrar: NSObject {
    private static let lock = NSLock()
    private static var installed = false

    @objc public static func setupGlobalErrorHandler() {
        lock.lock()
        defer { lock.unlock() }
        if installed { return }
        installed = true

        previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)
        hedgeLog("Global error handler set (chained to previous handler: \(previousUncaughtExceptionHandler != nil)).")
    }
}
