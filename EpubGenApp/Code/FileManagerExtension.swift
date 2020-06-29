//
//  FileManagerExtension.swift
//  EpubGenApp
//
//  Created by Stanislav Shemiakov on 29.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation

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
    
}
