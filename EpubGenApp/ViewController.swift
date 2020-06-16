//
//  ViewController.swift
//  EpubGenApp
//
//  Created by Stanislav on 16.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var xhtmlInputView: NSTextView!
    @IBOutlet weak var smilInputTextSourceView: NSTextField!
    @IBOutlet weak var smilInputAudioSourceView: NSTextField!
    @IBOutlet weak var smilInputOffsetView: NSTextField!
    @IBOutlet weak var smilInputView: NSTextView!
    @IBOutlet weak var xhtmlOutputView: NSTextView!
    @IBOutlet weak var smilOutputView: NSTextView!
    
    var allTextViews: [NSTextView] {
        return [xhtmlInputView,
                xhtmlOutputView,
                smilInputView,
                smilOutputView].compactMap { $0 }
    }
    
    var allTextFields: [NSTextField] {
        return [smilInputTextSourceView,
                smilInputAudioSourceView,
                smilInputOffsetView].compactMap { $0 }
    }
    
    let spanEnumerator = SpanEnumerator()
    let smilGenerator = SmilGenerator()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        for textView in allTextViews {
            textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textView.delegate = self
        }
        for textField in allTextFields {
            textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textField.delegate = self
        }
        xhtmlOutputView.string = spanEnumerator.output
        smilOutputView.string = smilGenerator.output
    }
    
    func updateSmil() {
        smilOutputView.string = smilGenerator.smil(from: smilInputView.string,
                                                   textPath: smilInputTextSourceView.stringValue,
                                                   audioPath: smilInputAudioSourceView.stringValue,
                                                   offset: smilInputOffsetView.doubleValue)
    }
    
}

extension ViewController: NSTextViewDelegate {
    
    func textDidChange(_ notification: Notification) {
        switch notification.object as? NSTextView {
        case xhtmlInputView:
            xhtmlOutputView.string = spanEnumerator.output(input: xhtmlInputView.string)
        case smilInputView:
            updateSmil()
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
        updateSmil()
    }
    
}
