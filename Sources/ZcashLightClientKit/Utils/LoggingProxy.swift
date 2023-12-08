//
//  LoggingProxy.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 3/6/20.
//

import Foundation

/**
Represents what's expected from a logging entity
*/
public protocol Logger {
    func debug(_ message: String, file: StaticString, function: StaticString, line: Int)
    func info(_ message: String, file: StaticString, function: StaticString, line: Int)
    func event(_ message: String, file: StaticString, function: StaticString, line: Int)
    func warn(_ message: String, file: StaticString, function: StaticString, line: Int)
    func error(_ message: String, file: StaticString, function: StaticString, line: Int)
    func sync(_ message: String, file: StaticString, function: StaticString, line: Int)
}

extension Logger {
    func debug(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        debug(message, file: file, function: function, line: line)
    }
    func info(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        info(message, file: file, function: function, line: line)
    }
    func event(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        event(message, file: file, function: function, line: line)
    }
    func warn(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        warn(message, file: file, function: function, line: line)
    }
    func error(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        error(message, file: file, function: function, line: line)
    }
    func sync(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        sync(message, file: file, function: function, line: line)
    }
}

/**
A concrete logger implementation that logs nothing at all
 */
struct NullLogger: Logger {
    func debug(_ message: String, file: StaticString, function: StaticString, line: Int) {}
    func info(_ message: String, file: StaticString, function: StaticString, line: Int) {}
    func event(_ message: String, file: StaticString, function: StaticString, line: Int) {}
    func warn(_ message: String, file: StaticString, function: StaticString, line: Int) {}
    func error(_ message: String, file: StaticString, function: StaticString, line: Int) {}
    func sync(_ message: String, file: StaticString, function: StaticString, line: Int) {}
}
