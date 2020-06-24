//
//  ViewController.swift
//  EpubGenApp
//
//  Created by Stanislav on 16.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Cocoa

enum TimingType: String, CaseIterable {
    case smil = "SMIL"
    case srt = "SRT"
}

class ViewController: NSViewController {
    
    @IBOutlet weak var xhtmlInput: NSTextView!
    @IBOutlet weak var timingTypePicker: NSPopUpButton!
    @IBOutlet weak var smilTextSourceInput: NSTextField!
    @IBOutlet weak var smilAudioSourceInput: NSTextField!
    @IBOutlet weak var timingOffsetInput: NSTextField!
    @IBOutlet weak var timingInput: NSTextView!
    @IBOutlet weak var xhtmlOutput: NSTextView!
    @IBOutlet weak var timingOutput: NSTextView!
    
    var allTextViews: [NSTextView] {
        return [xhtmlInput,
                xhtmlOutput,
                timingInput,
                timingOutput].compactMap { $0 }
    }
    
    var allTextFields: [NSTextField] {
        return [smilTextSourceInput,
                smilAudioSourceInput,
                timingOffsetInput].compactMap { $0 }
    }
    
    var timingType: TimingType {
        guard let selectedItemTitle = timingTypePicker?.titleOfSelectedItem else { return .smil }
        return TimingType(rawValue: selectedItemTitle) ?? .smil
    }
    
    lazy var spanGenerator = ColoredSpanGenerator()
    lazy var smilGenerator = SmilGenerator()
    lazy var srtGenerator = SRTGenerator()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        for textView in allTextViews {
            textView.typingAttributes[.font] = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textView.typingAttributes[.foregroundColor] = NSColor.labelColor
            textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textView.delegate = self
        }
        for textField in allTextFields {
            textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textField.delegate = self
        }
        xhtmlOutput.string = spanGenerator.output
        timingOutput.string = smilGenerator.output
    }
    
    @IBAction func timingTypePicked(_ sender: NSPopUpButton) {
        switch timingType {
        case .smil:
            smilTextSourceInput.isEnabled = true
            smilAudioSourceInput.isEnabled = true
        case .srt:
            smilTextSourceInput.isEnabled = false
            smilAudioSourceInput.isEnabled = false
        }
        updateTiming()
    }
    
    func updateTiming() {
        switch timingType {
        case .smil:
            updateSmil()
        case .srt:
            updateSRT()
        }
    }
    
    func updateSmil() {
        timingOutput.string = smilGenerator.smil(from: timingInput.string,
                                                 textPath: smilTextSourceInput.stringValue,
                                                 audioPath: smilAudioSourceInput.stringValue,
                                                 offset: timingOffsetInput.doubleValue)
    }
    
    func updateSRT() {
        timingOutput.string = srtGenerator.srt(from: timingInput.string,
                                               offset: timingOffsetInput.doubleValue)
    }
    
}

extension ViewController: NSTextViewDelegate {
    
    func textDidChange(_ notification: Notification) {
        switch notification.object as? NSTextView {
        case xhtmlInput:
            xhtmlOutput.string = (try? spanGenerator.output(input: xhtmlInput.string)) ?? ""
        case timingInput:
            updateTiming()
        default:
            break
        }
    }
    
}

extension ViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ obj: Notification) {
        guard
            let textField = obj.object as? NSTextField,
            allTextFields.contains(textField) else
        {
            return
        }
        updateTiming()
    }
    
}
