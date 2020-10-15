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
    
    var coloredSpans: [ColoredSpan]
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
