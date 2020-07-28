//
//  FileManagerExtension.swift
//  EpubGenApp
//
//  Created by Stanislav Shemiakov on 29.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation
import AVFoundation

extension FileManager {
    
    func directoryExists(atPath path: String) -> Bool {
        var isDir: ObjCBool = ObjCBool(false)
        if fileExists(atPath: path, isDirectory: &isDir) {
            return isDir.boolValue
        }
        return false
    }
    
    func fileNotDirectoryExists(atPath path: String) -> Bool {
        var isDir: ObjCBool = ObjCBool(false)
        if fileExists(atPath: path, isDirectory: &isDir) {
            return !isDir.boolValue
        }
        return false
    }
    
    func removeIfExists(at url: URL) {
        guard fileExists(atPath: url.path) else { return }
        do {
            try removeItem(at: url)
        } catch {
            print("removeIfExists error:", error)
            print(" ")
        }
    }
    
    func createFile(from string: String,
                    directoryURL url: URL,
                    name: String,
                    fileExtension: String? = nil) throws {
        var url = url.appendingPathComponent(name)
        if let fileExtension = fileExtension {
            url = url.appendingPathExtension(fileExtension)
        }
        let data = Data(string.utf8)
        let created = createFile(atPath: url.path,
                                 contents: data,
                                 attributes: nil)
        if !created {
            throw "Failed to create a file at \(url)"
        }
    }
    
    func duration(for url: URL) throws -> TimeInterval {
        guard fileNotDirectoryExists(atPath: url.path) else {
            throw "duration: \(url) is missing"
        }
        guard url.pathExtension == "mp3" else {
            throw "duration: \(url) expected to be .mp3"
        }
        let asset = AVURLAsset(url: url)
        return Double(CMTimeGetSeconds(asset.duration))
    }
    
    func files(inDirectory url: URL?) -> [URL] {
        guard let url = url else { return [] }
        do {
            let files = try contentsOfDirectory(at: url,
                                                includingPropertiesForKeys: nil,
                                                options: [.skipsHiddenFiles,
                                                          .skipsSubdirectoryDescendants,
                                                          .skipsPackageDescendants])
            return files.filter { fileNotDirectoryExists(atPath: $0.path) }
        } catch {
            print("files in directory error:", error)
            return []
        }
    }
    
}
