//
//  SampleLogger.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 3/9/20.
//  Copyright © 2020 Electric Coin Company. All rights reserved.
//

import Foundation
import os
import ZcashLightClientKit
class SampleLogger: ZcashLightClientKit.Logger {
    enum LogLevel: Int {
        case debug
        case error
        case warning
        case event
        case info
    }
    
    var level: LogLevel
    init(logLevel: LogLevel) {
        self.level = logLevel
    }
    
    private static let subsystem = Bundle.main.bundleIdentifier!
    static let oslog = OSLog(subsystem: subsystem, category: "test-logs")
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue == LogLevel.debug.rawValue else { return }
        log(level: "DEBUG 🐞", message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue <= LogLevel.error.rawValue else { return }
        log(level: "ERROR 💥", message: message, file: file, function: function, line: line)
    }
    
    func warn(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
           guard level.rawValue <= LogLevel.warning.rawValue else { return }
           log(level: "WARNING ⚠️", message: message, file: file, function: function, line: line)
    }

    func event(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue <= LogLevel.event.rawValue else { return }
        log(level: "EVENT ⏱", message: message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue <= LogLevel.info.rawValue else { return }
        log(level: "INFO ℹ️", message: message, file: file, function: function, line: line)
    }
    
    private func log(level: String, message: String, file: String, function: String, line: Int) {
        let fileName = file as NSString
        
        os_log("[%@] %@ - %@ - Line: %d -> %@", log: Self.oslog, type: .default, level, fileName.lastPathComponent, function, line, message)
    }
    
    
}
