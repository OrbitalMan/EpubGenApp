//
//  ArrayExtension.swift
//  EpubGenApp
//
//  Created by Stanislav Shemiakov on 28.07.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation

extension Array {
    
    public subscript(safe index: Int) -> Element? {
        if indices.contains(index) {
            return self[index]
        }
        return nil
    }
    
}

