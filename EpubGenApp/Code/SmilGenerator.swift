//
//  SmilGenerator.swift
//  EpubGenApp
//
//  Created by Stanislav on 16.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation

struct SmilGenerator {
    
    struct Output {
        let string: String
        let parsCount: Int
    }
    
    let inputURL: URL = {
        Bundle.main.url(forResource: "timings", withExtension: "txt")!
    }()
    
    var inputContents: String {
        return try! String(contentsOf: inputURL)
    }
    
    var output: String {
        return smil(from: inputContents,
                    textPath: "paragraph_1_2.xhtml",
                    audioPath: "../Audio/paragraph_1_2.mp3",
                    offset: nil).string
    }
    
    func smil(from audacityString: String,
              textPath: String,
              audioPath: String,
              offset: TimeInterval?) -> Output {
        let audacityLines = audacityString.components(separatedBy: .newlines)
        var timeStamps: [TimeInterval] = []
        for line in audacityLines {
            let stamps = line.components(separatedBy: .whitespaces).compactMap(TimeInterval.init)
            guard let begin = stamps[safe: 0], let end = stamps[safe: 1] else {
                continue
            }
            timeStamps.append(begin)
            timeStamps.append(end)
        }
        timeStamps = Array(Set(timeStamps))
        if !timeStamps.contains(0) {
            timeStamps.insert(0, at: 0)
        }
        timeStamps.sort()
        if let offset = offset, offset != 0 {
            timeStamps = timeStamps.map { max(0, $0+offset) }
        }
        let smilStampStrings = timeStamps.map(smilString)
        var smilString = smilHeader(textPath: textPath)
        var parsCount = 0
        if smilStampStrings.isEmpty {
            return Output(string: smilString+smilFooter(), parsCount: parsCount)
        }
        for index in 0..<smilStampStrings.count-1 {
            let parId = String(format: "%06d", index+1)
            let begin = smilStampStrings[index]
            let end = smilStampStrings[index+1]
            let paragraph = """
            <par id=\"p\(parId)\"><text src="\(textPath)#f\(parId)"/>
            <audio clipBegin="\(begin)" clipEnd="\(end)" src="\(audioPath)"/>
            </par>
            
            """
            smilString.append(paragraph)
            parsCount += 1
        }
        return Output(string: smilString+smilFooter(), parsCount: parsCount)
    }
    
    func smilHeader(textPath: String) -> String {
        return """
        <?xml version="1.0" encoding="utf-8" ?>
        <smil version="3.0" xmlns="http://www.w3.org/ns/SMIL" xmlns:epub="http://www.idpf.org/2007/ops">
        <body>
        <seq epub:textref="\(textPath)" epub:type="bodymatter chapter" id="seq1">
        
        """
    }
    
    func smilString(from interval: TimeInterval) -> String {
        let date = Date(timeIntervalSinceReferenceDate: interval)
        return DateFormatter.smilFormatter.string(from: date)
    }
    
    func smilFooter() -> String {
        return """
        </seq>
        </body>
        </smil>
        
        """
    }
    
}

extension DateFormatter {
    
    static let smilReferenceDate = Date(timeIntervalSinceReferenceDate: 0)
    
    static let smilFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.defaultDate = smilReferenceDate
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "H:mm:ss.SSS"
        return dateFormatter
    }()
    
    static let packageFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.defaultDate = smilReferenceDate
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        return dateFormatter
    }()
    
}

