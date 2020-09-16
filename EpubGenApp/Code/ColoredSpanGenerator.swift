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
    
    struct Output {
        let string: String
        let spansCount: Int
    }
    
    struct TimingData {
        let inputString: String
        let offset: TimeInterval
    }
    
    func output(input: String?, title: String = "", timingData: TimingData?) throws -> Output {
        guard var input = input else {
            throw "input missing"
        }
        input = removeUnwantedWhitespaces(in: input)
        var document = try SwiftSoup.parse(input)
        if  let lists = try? document.select("ol"),
            let list = lists.first()
        {
            let text = try? list.text()
            throw "ol/li list detected at \"\(text ?? "nil")\""
        }
        if  let lists = try? document.select("ul"),
            let list = lists.first()
        {
            let text = try? list.text()
            throw "ul/li list detected at \"\(text ?? "nil")\""
        }
        let coloredClasses = try findColoredClasses(in: document)
        
        if !title.isEmpty {
            try document.title(title)
        }
        document = try hyphenate(document, with: .softHyphen)
        let coloredElements = try findColoredElements(for: coloredClasses, in: document)
        try identify(elements: coloredElements)
        try eraseColors(in: document)
        try refineLinks(in: document)
        try fixImages(in: document, rawMode: timingData != nil)
        try wrapInSection(document: document)
        
        var outputString = try document.xhtml()
        outputString = removeUnwantedWhitespaces(in: outputString)
        if let timing = timingData {
            document = try SwiftSoup.parse(outputString)
            let spans = try document.select("span")
            let cueSpans = spans.filter { $0.id().lowercased().starts(with: "f") }
            
            let smilGenerator = SmilGenerator()
            let clips = smilGenerator.parseClips(from: timing.inputString,
                                                 offset: timing.offset)
            guard cueSpans.count == clips.count else {
                throw "cueSpans (\(cueSpans.count)) != clips (\(clips.count))"
            }
            for (span, clip) in zip(cueSpans, clips) {
                let begin = rawTimeStampString(from: clip.begin)
                let end = rawTimeStampString(from: clip.end)
                try span.attr("clipBegin", begin)
                try span.attr("clipEnd", end)
            }
            
            try generateRanges(in: document, output: outputString, cueSpans: cueSpans)
            outputString = try document.xhtml()
            outputString = removeUnwantedWhitespaces(in: outputString)
        }
        return Output(string: outputString, spansCount: coloredElements.count)
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
        for colored in coloredSpans {
            if colored.color == currentColor {
                coloredGroups[coloredGroups.count - 1].coloredSpans.append(colored)
            } else if let newColor = colored.color {
                currentColor = newColor
                let group = ColoredGroup(coloredSpans: [colored], color: currentColor)
                coloredGroups.append(group)
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
    
    private func wrapInSection(document: Document) throws {
        guard let body = document.body() else {
            throw "body is missing"
        }
        guard let htmlTag = try document.select("html").first() else {
            throw "htmlTag is missing"
        }
        let children = body.children()
        guard let firstChild = children.first else {
            throw "Can't find first child"
        }
        let insertionIndex = firstChild.siblingIndex
        for child in children {
            try body.removeChild(child)
        }
        try htmlTag.attr("xmlns:epub", "http://www.idpf.org/2007/ops")
        try htmlTag.attr("lang", "uk-UA")
        try htmlTag.attr("xml:lang", "uk-UA")
        let section = Element.init(Tag("section"), body.getBaseUri())
        try section.attr("epub:type", "bodymatter chapter")
        try section.addChildren(Array(children))
        try body.addChildren(insertionIndex, section)
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
        replacementPairs = [(";background-color:\\s+#[a-fA-F0-9]{6};", ";"),
                            ("\\{background-color:\\s+#[a-fA-F0-9]{6};", "{"),
                            (";background-color:\\s+#[a-fA-F0-9]{6}", ""),
                            ("background-color:\\s+#[a-fA-F0-9]{6}", ""),
                            ("background-color:\\s+#[a-fA-F0-9]{6}", "")]
        var newData = data
        for (pattern, replacement) in replacementPairs {
            newData = newData.replacingOccurrences(of: pattern,
                                                   with: replacement,
                                                   options: .regularExpression)
        }
        style.setWholeData(newData)
    }
    
    private func refineLinks(in document: Document) throws {
        let links = try document.select("a")
        for link in links {
            if  let href = try? link.attr("href"),
                href.starts(with: "http"),
                let url = href.components(separatedBy: "q=").last?.components(separatedBy: "&").first
            {
                let refinedURL = url.replacingOccurrences(of: "%25", with: "%")
                try link.attr("href", refinedURL)
            }
        }
    }
    
    private func fixImages(in document: Document, rawMode: Bool) throws {
        let imgs = try document.select("img")
        for img in imgs {
            if let src = try? img.attr("src") {
                let fixedPath: String
                if rawMode {
                    fixedPath = ""
                } else {
                    fixedPath = "../Images/"
                }
                let fixedSrc = src.replacingOccurrences(of: "images/", with: fixedPath)
                try img.attr("src", fixedSrc)
            }
        }
        if rawMode {
            for img in imgs {
                try img.generateTextLocation()
            }
        }
    }
    
    private func hyphenate(_ document: Document,
                           with hyphen: String = .softHyphen,
                           locale: Locale = Locale(identifier: "uk-ua")) throws -> Document {
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
        return try SwiftSoup.parse(output)
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
    
    static func parseTitle(from inputEpubFolder: URL?) throws -> String {
        guard let inputEpubFolder = inputEpubFolder else {
            throw "inputEpubFolder url is missing"
        }
        let inputXHTMLFileURL = inputEpubFolder
            .appendingPathComponent("GoogleDoc")
            .appendingPathComponent(inputEpubFolder.lastPathComponent)
            .appendingPathExtension("xhtml")
        let xhtmlString = try String(contentsOf: inputXHTMLFileURL)
        let document = try SwiftSoup.parse(xhtmlString)
        guard let body = document.body() else {
            throw "body is missing"
        }
        guard let firstSpan = try body.select("span").first() else {
            throw "firstSpan is missing"
        }
        var title = try firstSpan.text()
        title = title.replacingOccurrences(of: "§ \\d+. ", with: "", options: .regularExpression)
        title = title.replacingOccurrences(of: "Тема \\d+. ", with: "", options: .regularExpression)
        if title.suffix(1) == "." {
            title = String(title.dropLast())
        }
        return title
    }
    
    func generateRanges(in document: Document,
                        output: String,
                        cueSpans: [Element]) throws {
        let text = try output.attributedFromHTML().mutableString
        var searchRange = NSRange(location: 0, length: text.length)
        
        for span in cueSpans {
            let spanText = try span.attributedString().string.trimmingCharacters(in: .whitespacesAndNewlines)
            let range = text.range(of: spanText,
                                   options: [.caseInsensitive, .diacriticInsensitive],
                                   range: searchRange)
            if range.location == NSNotFound {
                throw "\ngenerateRanges: span\n'\(spanText)'\ntext not found in\n'\(text.substring(with: searchRange).prefix(1000))'\n"
            }
            let location = NSMaxRange(range)
            searchRange = NSRange(location: location,
                                  length: text.length-location)
            try span.attr("textLocation", range.location.description)
            try span.attr("textLength", range.length.description)
        }
        
        searchRange = NSRange(location: 0, length: text.length)
        for link in try document.select("a") {
            let linkText = try link.attributedString().string
            let range = text.range(of: linkText,
                                   options: [],
                                   range: searchRange)
            if range.location == NSNotFound {
                throw "generateRanges: link '\(linkText)' text not found"
            }
            let location = NSMaxRange(range)
            searchRange = NSRange(location: location,
                                  length: text.length-location)
            try link.attr("textLocation", range.location.description)
            try link.attr("textLength", range.length.description)
        }
        
        for img in try document.select("img") {
            try img.generateTextLocation()
        }
    }
    
    func rawTimeStampString(from timestamp: TimeInterval) -> String {
        return String(format: "%.3f", timestamp)
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
                             "<?xml version=\"$1\" encoding=\"UTF-8\"?>\n"),
                            ("<meta charset=\"([a-zA-Z0-9-]+)\">", "<meta charset=\"UTF-8\"/>"),
                            ("<hr class=\"([a-zA-Z0-9-]+)\">", "<hr class=\"$1\"/>"),
                            ("<img (.+?)\">", "<img $1\"/>"),
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
