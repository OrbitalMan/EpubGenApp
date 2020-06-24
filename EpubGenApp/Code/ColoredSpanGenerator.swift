//
//  ColoredSpanGenerator.swift
//  EpubGenApp
//
//  Created by Stanislav Shemiakov on 23.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation
import SwiftSoup

struct ColoredSpanGenerator {
    
    let inputURL: URL = Bundle.main.url(forResource: "paragraph", withExtension: "xhtml")!
    
    var inputContents: String {
        return try! String(contentsOf: inputURL)
    }
    
    var output: String {
        return (try? output(input: inputContents)) ?? ""
    }
    
    func output(input: String?) throws -> String {
        guard let input = input else {
            throw "input missing"
        }
        let document = try SwiftSoup.parse(input)
        let coloredClasses = try findColoredClasses(in: document)
        let coloredElements = try findColoredElements(for: coloredClasses, in: document)
        
        try identify(elements: coloredElements)
        try eraseColors(in: document)
        
        var output = try document.html()
        output = removeUnwantedWhitespaces(in: output)
        output = convertToXHTML(output)
        return output
    }
    
    private func findStyleElement(in document: Document) throws -> DataNode {
        guard let head = document.head() else {
            throw "head is missing"
        }
        let styles = try head.select("style")
        guard let style = styles.first()?.dataNodes().first else {
            throw "style is missing"
        }
        return style
    }
    
    private func findColoredClasses(in document: Document) throws -> [CSS] {
        let styleData = try findStyleElement(in: document).getWholeData()
        let allClasses = try parseCSS(input: styleData)
        return allClasses.filter { $0.backgroundColor != nil && $0.backgroundColor != "#ffffff" }
    }
    
    private func parseCSS(input: String) throws -> [CSS] {
        let commentsExcluded = input.replacingOccurrences(from: "<!--", to: "-->", with: "")
        let whiteSpacesExcluded = commentsExcluded.filter { !($0.isWhitespace || $0.isNewline) }
        let rawSelectors = whiteSpacesExcluded.slices(from: "\\{", to: "\\}").map { String($0) }
        var remainderToParse = whiteSpacesExcluded
        var selectors = [CSS]()
        for rawData in rawSelectors {
            var rawComponents = remainderToParse.components(separatedBy: rawData)
            guard rawComponents.count > 1 else {
                break
            }
            let rawKey = rawComponents.removeFirst()
            remainderToParse = rawComponents.joined(separator: rawData)
            var data: [String: String] = [:]
            let trimmedData = String(rawData.dropFirst().dropLast())
            let rawDataPairs = trimmedData.components(separatedBy: ";")
            let keyValueSeparator = ":"
            for rawDataPair in rawDataPairs {
                var dataComponents = rawDataPair.components(separatedBy: keyValueSeparator)
                guard dataComponents.count > 0 else {
                    break
                }
                let key = dataComponents.removeFirst()
                data[key] = dataComponents.joined(separator: keyValueSeparator)
            }
            let newSelector = CSS(rawClassName: rawKey, data: data)
            selectors.append(newSelector)
        }
        return selectors
    }
    
    private func findColoredElements(for coloredClasses: [CSS],
                             in document: Document) throws -> [Element] {
        let coloredSpans = try document.select("span, sup").compactMap { (span) -> ColoredSpan? in
            let spanClasses = try span.classNames()
            for colored in coloredClasses {
                if spanClasses.contains(colored.className) {
                    return ColoredSpan(span: span, css: colored)
                }
            }
            return nil
        }
        
        var coloredGroups: [ColoredGroup] = []
        var currentColor = ""
        var currentGroup: [ColoredSpan] = []
        for colored in coloredSpans {
            if colored.color == currentColor {
                currentGroup.append(colored)
            } else if let newColor = colored.color {
                if !currentGroup.isEmpty, !currentColor.isEmpty {
                    coloredGroups.append(ColoredGroup(coloredSpans: currentGroup, color: currentColor))
                }
                currentColor = newColor
                currentGroup = [colored]
            }
        }
        
        let wrappedSpans = try coloredGroups.compactMap(wrapIfNeeded(group:))
        return wrappedSpans
    }
    
    private func wrapIfNeeded(group: ColoredGroup) throws -> Element? {
        if group.coloredSpans.isEmpty {
            return nil
        }
        if  group.coloredSpans.count == 1,
            let coloredSpan = group.coloredSpans.first
        {
            return coloredSpan.span
        }
        let spans = group.coloredSpans.map { $0.span }
        let (parent, matchingChildren) = try findCommonParent(of: spans)
        guard
            let firstChild = matchingChildren.first,
            let firstIndex = parent.children().firstIndex(of: firstChild) else
        {
            throw "Can't find first child"
        }
        for child in matchingChildren {
            try parent.removeChild(child)
        }
        let wrappingSpan = Element(Tag("span"), parent.getBaseUri())
        try wrappingSpan.addChildren(Array(matchingChildren))
        try parent.addChildren(firstIndex, wrappingSpan)
        return wrappingSpan
    }
    
    private func findCommonParent(of elements: [Element]) throws -> (Element, [Element]) {
        if elements.isEmpty {
            throw "elements are empty"
        }
        let parents: OrderedSet<Element> = []
        for element in elements {
            guard let parent = element.parent() else {
                throw "parent missing for \(element)"
            }
            parents.append(parent)
        }
        if parents.count == 1, let parent = parents.first {
            let allChildren = parent.children()
            guard
                let firstChild = elements.first,
                let lastChild = elements.last,
                let firstIndex = allChildren.firstIndex(of: firstChild),
                let lastIndex = allChildren.firstIndex(of: lastChild) else
            {
                throw "no matching children found"
            }
            let matchingChildren = allChildren[firstIndex...lastIndex]
            return (parent, Array(matchingChildren))
        }
        return try findCommonParent(of: Array(parents))
    }
    
    private func identify(elements: [Element]) throws {
        for index in elements.indices {
            let element = elements[index]
            let fragmentId = String(format: "f%06d", index+1)
            try element.attr("id", fragmentId)
        }
    }
    
    private func eraseColors(in document: Document) throws {
        let style = try findStyleElement(in: document)
        let data = style.getWholeData()
        let replacementPairs: [(String, String)] = [("^;background-color:#[a-fA-F0-9]{6};", ";"),
                                                    ("background-color:#[a-fA-F0-9]{6};", ""),
                                                    (";background-color:#[a-fA-F0-9]{6}", ""),
                                                    ("background-color:#[a-fA-F0-9]{6}", "")]
        var newData = data
        for (regExp, replacement) in replacementPairs {
            newData = newData.replacingOccurrences(of: regExp,
                                                   with: replacement,
                                                   options: .regularExpression)
        }
        style.setWholeData(newData)
    }
    
    private func removeUnwantedWhitespaces(in input: String) -> String {
        var output = input
        
        output = output.replacingOccurrences(of: ">(\\s*)\\n(\\s*)<span",
                                             with: "\n$2><span",
                                             options: .regularExpression)
        output = output.replacingOccurrences(of: "</span>(\\s*)\\n(\\s*)<",
                                             with: "</span\n$2><",
                                             options: .regularExpression)
        
        output = output.replacingOccurrences(of: ">(\\s*)<span",
                                             with: "><span",
                                             options: .regularExpression)
        output = output.replacingOccurrences(of: "</span>(\\s*)<",
                                             with: "</span><",
                                             options: .regularExpression)
        
        output = output.replacingOccurrences(of: ">(\\s*)<sup",
                                             with: "><sup",
                                             options: .regularExpression)
        output = output.replacingOccurrences(of: "</sup>(\\s*)<",
                                             with: "</sup><",
                                             options: .regularExpression)
        
        output = output.replacingOccurrences(of: ">(\\s*)<a",
                                             with: "><a",
                                             options: .regularExpression)
        output = output.replacingOccurrences(of: "</a>(\\s*)<",
                                             with: "</a><",
                                             options: .regularExpression)
        
        return output
    }
    
    private func convertToXHTML(_ input: String) -> String {
        var output = input
        output = output.replacingOccurrences(of: "<!--?xml version=\"1.0\" encoding=\"UTF-8\"?-->\n",
                                             with: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        output = output.replacingOccurrences(of: "&nbsp;", with: " ")
        output = output.replacingOccurrences(of: "<meta charset=\"UTF-8\">",
                                             with: "<meta charset=\"UTF-8\"/>")
        output = output.replacingOccurrences(of: "<hr class=\"([a-zA-Z0-9]+)\">",
                                             with: "<hr class=\"$1\"/>",
                                             options: .regularExpression)
        return output
    }
    
}
