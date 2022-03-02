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
}

var logger: Logger?

enum LoggerProxy {
    static func debug(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        logger?.debug(message, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        logger?.info(message, file: file, function: function, line: line)
    }
    
    static func event(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        logger?.event(message, file: file, function: function, line: line)
    }
    
    static func warn(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        logger?.warn(message, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: StaticString = #file, function: StaticString = #function, line: Int = #line) {
        logger?.error(message, file: file, function: function, line: line)
    }
}
