//
//  HTMLExtension.swift
//  EpubGenApp
//
//  Created by Stanislav Shemiakov on 04.08.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation
import SwiftSoup

extension Element {
    
    func previousElements() throws -> [Element] {
        var previousElements: [Element] = []
        var current = self
        while let previous = try current.previousElementSibling() {
            previousElements.append(previous)
            current = previous
        }
        if let parent = parent() {
            return try parent.previousElements() + previousElements
        }
        return previousElements
    }
    
    func previousText() throws -> NSString {
        let previous = try previousElements()
        let previousText: NSMutableString = ""
        for element in previous {
            if let text = try? element.attributedString() {
                previousText.append(text.string)
            }
        }
        return previousText
    }
    
    func textLocation() throws -> Int {
        return try previousText().length
    }
    
    func textLength() throws -> Int {
        let text = try attributedString()
        return text.mutableString.length
    }
    
    func textRange() throws -> NSRange {
        return NSRange(location: try textLocation(), length: try textLength())
    }
    
    func attributedString() throws -> NSMutableAttributedString {
        var html = try outerHtml()
        if !(html.lowercased().contains("<?xml ") && html.lowercased().contains("encoding=\"utf-8\"")) {
            html = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\(html)"
        }
        return try html.attributedFromHTML()
    }
    
    func generateTextLocation() throws {
        try attr("textLocation", try textLocation().description)
    }
    
    func generateTextLength() throws {
        try attr("textLength", try textLength().description)
    }
    
    func generateTextRange() throws {
        try generateTextLocation()
        try generateTextLength()
    }
    
}
