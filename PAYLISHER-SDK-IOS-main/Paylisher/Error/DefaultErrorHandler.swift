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
        print("Error occurred: \(error.localizedDescription)")
        // Additional error logging or reporting
    }
    
    // Define the global exception handler
    @objc static func handleUncaughtException(exception: NSException) {
        // Log the exception details
        print("Uncaught exception: \(exception.name), Reason: \(String(describing: exception.reason))")
        print("Stack Trace: \(exception.callStackSymbols)")

        // You can also send this information to a logging service
    }
    
}
 
// Step 1: Global uncaught exception handler function
public func uncaughtExceptionHandler(_ exception: NSException) {
    // Log the exception details
    print("Uncaught exception: \(exception.name)")
    print("Reason: \(String(describing: exception.reason))")
    print("Stack Trace: \(exception.callStackSymbols)")

    // Capture stack trace as a string
    let stackTrace = exception.callStackSymbols.joined(separator: "\n")

    // Gather exception details
    let exceptionType = String(describing: exception.name)
    let message = exception.reason ?? "No message available"
    let threadName = Thread.isMainThread ? "Main Thread" : "Background Thread"

    // Construct data string with relevant information
    let data = """
    # Type of exception: \(exceptionType)
    # Exception message: \(message)
    # Thread name: \(threadName)
    # Stacktrace: \(stackTrace)
    """

    // Limit the data length to 8192 characters
    let truncatedData = data.count > 8192 ? String(data.prefix(8192)) : data

    // Create properties dictionary with the error details
    let properties: [String: Any] = [
        "exceptionType": exceptionType,
        "message": message,
        "threadName": threadName,
        "stackTrace": truncatedData
    ]

    // Send the data to Paylisher or any logging service
    PaylisherSDK.shared.capture("Error", properties: properties)
}

// Step 2: Register the global handler function
@objc public class ErrorHandlerRegistrar: NSObject {
    @objc public static func setupGlobalErrorHandler() {
        NSSetUncaughtExceptionHandler(uncaughtExceptionHandler)
        print("Global error handler set.")
    }
}

//**
 
// Define the global exception handler
//func handleUncaughtException(exception: NSException) {
//    // Log the exception details
//    print("Uncaught exception: \(exception.name), Reason: \(String(describing: exception.reason))")
//    print("Stack Trace: \(exception.callStackSymbols)")
//
//    // You can also send this information to a logging service
//}
//
//// Set the global exception handler
//public func setupGlobalErrorHandling() {
//    NSSetUncaughtExceptionHandler(handleUncaughtException)
//}
