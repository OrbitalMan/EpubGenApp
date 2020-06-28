//
//  ColoredSpanModels.swift
//  EpubGenApp
//
//  Created by Stanislav Shemiakov on 24.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation
import SwiftSoup

class CSS {
    
    let rawClassName: String
    var data: [String: String]
    
    var rawString: String {
        return "\(rawClassName):{\(rawData)}"
    }
    
    var className: String {
        var name = rawClassName.components(separatedBy: ");").last ?? ""
        if name.starts(with: ".") {
            name.removeFirst()
        }
        return name
    }
    
    var backgroundColor: String? {
        get {
            return data["background-color"]
        } set {
            data["background-color"] = newValue
        }
    }
    
    private var rawData: String {
        var dataPairs = data.map { ($0.key, $0.value) }
        if dataPairs.isEmpty {
            return ""
        }
        let firstPair = dataPairs.removeFirst()
        var rawData = "\(firstPair.0):\(firstPair.1)"
        for (key, value) in dataPairs {
            rawData.append(";\(key):\(value)")
        }
        return rawData
    }
    
    var desc: String {
        var output = className
        let sortedData = data.sorted {  $0.key < $1.key }
        for (key, value) in sortedData {
            output.append("\n    \(key): \(value)")
        }
        output.append("\n")
        return output
    }
    
    init(rawClassName: String, data: [String : String]) {
        self.rawClassName = rawClassName
        self.data = data
    }
    
}

struct ColoredSpan {
    let span: Element
    let css: CSS
    var color: String? { css.backgroundColor }
}

struct ColoredGroup {
    
    let coloredSpans: [ColoredSpan]
    let color: String
    
    var desc: String {
        var output = "\(color) (\(coloredSpans.count))"
        for colored in coloredSpans {
            output.append("\n    \(colored.css.className) \((try? colored.span.text()) ?? "nil")")
        }
        output.append("\n")
        return output
    }
    
}

extension Array {
    
    func printElements() {
        for element in self {
            print(element)
        }
    }
    
}

extension String: Error {
    
    private func regExpDetectingSubstring(between str1: String,
                                          and str2: String) -> String {
        return "(?:\(str1))(.*?)(?:\(str2))"
    }
    
    func replacingOccurrences(from subString1: String,
                              to subString2: String,
                              with replacement: String) -> String {
        let regExpr = regExpDetectingSubstring(between: subString1,
                                               and: subString2)
        return replacingOccurrences(of: regExpr,
                                    with: replacement,
                                    options: .regularExpression)
    }
    
    func slices(from subString1: String,
                to subString2: String) -> [SubSequence] {
        let regExpr = regExpDetectingSubstring(between: subString1,
                                               and: subString2)
        let sliceRanges = ranges(of: regExpr,
                                 options: .regularExpression)
        return sliceRanges.map { self[$0] }
    }
    
    public func ranges(of searchString: String,
                       options: String.CompareOptions = [],
                       range: Range<String.Index>? = nil,
                       locale: Locale? = nil) -> [Range<String.Index>] {
        let slice = (range == nil) ? self[...] : self[range!]
        var previousEnd = slice.startIndex
        var ranges = [Range<String.Index>]()
        var sliceRange: Range<Index>? {
            return slice.range(of: searchString,
                               options: options,
                               range: previousEnd ..< slice.endIndex,
                               locale: locale)
        }
        while let newRange = sliceRange {
            if previousEnd != endIndex {
                previousEnd = index(after: newRange.lowerBound)
            }
            ranges.append(newRange)
        }
        return ranges
    }
    
    var range: Range<Index> {
        return Range<Index>(uncheckedBounds: (lower: startIndex, upper: endIndex))
    }
    
    static let softHyphen = "\u{00AD}"
    
    func hyphenated(with hyphen: String = .softHyphen,
                    locale: Locale) throws -> String {
        guard locale.isHyphenationAvailable else {
            throw "Hyphenation isn't available for '\(locale.identifier)' locale"
        }
        let string: NSMutableString = NSMutableString(string: self)
        var hyphenationLocations = [CUnsignedChar](repeating: 0, count: Int(string.length))
        let range: CFRange = CFRangeMake(0, string.length)
        let cfLocale = locale as CFLocale
        for i in 0..<string.length {
            let location = CFStringGetHyphenationLocationBeforeIndex(string, i, range, 0, cfLocale, nil)
            if(location >= 0 && location < string.length)
            {
                hyphenationLocations[location] = 1;
            }
        }
        for i in (0..<string.length).reversed() {
            if hyphenationLocations[i] > 0 {
                string.insert(hyphen, at: i)
            }
        }
        return string as String
    }
    
}

extension Locale {
    
    var isHyphenationAvailable: Bool {
        return CFStringIsHyphenationAvailableForLocale(self as CFLocale)
    }
    
}

