//
//  Forklift.swift
//
//
//  Created by Jack Grigg on 31/10/2023.
//

import Foundation

@main
@available(macOS 13.0.0, *)
class Forklift {
    static func main() {
        var arguments = CommandLine.arguments
        let executable = arguments.removeFirst()

        let process = Process()
        process.executableURL = URL.init(string: executable)
        process.arguments = arguments
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        do {
            try process.run()
        } catch {
            exit(1)
        }
    }
}
