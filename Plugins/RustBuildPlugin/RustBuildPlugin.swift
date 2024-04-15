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

        let rustBaseDir = context.package.directory.appending("rust")
        let rustManifestPath = rustBaseDir.appending("Cargo.toml")
        let rustBuildScript = rustBaseDir.appending("build.rs")
        let rustSrcDir = rustBaseDir.appending("src")
        let rustSrcLib = rustSrcDir.appending("lib.rs")
        let rustSrcFfi = rustSrcDir.appending("ffi.rs")
        let rustSrcOsLog = rustSrcDir.appending("os_log.rs")
        let rustSrcOsLogLayer = rustSrcDir.appending(["os_log", "layer.rs"])
        let rustSrcOsLogSignpost = rustSrcDir.appending(["os_log", "signpost.rs"])
        let rustSrcOsLogWriter = rustSrcDir.appending(["os_log", "writer.rs"])

        let rustTargetDir = context.pluginWorkDirectory.appending("RustBuild")
        let headersSrcDir = rustTargetDir.appending("Headers")
        let headersSrcFile = headersSrcDir.appending("zcashlc.h")

        let supportDir = context.package.directory.appending("support")
        let infoPlist = supportDir.appending("Info.plist")
        let moduleMap = supportDir.appending("module.modulemap")

        let xcframeworkDir = context.pluginWorkDirectory.appending("libzcashlc.xcframework")
        let xcframeworkInfoPlist = xcframeworkDir.appending("Info.plist")

        try FileManager.default.createDirectory(atPath: rustTargetDir.string, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: xcframeworkDir.string, withIntermediateDirectories: true)

        // The Info.plist needs to exist here in order to generate the build graph.
        let infoPlistCommand = Command.prebuildCommand(
            displayName: "Copying Info.plist into XCFramework",
            executable: try context.tool(named: "cp").path,
            arguments: [infoPlist, xcframeworkDir],
            outputFilesDirectory: xcframeworkInfoPlist
        )

        // A file can only be the output of a single command, so we use a "fast" command
        // to trigger the Rust build script and generate the headers.
        let headersCommand = Command.buildCommand(
            displayName: "Generating Rust headers",
            executable: try context.tool(named: "Forklift").path,
            arguments: [
                "cargo", "check",
                "--manifest-path", rustManifestPath,
                "--target-dir", rustTargetDir
            ],
            inputFiles: [
                rustManifestPath,
                rustBuildScript
            ],
            outputFiles: [headersSrcFile]
        )

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
                    inputFiles: [
                        rustManifestPath,
                        rustSrcLib,
                        rustSrcFfi,
                        rustSrcOsLog,
                        rustSrcOsLogLayer,
                        rustSrcOsLogSignpost,
                        rustSrcOsLogWriter
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
            let headersDestFile = headersDestDir.appending("zcashlc.h")
            let modulesDir = universalLibDir.appending("Modules")
            let moduleMapDest = modulesDir.appending("module.modulemap")

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
                    inputFiles: [headersSrcFile],
                    outputFiles: [headersDestFile]
                ),
                Command.buildCommand(
                    displayName: "Copying module map to \($0)",
                    executable: try context.tool(named: "cp").path,
                    arguments: [moduleMap, modulesDir],
                    inputFiles: [moduleMap],
                    outputFiles: [moduleMapDest]
                ),
                Command.buildCommand(
                    displayName: "Finished Rust \($0)",
                    executable: try context.tool(named: "ls").path,
                    arguments: [universalLibDir],
                    inputFiles: [universalLib, headersDestFile, moduleMapDest],
                    outputFiles: [universalLibDir]
                )
            ]
        }

        let platformDirs = platforms.map {
            return xcframeworkDir.appending([$0.key, "libzcashlc.framework"])
        }

        return [
            infoPlistCommand,
            headersCommand,
            Command.buildCommand(
                displayName: "Finished Rust XCFramework",
                executable: try context.tool(named: "ls").path,
                arguments: [xcframeworkDir],
                inputFiles: platformDirs,
                outputFiles: [xcframeworkDir]
            )
        ] + platformCommands
    }
}
