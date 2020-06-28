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
    
    let paragraphURL: URL = Bundle.main.url(forResource: "paragraph", withExtension: "xhtml")!
    let simpleURL: URL = Bundle.main.url(forResource: "simple", withExtension: "xhtml")!
    
    var inputContents: String {
        return try! String(contentsOf: paragraphURL)
    }
    
    var output: String {
        return output(input: inputContents)
    }
    
    func output(input: String) -> String {
        do {
            return try getOutput(input: input)
        } catch {
            return "\(error)"
        }
    }
    
    private func getOutput(input: String?) throws -> String {
        guard var input = input else {
            throw "input missing"
        }
        input = removeUnwantedWhitespaces(in: input)
        let document = try SwiftSoup.parse(input)
        let coloredClasses = try findColoredClasses(in: document)
        let coloredElements = try findColoredElements(for: coloredClasses, in: document)
        
        try identify(elements: coloredElements)
        try eraseColors(in: document)
        
        var output = try hyphenate(document, with: .softHyphen)
        output = removeUnwantedWhitespaces(in: output)
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
        let coloredSpans = try document.selectTextElements().compactMap { (span) -> ColoredSpan? in
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
        if !currentGroup.isEmpty, !currentColor.isEmpty {
            coloredGroups.append(ColoredGroup(coloredSpans: currentGroup, color: currentColor))
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
        guard let firstChild = matchingChildren.first else {
            throw "Can't find first child"
        }
        let insertionIndex = firstChild.siblingIndex
        for child in matchingChildren {
            try parent.removeChild(child)
        }
        let wrappingSpan = Element(Tag("span"), parent.getBaseUri())
        try wrappingSpan.addChildren(Array(matchingChildren))
        try parent.addChildren(insertionIndex, wrappingSpan)
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
        let replacementPairs: [(String, String)]
        replacementPairs = [(";background-color:#[a-fA-F0-9]{6};", ";"),
                            ("\\{background-color:#[a-fA-F0-9]{6};", "{"),
                            (";background-color:#[a-fA-F0-9]{6}", ""),
                            ("background-color:#[a-fA-F0-9]{6}", "")]
        var newData = data
        for (pattern, replacement) in replacementPairs {
            newData = newData.replacingOccurrences(of: pattern,
                                                   with: replacement,
                                                   options: .regularExpression)
        }
        style.setWholeData(newData)
    }
    
    private func hyphenate(_ document: Document,
                           with hyphen: String = .softHyphen,
                           locale: Locale = Locale(identifier: "uk-ua")) throws -> String {
        let textElements = try document.selectTextElements()
        var output = try document.xhtml()
        var searchRange = output.range
        var hyphenationRanges: [(String, String, Range<String.Index>)] = []
        for element in textElements {
            guard element.hasText() else {
                continue
            }
            let text = element.ownText()
            if text.isEmpty {
                continue
            }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            guard let range = output.range(of: text,
                                           range: searchRange,
                                           locale: locale) else
            {
                throw "couldn't find '\(text)' in document!"
            }
            searchRange = Range(uncheckedBounds: (lower: range.upperBound, upper: searchRange.upperBound))
            guard let hyphenatedText = try? text.hyphenated(with: hyphen, locale: locale) else {
                continue
            }
            hyphenationRanges.append((text, hyphenatedText, range))
        }
        for (text, hyphenatedText, range) in hyphenationRanges.reversed() {
            output = output.replacingOccurrences(of: text,
                                                 with: hyphenatedText,
                                                 range: range)
        }
        return output
    }
    
    private func removeUnwantedWhitespaces(in input: String) -> String {
        
        func getReplacementPairs(for tag: String) -> [(String, String)] {
            return [(">(\\n+)(\\s*)<\(tag)",   "\n$2><\(tag)"),
                    ("</\(tag)>(\\n+)(\\s*)<", "</\(tag)\n$2><"),
                    ("([^\\s])><\(tag)",       "$1\n><\(tag)"),
                    ("</\(tag)><", "</\(tag)\n><")]
        }
        
        let tags = ["span", "sup", "a"]
        var replacementPairs: [(String, String)] = []
        for tag in tags {
            replacementPairs.append(contentsOf: getReplacementPairs(for: tag))
        }
        var output = input
        for (pattern, replacement) in replacementPairs {
            output = output.replacingOccurrences(of: pattern,
                                                 with: replacement,
                                                 options: .regularExpression)
        }
        return output
    }
    
}

extension Document {
    
    func selectTextElements() throws -> Elements {
        return try select("span, sup, a")
    }
    
    func xhtml() throws -> String {
        var output = try html()
        let replacementPairs: [(String, String)]
        replacementPairs = [("<!--\\?xml version=\"([0-9.]+)\" encoding=\"([a-zA-Z0-9-]+)\"\\?-->\\n?",
                             "<?xml version=\"$1\" encoding=\"UTF-8\"?>"),
                            ("<meta charset=\"([a-zA-Z0-9-]+)\">", "<meta charset=\"UTF-8\"/>"),
                            ("<hr class=\"([a-zA-Z0-9-]+)\">", "<hr class=\"$1\"/>"),
                            ("&amp;", "&"),
                            ("&shy;", String.softHyphen),
                            ("&quot;", "\""),
                            ("&nbsp;", "\u{00A0}"),
                            ("&lt;", "<"),
                            ("&gt;", ">"),
                            ("&sect;", "§"),
                            ("&copy;", "©"),
                            ("&laquo;", "«"),
                            ("&raquo;", "»"),
                            ("&reg;", "®"),
                            ("&iexcl;", "¡"),
                            ("&cent;", "¢"),
                            ("&pound;", "£"),
                            ("&curren;", "¤"),
                            ("&yen;", "¥"),
                            ("&brvbar;", "¦"),
                            ("&uml;", "¨"),
                            ("&ordf;", "ª"),
                            ("&not;", "¬"),
                            ("&macr;", "¯"),
                            ("&deg;", "°"),
                            ("&plusmn;", "±"),
                            ("&sup2;", "²"),
                            ("&sup3;", "³"),
                            ("&acute;", "´"),
                            ("&micro;", "µ"),
                            ("&para;", "¶"),
                            ("&middot;", "·"),
                            ("&cedil;", "¸"),
                            ("&sup1;", "¹"),
                            ("&ordm;", "º"),
                            ("&frac14;", "¼"),
                            ("&frac12;", "½"),
                            ("&frac34;", "¾"),
                            ("&iquest;", "¿"),
                            ("&times;", "×"),
                            ("&divide;", "÷"),
                            ("&ETH;", "Ð"),
                            ("&eth;", "ð"),
                            ("&THORN;", "Þ"),
                            ("&thorn;", "þ"),
                            ("&AElig;", "Æ"),
                            ("&aelig;", "æ"),
                            ("&OElig;", "Œ"),
                            ("&oelig;", "œ"),
                            ("&Aring;", "Å"),
                            ("&Oslash;", "Ø"),
                            ("&Ccedil;", "Ç"),
                            ("&ccedil;", "ç"),
                            ("&szlig;", "ß"),
                            ("&Ntilde;", "Ñ"),
                            ("&ntilde;", "ñ")]
        for (pattern, replacement) in replacementPairs {
            output = output.replacingOccurrences(of: pattern,
                                                 with: replacement,
                                                 options: .regularExpression)
        }
        return output
    }
    
}
