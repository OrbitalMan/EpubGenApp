//
//  ViewController.swift
//  EpubGenApp
//
//  Created by Stanislav on 16.06.2020.
//  Copyright © 2020 OrbitApp. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var inputEpubFolderPickerField: NSTextField!
    @IBOutlet weak var inputAudioFilePickerField: NSTextField!
    @IBOutlet weak var inputTimingFilePickerField: NSTextField!
    @IBOutlet weak var inputTimingOffsetField: NSTextField!
    @IBOutlet weak var outputFileNameField: NSTextField!
    @IBOutlet weak var outputTitleField: NSTextField!
    @IBOutlet weak var composeButton: NSButton!
    
    var inputEpubFolderURL: URL? {
        didSet {
            inputEpubFolderPickerField.stringValue = inputEpubFolderURL?.path ?? ""
            outputFileName = inputEpubFolderURL?.lastPathComponent
        }
    }
    
    var inputAudioFileURL: URL? {
        didSet {
            inputAudioFilePickerField.stringValue = inputAudioFileURL?.path ?? ""
        }
    }
    
    var inputTimingFileURL: URL? {
        didSet {
            inputTimingFilePickerField.stringValue = inputTimingFileURL?.path ?? ""
        }
    }
    
    var outputFileName: String? {
        get {
            let fileName = outputFileNameField?.stringValue ?? ""
            if fileName.isEmpty { return nil }
            return fileName
        } set {
            outputFileNameField?.stringValue = newValue ?? ""
        }
    }
    
    var outputTitle: String? {
        get {
            let title = outputTitleField?.stringValue ?? ""
            if title.isEmpty { return nil }
            return title
        } set {
            outputTitleField?.stringValue = newValue ?? ""
        }
    }
    
    let fileManager = FileManager.default
    lazy var epubComposer = EpubComposer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func enteredInputEpubFolder(_ sender: Any) {
        if inputEpubFolderPickerField.stringValue.isEmpty {
            return
        }
        let url = URL(fileURLWithPath: inputEpubFolderPickerField.stringValue, isDirectory: true)
        if fileManager.directoryExists(atPath: url.path) {
            inputEpubFolderURL = url
        } else {
            inputEpubFolderURL = inputEpubFolderURL?.absoluteURL
        }
    }
    
    @IBAction func browseInputEpubFolder(_ sender: Any) {
        let inputFolderPicker = NSOpenPanel()
        inputFolderPicker.title                   = inputEpubFolderPickerField.placeholderString
        inputFolderPicker.showsResizeIndicator    = true
        inputFolderPicker.showsHiddenFiles        = false
        inputFolderPicker.allowsMultipleSelection = false
        inputFolderPicker.canChooseDirectories    = true
        inputFolderPicker.canChooseFiles          = false
        
        let pickerResponse = inputFolderPicker.runModal()
        if pickerResponse == .OK {
            if let url = inputFolderPicker.url {
                inputEpubFolderURL = url
            }
        } else {
            // print("inputFolderPicker response:", pickerResponse)
        }
    }
    
    @IBAction func enteredInputAudioFile(_ sender: Any) {
        let url = URL(fileURLWithPath: inputAudioFilePickerField.stringValue, isDirectory: false)
        if fileManager.fileNotDirectoryExists(atPath: url.path) {
            inputAudioFileURL = url
        } else {
            inputAudioFileURL = inputAudioFileURL?.absoluteURL
        }
    }
    
    @IBAction func browseInputAudioFile(_ sender: Any) {
        let inputAudioFilePicker = NSOpenPanel()
        inputAudioFilePicker.title                   = inputAudioFilePickerField.placeholderString
        inputAudioFilePicker.showsResizeIndicator    = true
        inputAudioFilePicker.showsHiddenFiles        = false
        inputAudioFilePicker.allowsMultipleSelection = false
        inputAudioFilePicker.canChooseDirectories    = false
        inputAudioFilePicker.canChooseFiles          = true
        inputAudioFilePicker.allowedFileTypes        = ["mp3"]
        
        let pickerResponse = inputAudioFilePicker.runModal()
        if pickerResponse == .OK {
            if let url = inputAudioFilePicker.url {
                inputAudioFileURL = url
            }
        } else {
            // print("inputAudioFilePicker response:", pickerResponse)
        }
    }
    
    @IBAction func enteredInputTimingFile(_ sender: Any) {
        let url = URL(fileURLWithPath: inputTimingFilePickerField.stringValue, isDirectory: false)
        if fileManager.fileNotDirectoryExists(atPath: url.path) {
            inputTimingFileURL = url
        } else {
            inputTimingFileURL = inputTimingFileURL?.absoluteURL
        }
    }
    
    @IBAction func browseInputTimingFile(_ sender: Any) {
        let inputTimingFilePicker = NSOpenPanel()
        inputTimingFilePicker.title                   = inputTimingFilePickerField.placeholderString
        inputTimingFilePicker.showsResizeIndicator    = true
        inputTimingFilePicker.showsHiddenFiles        = false
        inputTimingFilePicker.allowsMultipleSelection = false
        inputTimingFilePicker.canChooseDirectories    = false
        inputTimingFilePicker.canChooseFiles          = true
        
        let pickerResponse = inputTimingFilePicker.runModal()
        if pickerResponse == .OK {
            if let url = inputTimingFilePicker.url {
                inputTimingFileURL = url
            }
        } else {
            // print("inputTimingFilePicker response:", pickerResponse)
        }
    }
    
    @IBAction func composeEpub(_ sender: Any) {
        do {
            try epubComposer.compose(inputEpubFolderURL: inputEpubFolderURL,
                                     inputAudioFileURL: inputAudioFileURL,
                                     inputTimingFileURL: inputTimingFileURL,
                                     inputTimingOffset: inputTimingOffsetField.doubleValue,
                                     outputFileName: outputFileName,
                                     outputTitle: outputTitle)
        } catch {
            view.window?.shake()
            print("composeEpub error:", error)
            print(" ")
        }
    }
    
}

extension NSWindow {
    
    func shake(times: Int = 3,
               with offset: CGFloat = 8,
               duration: Double = 0.6) {
        let frame = self.frame
        let shakeAnimation = CAKeyframeAnimation()
        
        let shakePath = CGMutablePath()
        shakePath.move(to: CGPoint(x: NSMinX(frame), y: NSMinY(frame)))
        
        for _ in 0...times-1 {
            shakePath.addLine(to: CGPoint(x: NSMinX(frame) - offset, y: NSMinY(frame)))
            shakePath.addLine(to: CGPoint(x: NSMinX(frame) + offset, y: NSMinY(frame)))
        }
        
        shakePath.closeSubpath()
        shakeAnimation.path = shakePath
        shakeAnimation.duration = duration
        
        animations = [NSAnimatablePropertyKey("frameOrigin") : shakeAnimation]
        animator().setFrameOrigin(NSPoint(x: frame.minX, y: frame.minY))
    }
    
}
