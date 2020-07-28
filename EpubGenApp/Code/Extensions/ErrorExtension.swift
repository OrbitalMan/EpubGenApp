//
//  ErrorExtension.swift
//  EpubGenApp
//
//  Created by Stanislav Shemiakov on 28.07.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation

extension String: LocalizedError {
    
    public var errorDescription: String? {
        return self
    }
    
}

extension Error {
    
    var logDescription: String {
        let localDesc = localizedDescription
        let selfDesc = "\(self)"
        if localDesc == selfDesc {
            return localDesc
        }
        return "\(localDesc)\n\(selfDesc)"
    }
    
}
