//
//  OSLogger.swift
//  
//
//  Created by Lukáš Korba on 26.01.2023.
//

import Foundation
import os

public class OSLogger: Logger {
    public var alias: ZcashSynchronizerAlias?
    
    public enum LogLevel: Int {
        case debug
        case error
        case warning
        case event
        case info
    }

    public private(set) var oslog: OSLog?
    
    var level: LogLevel
    
    public init(logLevel: LogLevel, category: String = "logs", alias: ZcashSynchronizerAlias? = nil) {
        self.alias = alias
        self.level = logLevel
        if let bundleName = Bundle.main.bundleIdentifier {
            var postfix = ""
            if let alias { postfix = "_\(alias.description)" }
            self.oslog = OSLog(subsystem: bundleName, category: "\(category)\(postfix)")
        }
    }

    public func debug(
        _ message: String,
        file: StaticString = #file,
        function: StaticString = #function,
        line: Int = #line
    ) {
        guard level.rawValue == LogLevel.debug.rawValue else { return }
        log(level: "DEBUG 🐞", message: message, file: file, function: function, line: line)
    }
    
    public func error(
        _ message: String,
        file: StaticString = #file,
        function: StaticString = #function,
        line: Int = #line
    ) {
        guard level.rawValue <= LogLevel.error.rawValue else { return }
        log(level: "ERROR 💥", message: message, file: file, function: function, line: line)
    }
    
    public func warn(
        _ message: String,
        file: StaticString = #file,
        function: StaticString = #function,
        line: Int = #line
    ) {
        guard level.rawValue <= LogLevel.warning.rawValue else { return }
        log(level: "WARNING ⚠️", message: message, file: file, function: function, line: line)
    }

    public func event(
        _ message: String,
        file: StaticString = #file,
        function: StaticString = #function,
        line: Int = #line
    ) {
        guard level.rawValue <= LogLevel.event.rawValue else { return }
        log(level: "EVENT ⏱", message: message, file: file, function: function, line: line)
    }
    
    public func info(
        _ message: String,
        file: StaticString = #file,
        function: StaticString = #function,
        line: Int = #line
    ) {
        guard level.rawValue <= LogLevel.info.rawValue else { return }
        log(level: "INFO ℹ️", message: message, file: file, function: function, line: line)
    }
    
    private func log(
        level: String,
        message: String,
        file: StaticString = #file,
        function: StaticString = #function,
        line: Int = #line
    ) {
        guard let oslog else { return }
        
        let fileName = (String(describing: file) as NSString).lastPathComponent
        
        os_log(
            "[%{public}@] %{public}@ - %{public}@ - Line: %{public}d -> %{public}@",
            log: oslog,
            level,
            fileName,
            String(describing: function),
            line,
            message
        )
    }
}
