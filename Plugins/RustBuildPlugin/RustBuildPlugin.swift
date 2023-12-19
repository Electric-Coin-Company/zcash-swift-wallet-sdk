//
//  RustBuildPlugin.swift
//
//
//  Created by Jack Grigg on 31/10/2023.
//

import Foundation
import PackagePlugin

@main
struct MyPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        if target.name != "ZcashLightClientKit" { return [] }

        let platforms = [
            "ios-arm64": ["aarch64-apple-ios"],
            "macos-arm64_x86_64": ["aarch64-apple-darwin", "x86_64-apple-darwin"],
            "ios-arm64_x86_64-simulator": ["aarch64-apple-ios-sim", "x86_64-apple-ios"],
        ]

        let rustManifestPath = context.package.directory.appending(["rust", "Cargo.toml"])
        let rustTargetDir = context.pluginWorkDirectory.appending("RustBuild")
        let headersSrcDir = rustTargetDir.appending("Headers")
        let supportDir = context.package.directory.appending("support")
        let infoPlist = supportDir.appending("Info.plist")
        let moduleMap = supportDir.appending("module.modulemap")
        let xcframeworkDir =  context.pluginWorkDirectory.appending("libzcashlc.xcframework")

        try FileManager.default.createDirectory(atPath: rustTargetDir.string, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: xcframeworkDir.string, withIntermediateDirectories: true)

        let platformCommands = try platforms.flatMap {
            let archCommands = try $1.map {
                return Command.buildCommand(
                    displayName: "Building Rust static library for \($0)",
                    executable: try context.tool(named: "Forklift").path,
                    arguments: [
                        "cargo", "build",
                        "--manifest-path", rustManifestPath,
                        "--target-dir", rustTargetDir,
                        "--target", $0,
                        "--release"
                    ],
                    outputFiles: [
                        rustTargetDir.appending([$0, "release", "libzcashlc.a"])
                    ]
                )
            }

            let archLibs = $1.map {
                rustTargetDir.appending([$0, "release", "libzcashlc.a"])
            }

            let universalLibDir = xcframeworkDir.appending([$0, "libzcashlc.framework"])
            let universalLib = universalLibDir.appending("libzcashlc")
            let headersDestDir = universalLibDir.appending("Headers")
            let modulesDir = universalLibDir.appending("Modules")

            try FileManager.default.createDirectory(atPath: modulesDir.string, withIntermediateDirectories: true)

            return archCommands + [
                Command.buildCommand(
                    displayName: "Creating universal library for \($0)",
                    executable: try context.tool(named: "lipo").path,
                    arguments: ["-create"] + archLibs + ["-output", universalLib],
                    inputFiles: archLibs,
                    outputFiles: [universalLib]
                ),
                Command.buildCommand(
                    displayName: "Copying Rust headers to \($0)",
                    executable: try context.tool(named: "cp").path,
                    arguments: ["-R", headersSrcDir, universalLibDir],
                    inputFiles: [headersSrcDir],
                    outputFiles: [headersDestDir]
                ),
                Command.buildCommand(
                    displayName: "Copying module map to \($0)",
                    executable: try context.tool(named: "cp").path,
                    arguments: [moduleMap, modulesDir],
                    inputFiles: [moduleMap],
                    outputFiles: [modulesDir]
                )
            ]
        }

        let platformFiles = platforms.flatMap {
            let universalLibDir = xcframeworkDir.appending([$0.key, "libzcashlc.framework"])
            let universalLib = universalLibDir.appending("libzcashlc")
            let headersDestDir = universalLibDir.appending("Headers")
            let modulesDir = universalLibDir.appending("Modules")

            return [universalLib, headersDestDir, modulesDir]
        }

        return platformCommands + [
            Command.buildCommand(
                displayName: "Assembling XCFramework",
                executable: try context.tool(named: "cp").path,
                arguments: [infoPlist, xcframeworkDir],
                inputFiles: platformFiles + [infoPlist],
                outputFiles: [xcframeworkDir]
            )
        ]
    }
}
