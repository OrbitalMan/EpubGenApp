//
//  SRTGenerator.swift
//  EpubGenApp
//
//  Created by Stanislav on 17.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Foundation

struct SRTGenerator {
    
    func srt(from audacityString: String, offset: TimeInterval?) -> String {
        let timeStamps = audacityString.components(separatedBy: .whitespacesAndNewlines).compactMap(TimeInterval.init)
        var sortedTimeStamps = Array(Set(timeStamps)).sorted()
        if let offset = offset, offset != 0 {
            sortedTimeStamps = sortedTimeStamps.map { max(0, $0+offset) }
        }
        let srtStamps = sortedTimeStamps.map(srtString)
        var srt = ""
        if srtStamps.isEmpty {
            return srt
        }
        for index in 0..<srtStamps.count-1 {
            let cueId = index+1
            let left = srtStamps[index]
            let right = srtStamps[index+1]
            let cue = """
            \(cueId)
            \(left) --> \(right)
            Caption text \(cueId)
            
            
            """
            srt.append(cue)
        }
        return srt
    }
    
    func srtString(from interval: TimeInterval) -> String {
        let date = Date(timeIntervalSinceReferenceDate: interval)
        return DateFormatter.srtFormatter.string(from: date)
    }
    
}

extension DateFormatter {
    
    static let srtFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "HH:mm:ss,SSS"
        return dateFormatter
    }()
    
}

