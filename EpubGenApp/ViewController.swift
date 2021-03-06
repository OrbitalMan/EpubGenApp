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
    @IBOutlet weak var warningLabel: NSTextField!
    
    var inputEpubFolderURL: URL? {
        didSet {
            inputEpubFolderPickerField.stringValue = inputEpubFolderURL?.path ?? ""
            outputFileName = inputEpubFolderURL?.lastPathComponent
            if let parsedTitle = try? ColoredSpanGenerator.parseTitle(from: inputEpubFolderURL) {
                outputTitle = parsedTitle
            }
            inputAudioFileURL = estimatedInputAudioFileURL ?? inputMetadataURL
            inputTimingFileURL = estimatedInputTimingFileURL ?? inputMetadataURL
        }
    }
    
    var inputMetadataURL: URL? {
        guard let inputEpubFolderURL = inputEpubFolderURL else { return nil }
        let root = inputEpubFolderURL.deletingLastPathComponent()
        let metadata = root.appendingPathComponent("metadata")
        guard fileManager.directoryExists(atPath: metadata.path) else { return root }
        let paragraphMetadata = metadata.appendingPathComponent(inputEpubFolderURL.lastPathComponent)
        guard fileManager.directoryExists(atPath: paragraphMetadata.path) else { return metadata }
        return paragraphMetadata
    }
    
    var estimatedInputAudioFileURL: URL? {
        return fileManager.files(inDirectory: inputMetadataURL).first { $0.lastPathComponent.contains("_b44.mp3") }
    }
    
    var estimatedInputTimingFileURL: URL? {
        return fileManager.files(inDirectory: inputMetadataURL).first { $0.pathExtension == "txt" }
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
    
    var outputEpubFolderURL: URL? {
        guard
            let inputEpubFolderURL = inputEpubFolderURL,
            let outputFileName = outputFileName else
        {
            return nil
        }
        let outputEpubFolderURL = inputEpubFolderURL
            .deletingLastPathComponent()
            .appendingPathComponent("generated")
            .appendingPathComponent(outputFileName)
        return outputEpubFolderURL
    }
    
    var outputRawFolderURL: URL? {
        guard
            let inputEpubFolderURL = inputEpubFolderURL,
            let outputFileName = outputFileName else
        {
            return nil
        }
        let outputRawFolderURL = inputEpubFolderURL
            .deletingLastPathComponent()
            .appendingPathComponent("generated_raw")
            .appendingPathComponent(outputFileName)
        return outputRawFolderURL
    }
    
    let fileManager = FileManager.default
    lazy var epubComposer = EpubComposer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        warningLabel.stringValue = ""
        epubComposer.delegate = self
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
        inputAudioFilePicker.directoryURL            = estimatedInputAudioFileURL ?? inputMetadataURL
        
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
        inputTimingFilePicker.allowedFileTypes        = ["txt"]
        inputTimingFilePicker.directoryURL            = estimatedInputTimingFileURL ?? inputMetadataURL
        
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
        warningLabel.stringValue = "Started composing..."
        let inputEpubFolderURL = self.inputEpubFolderURL
        let inputAudioFileURL = self.inputAudioFileURL
        let inputTimingFileURL = self.inputTimingFileURL
        let inputTimingOffset = self.inputTimingOffsetField.doubleValue
        let outputFileName = self.outputFileName
        let outputTitle = self.outputTitle
        let outputEpubFolderURL = self.outputEpubFolderURL
        let outputRawFolderURL = self.outputRawFolderURL
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try self?.epubComposer.compose(inputEpubFolderURL: inputEpubFolderURL,
                                              inputAudioFileURL: inputAudioFileURL,
                                              inputTimingFileURL: inputTimingFileURL,
                                              inputTimingOffset: inputTimingOffset,
                                              outputFileName: outputFileName,
                                              outputTitle: outputTitle,
                                              outputEpubFolderURL: outputEpubFolderURL,
                                              outputRawFolderURL: outputRawFolderURL)
                DispatchQueue.main.async { [weak self] in
                    self?.warningLabel.stringValue = "\(outputFileName ?? "outputFileName") is ready!"
                }
            } catch {
                print("composeEpub error:", error)
                print(" ")
                DispatchQueue.main.async { [weak self] in
                    if  let outputEpub = outputEpubFolderURL,
                        let rawOutput = outputRawFolderURL
                    {
                        self?.fileManager.removeIfExists(at: outputEpub)
                        self?.fileManager.removeIfExists(at: rawOutput)
                    }
                    self?.view.window?.shake()
                    self?.warningLabel.stringValue = error.logDescription
                }
            }
        }
    }
    
    @IBAction func showGeneratedInFinder(_ sender: Any) {
        guard
            let outputEpubFolderURL = outputEpubFolderURL,
            fileManager.fileExists(atPath: outputEpubFolderURL.path) else
        {
            view.window?.shake()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([outputEpubFolderURL])
    }
    
    @IBAction func nextEpub(_ sender: Any) {
        guard let inputEpubFolderURL = inputEpubFolderURL else {
            warningLabel.stringValue = "inputEpubFolderURL is missing"
            return
        }
        let folderName = inputEpubFolderURL.lastPathComponent
        guard
            let numberString = folderName.components(separatedBy: "_").last,
            let number = Int(numberString) else
        {
            warningLabel.stringValue = "number is missing in folder name of '\(folderName)'"
            return
        }
        let nextNumber = number+1
        var nextFolderName = folderName.components(separatedBy: "_").dropLast().joined(separator: "_")
        nextFolderName.append("_\(nextNumber)")
        let nextInputEpubFolderURL = inputEpubFolderURL.deletingLastPathComponent().appendingPathComponent(nextFolderName)
        guard fileManager.directoryExists(atPath: nextInputEpubFolderURL.path) else {
            warningLabel.stringValue = "directory '\(nextFolderName)' is missing"
            return
        }
        self.inputEpubFolderURL = nextInputEpubFolderURL
        warningLabel.stringValue = "switched to '\(nextFolderName)'!"
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

extension ViewController: EpubComposerDelegate {
    
    func event(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.warningLabel.stringValue = message
        }
    }
    
}
