//
//  SmilGenerator.swift
//  EpubGenApp
//
//  Created by Stanislav on 16.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation

struct SmilGenerator {
    
    let inputURL: URL = {
        Bundle.main.url(forResource: "timings", withExtension: "txt")!
    }()
    
    var inputContents: String {
        return try! String(contentsOf: inputURL)
    }
    
    var output: String {
        return smil(from: inputContents,
                    textPath: "paragraph_1_2.xhtml",
                    audioPath: "../Audio/paragraph_1_2.mp3")
    }
    
    func smil(from audacityString: String,
              textPath: String,
              audioPath: String) -> String {
        let timeStamps = audacityString.components(separatedBy: .whitespacesAndNewlines).compactMap(TimeInterval.init)
        let sortedTimeStamps = Array(Set(timeStamps)).sorted()
        let smilStamps = sortedTimeStamps.map(smilString)
        var smil = """
        <?xml version="1.0" encoding="utf-8" ?>
        <smil version="3.0" xmlns="http://www.w3.org/ns/SMIL" xmlns:epub="http://www.idpf.org/2007/ops">
        <body>
        <seq epub:textref="\(textPath)" epub:type="bodymatter chapter" id="seq1">
        
        """
        let smilFooter = """
        </seq>
        </body>
        </smil>
        
        """
        if smilStamps.isEmpty {
            return smil+smilFooter
        }
        for index in 0..<smilStamps.count-1 {
            let parId = String(format: "%06d", index+1)
            let begin = smilStamps[index]
            let end = smilStamps[index+1]
            let paragraph = """
            <par id=\"p\(parId)\"><text src="\(textPath)#f\(parId)"/>
            <audio clipBegin="\(begin)" clipEnd="\(end)" src="\(audioPath)"/>
            </par>
            
            """
            smil.append(paragraph)
        }
        return smil+smilFooter
    }
    
    func smilString(from interval: TimeInterval) -> String {
        let date = Date(timeIntervalSinceReferenceDate: interval)
        return DateFormatter.smilFormatter.string(from: date)
    }
    
}

extension DateFormatter {
    
    static let smilFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "H:mm:ss.SSS"
        return dateFormatter
    }()
    
}

