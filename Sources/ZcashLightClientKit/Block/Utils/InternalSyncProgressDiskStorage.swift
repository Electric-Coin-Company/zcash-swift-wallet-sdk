//
//  InternalSyncProgressDiskStorage.swift
//  
//
//  Created by Michal Fousek on 21.05.2023.
//

import Foundation

actor InternalSyncProgressDiskStorage {
    private let storageURL: URL
    private let logger: Logger
    init(storageURL: URL, logger: Logger) {
        self.storageURL = storageURL
        self.logger = logger
    }

    private func fileURL(for key: String) -> URL {
        return storageURL.appendingPathComponent(key)
    }
}

extension InternalSyncProgressDiskStorage: InternalSyncProgressStorage {
    /// - If object on the file system at `generalStorageURL` exists and it is directory then do nothing.
    /// - If object on the file system at `generalStorageURL` exists and it is file then throw error. Because `generalStorageURL` should be directory.
    /// - If object on the file system at `generalStorageURL` doesn't exists then create directory at this URL. And set `isExcludedFromBackup` URL
    ///   flag to prevent backup of the progress information to system backup.
    func initialize() async throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: storageURL.pathExtension, isDirectory: &isDirectory)

        if exists && !isDirectory.boolValue {
            throw ZcashError.initializerGeneralStorageExistsButIsFile(storageURL)
        } else if !exists {
            do {
                try fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
            } catch {
                throw ZcashError.initializerGeneralStorageCantCreate(storageURL, error)
            }

            do {
                // Prevent from backing up progress information to system backup.
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                var generalStorageURL = storageURL
                try generalStorageURL.setResourceValues(resourceValues)
            } catch {
                throw ZcashError.initializerCantSetNoBackupFlagToGeneralStorageURL(storageURL, error)
            }
        }
    }

    func bool(for key: String) async throws -> Bool {
        let fileURL = self.fileURL(for: key)
        do {
            return try Data(contentsOf: fileURL).toBool()
        } catch {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                return false
            } else {
                throw ZcashError.ispStorageCantLoad(fileURL, error)
            }
        }
    }

    func integer(for key: String) async throws -> Int {
        let fileURL = self.fileURL(for: key)
        do {
            return try Data(contentsOf: fileURL).toInt()
        } catch {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                return 0
            } else {
                throw ZcashError.ispStorageCantLoad(fileURL, error)
            }
        }
    }

    func set(_ value: Int, for key: String) async throws {
        let fileURL = self.fileURL(for: key)
        do {
            try value.toData().write(to: fileURL, options: [.atomic])
        } catch {
            throw ZcashError.ispStorageCantWrite(fileURL, error)
        }
    }

    func set(_ value: Bool, for key: String) async throws {
        let fileURL = self.fileURL(for: key)
        do {
            try value.toData().write(to: fileURL, options: [.atomic])
        } catch {
            throw ZcashError.ispStorageCantWrite(fileURL, error)
        }
    }
}
