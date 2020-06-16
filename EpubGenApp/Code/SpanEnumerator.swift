//
//  SpanEnumerator.swift
//  EpubGenApp
//
//  Created by Stanislav on 16.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation

struct SpanEnumerator {
    
    let inputURL: URL = {
        Bundle.main.url(forResource: "paragraph", withExtension: "xhtml")!
    }()
    
    let defaultSpanId = "f000000"
    
    var inputContents: String {
        return try! String(contentsOf: inputURL)
    }
    
    var output: String {
        return output(input: inputContents)
    }
    
    func output(input: String) -> String {
        var spans = input.components(separatedBy: defaultSpanId)
        var output = spans.removeFirst()
        for index in spans.indices {
            let span = spans[index]
            let fragmentId = String(format: "f%06d", index+1)
            output.append("\(fragmentId)\(span)")
        }
        return output
    }
    
}
