//
//  SketchNoteViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

import Firebase
import PopMenu
import BadgeHub
import NVActivityIndicatorView
import Repeat
import NotificationBannerSwift

import PencilKit

class SketchNoteViewController: UIViewController, UIPencilInteractionDelegate, UICollectionViewDataSource, UICollectionViewDelegate, DocumentVisitor, SketchnoteDelegate, PKCanvasViewDelegate, PKToolPickerObserver, UIScreenshotServiceDelegate {
    
    @IBOutlet var canvasView: PKCanvasView!
    
    @IBOutlet var topicsButton: UIButton!
    @IBOutlet var bookshelfButton: UIButton!
    @IBOutlet var drawingsButton: UIButton!
    @IBOutlet var manageDrawingsButton: UIButton!
    
    @IBOutlet var closeButton: UIButton!
    var topicsBadgeHub: BadgeHub!
    
    @IBOutlet var bookshelf: UIView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var bookshelfUpdateIndicator: NVActivityIndicatorView!
    
    var sketchnote: Sketchnote!
    var new = false
    var storedPathArray: NSMutableArray?
    
    var helpLinesHorizontal = [HoritonzalHelpLine]()
    var helpLinesVertical = [VerticalHelpLine]()
    enum HelpLinesStatus {
        case None
        case Horizontal
        case Grid
    }
    var helpLinesStatus : HelpLinesStatus = .None
    @IBOutlet weak var helpLinesButton: UIButton!
    
    var drawingViews = [UIView]()
    var drawingViewsShown = false
    
    var spotlightHelper: SpotlightHelper!
    var bioportalHelper: BioPortalHelper!
    var tagmeHelper: TAGMEHelper!
    
    var conceptHighlights = [UIView : [Document]]()
    @IBOutlet weak var clearFilteredDocumentsButton: UIButton!
    
    // This function sets up the page and every element contained within it.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        self.setupDocumentDetailView()
        self.bookshelfLeftDragView.curveTopCorners(size: 5)
        
        canvasView.drawing = PKDrawing()
        canvasView.allowsFingerDrawing = false
        canvasView.delegate = self
        if let window = parent?.view.window {
            let toolPicker = PKToolPicker.shared(for: window)!
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            toolPicker.addObserver(self)
            canvasView.becomeFirstResponder()
        }
        
        //Drawing Recognition - This loads the labels for the drawing recognition's CoreML model.
        if let path = Bundle.main.path(forResource: "labels", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let labelNames = data.components(separatedBy: .newlines).filter { $0.count > 0 }
                self.labelNames.append(contentsOf: labelNames)
            } catch {
                print("error loading labels: \(error)")
            }
        }
        
        setupHelpLines()
        self.rightScreenSidePanGesture.edges = [.right]
        self.topicsBadgeHub = BadgeHub(view: topicsButton)
        self.topicsBadgeHub.scaleCircleSize(by: 0.55)
        self.topicsBadgeHub.moveCircleBy(x: 4, y: -6)
        self.topicsBadgeHub.setCount(self.sketchnote.documents.count)
        
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        view.addInteraction(interaction)
        
        spotlightHelper = SpotlightHelper()
        bioportalHelper = BioPortalHelper()
        tagmeHelper = TAGMEHelper()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.sketchnote.delegate = self
        
        setupConceptHighlights()
        setupDrawingRegions()
        
        self.recognizedTextLogView.text = self.sketchnote.getText(raw: true)
        
        // If the user has not created a new note, but is trying to edit an existing note, this existing note is reloaded.
        // This reload consists of redrawing the user's strokes for that note on the note's canvas on this page.
        if sketchnote != nil {
            if new == true {
                sketchnote?.image = canvasView.drawing.image(from: canvasView.bounds, scale: 1.0)
            }
            else {
                log.info("Loading canvas data for note.")
                self.canvasView.drawing = self.sketchnote.canvasData
            }
            if let documents = sketchnote.documents {
                log.info("Reloading documents")
                self.items = documents
                documentsCollectionView.reloadData()
            }
            else {
                sketchnote.documents = [Document]()
                self.items = [Document]()
            }
            // This is the case where the user has created a new note and is not editing an existing one.
        } else {
            sketchnote = Sketchnote(image: canvasView.drawing.image(from: canvasView.bounds, scale: 1.0), relatedDocuments: nil, drawings: nil)
        }
    }
    
    // This function is called when the user closes the page, i.e. stops editing the note, and the app returns to the home page.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
        case "Placeholder":
            print("Placeholder")
            break
        case "CloseNote":
            if textRecognitionTimer != nil {
                textRecognitionTimer!.invalidate()
            }
            if saveTimer != nil {
                saveTimer!.invalidate()
            }
            bookshelfUpdateTimer?.reset(nil)
            for helpLine in self.helpLinesHorizontal {
                helpLine.removeFromSuperview()
            }
            for helpLine in self.helpLinesVertical {
                helpLine.removeFromSuperview()
            }
            self.toggleConceptHighlight(isHidden: true)
            self.processDrawingRecognition()
            traitCollection.performAsCurrent {
                sketchnote.image = canvasView.drawing.image(from: canvasView.bounds, scale: 2.0)
                if traitCollection.userInterfaceStyle == .dark {
                    sketchnote.image = sketchnote.image?.invert() ?? sketchnote.image
                }
            }
            sketchnote.setUpdateDate()
            self.sketchnote.canvasData = self.canvasView.drawing
            log.info("Closing & saving note.")
        default:
            print("Default segue case triggered.")
        }
    }
    
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        switch SettingsManager.pencilSideButton() {
        case .ManageDrawings:
            toggleManageDrawings()
            break
        case .ToggleEraserPencil:
            // TO REDO
            break
        case .Undo:
            self.undo()
            break
        case .Redo:
            self.redo()
            break
        }
    }
    
    @IBOutlet weak var imageTestView: UIImageView!
    private func processDrawingRecognition() {
        hideAllHelpLines()
        
        let canvasImage = canvasView.drawing.image(from: canvasView.bounds, scale: 1.0)
        let mainImage = canvasImage.invertedImage() ?? canvasImage
        for region in self.drawingViews {
            let image = UIImage(cgImage: mainImage.cgImage!.cropping(to: region.frame)!)
            
            let resized = image.resize(newSize: CGSize(width: 28, height: 28))
            
            guard let pixelBuffer = resized.grayScalePixelBuffer() else {
                print("Pixel buffer for drawing recognition could not be created.")
                return
            }
            do {
                currentPrediction = try drawnImageClassifier.prediction(image: pixelBuffer)
            }
            catch {
                print("Drawing recognition prediction error: \(error)")
            }
        }
    }
    
    private func setupHelpLines() {
        self.helpLinesHorizontal = [HoritonzalHelpLine]()
        self.helpLinesVertical = [VerticalHelpLine]()
        var height = CGFloat(40)
        while (CGFloat(height) < UIScreen.main.bounds.height + 80) {
            let line = HoritonzalHelpLine(frame: CGRect(x: 0, y: height, width: UIScreen.main.bounds.width, height: 1))
            
            line.isUserInteractionEnabled = false
            line.isHidden = true
            self.canvasView.addSubview(line)
            self.helpLinesHorizontal.append(line)
            height = height + 40
        }
        var width = CGFloat(40)
        while (CGFloat(width) < UIScreen.main.bounds.width + 80) {
            let line = VerticalHelpLine(frame: CGRect(x: width, y: 0, width: 1, height: UIScreen.main.bounds.height))
            
            line.isUserInteractionEnabled = false
            line.isHidden = true
            self.canvasView.addSubview(line)
            self.helpLinesVertical.append(line)
            width = width + 40
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) { // Handle screen orientation change
        super.viewWillTransition(to: size, with: coordinator)
        self.resetHelpLines()
    }
    
    private func resetHelpLines() {
        for helpLine in self.helpLinesHorizontal {
            helpLine.removeFromSuperview()
        }
        for helpLine in self.helpLinesVertical {
            helpLine.removeFromSuperview()
        }
        self.setupHelpLines()
        switch self.helpLinesStatus {
        case .None:
            for helpLine in self.helpLinesHorizontal {
                helpLine.isHidden = true
            }
            for helpLine in self.helpLinesVertical {
                helpLine.isHidden = true
            }
            break
        case .Horizontal:
            for helpLine in self.helpLinesHorizontal {
                helpLine.isHidden = false
            }
            for helpLine in self.helpLinesVertical {
                helpLine.isHidden = true
            }
            break
        case .Grid:
            for helpLine in self.helpLinesHorizontal {
                helpLine.isHidden = false
            }
            for helpLine in self.helpLinesVertical {
                helpLine.isHidden = false
            }
            break
        }
    }
    
    // MARK: Highlighting recognized concepts/topics on the canvas
    private func setupConceptHighlights() {
        conceptHighlights = [UIView : [Document]]()
        if let documents = sketchnote.documents {
            for textData in sketchnote.textDataArray {
                for document in documents {
                    var documentTitle = document.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if let TAGMEdocument = document as? TAGMEDocument {
                        if let spot = TAGMEdocument.spot {
                            documentTitle = spot.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        }
                    }
                    if textData.original.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().contains(documentTitle) {
                        for block in textData.visionTextWrapper.blocks {
                            for line in block.lines {
                                for element in line.elements {
                                    let elementText = element.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                    if elementText == documentTitle {
                                        let scaledFrame = createScaledFrame(featureFrame: element.frame, imageSize: canvasView.frame.size)
                                        let conceptHighlightView = UIView(frame: scaledFrame)
                                        conceptHighlightView.layer.borderWidth = 2
                                        conceptHighlightView.layer.borderColor = #colorLiteral(red: 0.3333333333, green: 0.4588235294, blue: 0.7568627451, alpha: 1).cgColor
                                        if conceptHighlightExists(new: conceptHighlightView.frame) != nil {
                                            let existingView = conceptHighlightExists(new: conceptHighlightView.frame)!
                                            var newDocs = self.conceptHighlights[existingView]!
                                            newDocs.append(document)
                                            self.conceptHighlights[existingView] = newDocs
                                        }
                                        else {
                                            self.conceptHighlights[conceptHighlightView] = [Document]()
                                            var newDocs = self.conceptHighlights[conceptHighlightView]!
                                            newDocs.append(document)
                                            self.conceptHighlights[conceptHighlightView] = newDocs
                                            self.canvasView.addSubview(conceptHighlightView)
                                            conceptHighlightView.isHidden = true
                                            conceptHighlightView.isUserInteractionEnabled = true
                                            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleConceptHighlightTap(_:)))
                                            conceptHighlightView.addGestureRecognizer(tapGesture)
                                        }
                                    }
                                }
                                for index in 0..<line.elements.count {
                                    var elementText = line.elements[index].text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                    var width = line.elements[index].frame.width
                                    if index < line.elements.count-1 {
                                        for j in index+1..<line.elements.count {
                                            elementText = elementText + " " + line.elements[j].text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                            width = width + line.elements[j].frame.width
                                            if elementText == documentTitle {
                                                let scaledFrame = createScaledFrame(featureFrame: CGRect(x: line.elements[index].frame.minX, y: line.elements[index].frame.minY, width: width, height: line.elements[index].frame.height), imageSize: canvasView.frame.size)
                                                let conceptHighlightView = UIView(frame: scaledFrame)
                                                conceptHighlightView.layer.borderWidth = 2
                                                conceptHighlightView.layer.borderColor = #colorLiteral(red: 0.3333333333, green: 0.4588235294, blue: 0.7568627451, alpha: 1).cgColor
                                                
                                                if conceptHighlightExists(new: conceptHighlightView.frame) != nil {
                                                    let existingView = conceptHighlightExists(new: conceptHighlightView.frame)!
                                                    var newDocs = self.conceptHighlights[existingView]!
                                                    newDocs.append(document)
                                                    self.conceptHighlights[existingView] = newDocs
                                                }
                                                else {
                                                    self.conceptHighlights[conceptHighlightView] = [Document]()
                                                    var newDocs = self.conceptHighlights[conceptHighlightView]!
                                                    newDocs.append(document)
                                                    self.conceptHighlights[conceptHighlightView] = newDocs
                                                    self.canvasView.addSubview(conceptHighlightView)
                                                    conceptHighlightView.isHidden = true
                                                    conceptHighlightView.isUserInteractionEnabled = true
                                                    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleConceptHighlightTap(_:)))
                                                    conceptHighlightView.addGestureRecognizer(tapGesture)
                                                }
                                                break
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    private func conceptHighlightExists(new: CGRect) -> UIView? {
        for (view, _) in self.conceptHighlights {
            if view.frame == new {
                return view
            }
        }
        return nil
    }
    private func createScaledFrame(featureFrame: CGRect, imageSize: CGSize) -> CGRect {
            let viewSize = canvasView.frame.size
            
            // 2
            let resolutionView = viewSize.width / viewSize.height
            let resolutionImage = imageSize.width / imageSize.height
            
            // 3
            var scale: CGFloat
            if resolutionView > resolutionImage {
                scale = viewSize.height / imageSize.height
            } else {
                scale = viewSize.width / imageSize.width
            }
            
            // 4
            let featureWidthScaled = featureFrame.size.width * scale
            let featureHeightScaled = featureFrame.size.height * scale
            
            // 5
            let imageWidthScaled = imageSize.width * scale
            let imageHeightScaled = imageSize.height * scale
            let imagePointXScaled = (viewSize.width - imageWidthScaled) / 2
            let imagePointYScaled = (viewSize.height - imageHeightScaled) / 2
            
            // 6
            let featurePointXScaled = imagePointXScaled + featureFrame.origin.x * scale
            let featurePointYScaled = imagePointYScaled + featureFrame.origin.y * scale
            
            // 7
            return CGRect(x: featurePointXScaled,
                          y: featurePointYScaled,
                          width: featureWidthScaled,
                          height: featureHeightScaled)
    }
    
    @objc func handleConceptHighlightTap(_ sender: UITapGestureRecognizer) {
        if let conceptHighlightView = sender.view {
            if let documents = self.conceptHighlights[conceptHighlightView] {
                if self.bookshelfState == .Topic && self.selectedTopicDocuments != nil && self.selectedTopicDocuments! == documents {
                    self.clearTopicDocuments()
                }
                else {
                    self.selectedTopicDocuments = documents
                    self.updateBookshelfState(state: .Topic)
                    self.showTopicDocuments(documents: documents)
                }
                if bookshelf.isHidden {
                    showBookshelf()
                }
            }
        }
    }
    
    private func toggleConceptHighlight(isHidden: Bool) {
        for (view, _) in self.conceptHighlights {
            view.isHidden = isHidden
        }
    }
    
    var topicsShown = false
    @IBAction func topicsTapped(_ sender: UIButton) {
        topicsShown = !topicsShown
        if topicsShown {
            setupConceptHighlights()
            topicsButton.tintColor = self.view.tintColor
            topicsButton.setTitleColor(self.view.tintColor, for: .normal)
        }
        else {
            topicsButton.tintColor = .white
            topicsButton.setTitleColor(.white, for: .normal)
        }
        self.toggleConceptHighlight(isHidden: !topicsShown)
    }
    
    private func clearConceptHighlights() {
        for (view, _) in conceptHighlights {
            view.removeFromSuperview()
        }
        self.conceptHighlights = [UIView : [Document]]()
        topicsButton.tintColor = .white
        topicsButton.setTitleColor(.white, for: .normal)
    }
    
    @IBAction func moreButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: self.sketchnote.getTitle(), message: "", preferredStyle: .alert)
        if !SettingsManager.automaticAnnotation() {
            alert.addAction(UIAlertAction(title: "Annotate", style: .default, handler: { action in
                self.processHandwritingRecognition()
            }))
        }
        alert.addAction(UIAlertAction(title: "Set Title", style: .default, handler: { action in
            let alertController = UIAlertController(title: "Title for this note", message: nil, preferredStyle: .alert)
            
            let confirmAction = UIAlertAction(title: "Set", style: .default) { (_) in
                
                let title = alertController.textFields?[0].text
                
                self.sketchnote.setTitle(title: title ?? "Untitled")
                
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
            
            alertController.addTextField { (textField) in
                textField.placeholder = "Enter Note Title"
            }
            
            alertController.addAction(confirmAction)
            alertController.addAction(cancelAction)
            
            self.present(alertController, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Share", style: .default, handler: { action in
            self.sketchnote.image = self.canvasView.drawing.image(from: self.canvasView.bounds, scale: 1.0)
            if self.sketchnote.image != nil {
                var data = [Any]()
                if let pdf = self.sketchnote.createPDF() {
                    data.append(pdf)
                }
                
                let activityController = UIActivityViewController(activityItems: data, applicationActivities: nil)
                self.present(activityController, animated: true, completion: nil)
                if let popOver = activityController.popoverPresentationController {
                    popOver.sourceView = self.canvasView
                }
            }
        }))
        if !sketchnote.getText().isEmpty {
            alert.addAction(UIAlertAction(title: "Copy Text", style: .default, handler: { action in
                UIPasteboard.general.string = self.sketchnote.getText()
                let banner = FloatingNotificationBanner(title: self.sketchnote.getTitle(), subtitle: "Copied text to clipboard.", style: .info)
                banner.show()
            }))
        }
        alert.addAction(UIAlertAction(title: "Reset Documents", style: .default, handler: { action in
            self.sketchnote.documents = [Document]()
            //self.items = [Document]()
            self.clearConceptHighlights()
            self.updateBookshelfState(state: .All)
            self.bookshelfFilter = .All
            self.filterDocumentsButton.setTitle("All", for: .normal)
            self.updateBookshelf()
            self.annotateText(text: self.sketchnote.getText())
        }))
        alert.addAction(UIAlertAction(title: "Reset Text Recognition", style: .default, handler: { action in
            self.sketchnote.clearTextData()
            self.sketchnote.documents = [Document]()
            self.items = [Document]()
            self.clearConceptHighlights()
            self.updateBookshelfState(state: .All)
            self.bookshelfFilter = .All
            self.filterDocumentsButton.setTitle("All", for: .normal)
            self.processHandwritingRecognition()
        }))
        alert.addAction(UIAlertAction(title: "Clear Note", style: .destructive, handler: { action in
            self.canvasView.drawing = PKDrawing()
            self.sketchnote.canvasData = PKDrawing()
            self.canvasView.subviews.forEach { $0.removeFromSuperview() }
            self.resetHelpLines()
            
            self.sketchnote.clear()
            self.clearConceptHighlights()
            self.topicsButton.tintColor = .white
            self.topicsButton.setTitleColor(.white, for: .normal)
            self.updateBookshelfState(state: .All)
            self.bookshelfFilter = .All
            self.items = self.sketchnote.documents
            if self.bookshelfUpdateTimer != nil {
                self.bookshelfUpdateTimer!.reset(nil)
            }
            self.documentsCollectionView.reloadData()
            self.topicsBadgeHub.setCount(0)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    private func undo() {
        self.startRecognitionTimer()
        self.resetHandwritingRecognition = true
        self.startSaveTimer()
        if canvasView.undoManager?.canUndo ?? false {
            canvasView.undoManager?.undo()
        }
    }
    private func redo() {
        self.startRecognitionTimer()
        self.resetHandwritingRecognition = true
        self.startSaveTimer()
        if canvasView.undoManager?.canRedo ?? false {
            canvasView.undoManager?.redo()
        }
    }
    
    @IBAction func drawingsTapped(_ sender: UIButton) {
        drawingViewsShown = !drawingViewsShown
        if drawingViewsShown {
            toggleDrawingRegions(isHidden: false, canInteract: false)
            drawingsButton.tintColor = self.view.tintColor
        }
        else {
            toggleDrawingRegions(isHidden: true, canInteract: false)
            drawingsButton.tintColor = .white
        }
    }
    
    @IBAction func helpLinesButtonTapped(_ sender: UIButton) {
        switch self.helpLinesStatus {
        case .None:
            self.helpLinesStatus = .Horizontal
            helpLinesButton.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
            helpLinesButton.tintColor = self.view.tintColor
            
            for line in helpLinesHorizontal {
                line.isHidden = false
            }
            for line in helpLinesVertical {
                line.isHidden = true
            }
            break
        case .Horizontal:
            self.helpLinesStatus = .Grid
            helpLinesButton.tintColor = self.view.tintColor
            helpLinesButton.setImage(UIImage(systemName: "grid"), for: .normal)
            for line in helpLinesHorizontal {
                line.isHidden = false
            }
            for line in helpLinesVertical {
                line.isHidden = false
            }
            break
        case .Grid:
            self.helpLinesStatus = .None
            helpLinesButton.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
            helpLinesButton.tintColor = .white
            hideAllHelpLines()
            break
        }
    }

    private func hideAllHelpLines() {
        for line in helpLinesHorizontal {
            line.isHidden = true
        }
        for line in helpLinesVertical {
            line.isHidden = true
        }
    }
    
    //MARK: Handwriting recognition process
    let handwritingRecognizer = HandwritingRecognizer()
    
    private func processHandwritingRecognition() {
        let image = self.generateHandwritingRecognitionImage()
        self.sketchnote.clearTextData()
        handwritingRecognizer.recognize(spellcheck: false, image: image) { (success, textData) in
            if success {
                if let textData = textData {
                    self.sketchnote.textDataArray.append(textData)
                    self.annotateText(text: self.sketchnote.getText())
                    print(textData.spellchecked ?? "")
                    
                    self.recognizedTextLogView.text = self.sketchnote.getText(raw: true)
                }
            }
            else {
                self.activityIndicator.stopAnimating()
                print("Handwriting recognition returned no result.")
            }
        }
    }
    private func generateHandwritingRecognitionImage() -> UIImage {
        var noteImage = canvasView.drawing.image(from: canvasView.bounds, scale: 1.0)
        if UITraitCollection.current.userInterfaceStyle == .dark {
            log.info("Handwriting recognition image generation - dark mode detected, inverting image")
            noteImage = noteImage.invertedImage() ?? noteImage
        }
        return noteImage
    }
    
    func annotateText(text: String) {
        self.activityIndicator.stopAnimating()
        self.clearConceptHighlights()
        
        DispatchQueue.global(qos: .background).async {
            self.tagmeHelper.fetch(text: text, note: self.sketchnote)
            self.bioportalHelper.fetch(text: text, note: self.sketchnote)
            self.bioportalHelper.fetchCHEBI(text: text, note: self.sketchnote)
        }
    }
    
    
    @IBAction func bookshelfButtonTapped(_ sender: UIButton) {
        if self.bookshelf.isHidden {
            showBookshelf()
        }
        else {
            closeBookshelf()
        }
    }
    
    private func showBookshelf() {
        bookshelfButton.tintColor = self.view.tintColor
        self.bookshelf.isHidden = false
        if self.isBookshelfDraggedOut {
            self.bookshelfLeftConstraint.constant -= 500
            UIView.animate(withDuration: 0.25, delay: 0, options: UIView.AnimationOptions.curveEaseIn, animations: {
                self.view.layoutIfNeeded()
            }, completion: { (ended) in
            })
            self.isBookshelfDraggedOut = false
        }
    }
    
    private func closeBookshelf() {
         bookshelfButton.tintColor = .white
        bookshelfLeftConstraint.constant = UIScreen.main.bounds.width
        self.isBookshelfDraggedOut = true
        UIView.animate(withDuration: 0.25, delay: 0, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.view.layoutIfNeeded()
        }, completion: { (ended) in
            self.bookshelf.isHidden = true
        })
        bookshelf.alpha = 1.0
    }
    
    var textRecognitionTimer: Timer?
    var resetHandwritingRecognition = false

    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        self.resetHandwritingRecognition = true
        self.startSaveTimer()
        if (canvasView.tool is PKInkingTool && (canvasView.tool as! PKInkingTool).inkType != PKInkingTool.InkType.marker) || canvasView.tool is PKEraserTool {
            if SettingsManager.automaticAnnotation() {
                self.startRecognitionTimer()
            }
        }
    }
    private func startRecognitionTimer() {
        if textRecognitionTimer != nil {
            textRecognitionTimer!.invalidate()
            textRecognitionTimer = nil
        }
        textRecognitionTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(onRecognitionTimerFires), userInfo: nil, repeats: false)
        self.activityIndicator.startAnimating()
        log.info("Recognition timer started/reset.")
    }
    @objc func onRecognitionTimerFires()
    {
        textRecognitionTimer?.invalidate()
        textRecognitionTimer = nil
        self.processHandwritingRecognition()
    }
    
    var saveTimer: Timer?
    private func startSaveTimer() {
        if saveTimer != nil {
            saveTimer!.invalidate()
            saveTimer = nil
            print("Save timer reset.")
        }
        saveTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(onSaveTimerFires), userInfo: nil, repeats: false)
        print("Save timer started.")
    }
    @objc func onSaveTimerFires()
    {
        saveTimer?.invalidate()
        saveTimer = nil
        print("Auto-saving sketchnote strokes and text data.")
        self.sketchnote.canvasData = self.canvasView.drawing
        self.sketchnote.save()
    }
    
    // Drawing recognition
    // In case the user's drawing has been recognized with at least a >40% confidence, the recognized drawing's label, e.g. "light bulb", is stored for the sketchnote.
    private var labelNames: [String] = []
    private let drawnImageClassifier = DrawnImageClassifier()
    private var currentPrediction: DrawnImageClassifierOutput? {
        didSet {
            if let currentPrediction = currentPrediction {
                let sorted = currentPrediction.category_softmax_scores.sorted { $0.value > $1.value }
                let top5 = sorted.prefix(5)
                print(top5.map { $0.key + "(" + String($0.value) + ")"}.joined(separator: ", "))
                
                for (label, score) in top5 {
                    if score > 0.4 {
                        print("Adding drawing: " + label)
                        self.sketchnote!.addDrawing(drawing: label)
                    }
                }
            }
            else {
                print("Waiting for drawing")
            }
        }
    }
    
    //MARK: Bookshelf resize
    @IBOutlet weak var bookshelfLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var bookshelfRightConstraint: NSLayoutConstraint!
    @IBOutlet weak var bookshelfBottomConstraint: NSLayoutConstraint!
    
    
    struct ResizeRect{
        var topTouch = false
        var leftTouch = false
        var rightTouch = false
        var bottomTouch = false
        var middelTouch = false
    }
    
    var touchStart = CGPoint.zero
    var proxyFactor = CGFloat(10)
    var resizeRect = ResizeRect()
    
    var isBookshelfDraggedOut = false
    @IBOutlet var bookshelfLeftDragView: UIView!
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first{
            let touchStart = touch.location(in: self.view)
            
            resizeRect.topTouch = false
            resizeRect.leftTouch = false
            resizeRect.rightTouch = false
            resizeRect.bottomTouch = false
            resizeRect.middelTouch = false
            if touchStart.x > bookshelf.frame.minX - proxyFactor &&  touchStart.x < bookshelf.frame.minX + proxyFactor + 15 {
                resizeRect.leftTouch = true
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first{
            let currentTouchPoint = touch.location(in: self.view)
            let previousTouchPoint = touch.previousLocation(in: self.view)
            
            let deltaX = currentTouchPoint.x - previousTouchPoint.x
            
            if resizeRect.leftTouch {
                if (bookshelfLeftConstraint.constant + deltaX) >= 0 && UIScreen.main.bounds.maxX - currentTouchPoint.x >= 300 {
                    bookshelfLeftConstraint.constant += deltaX
                }
                
                
                if UIScreen.main.bounds.maxX - currentTouchPoint.x <= 300 {
                    bookshelf.alpha = 0.4
                }
                else {
                    bookshelf.alpha = 1.0
                }
            }
            
            
            UIView.animate(withDuration: 0.25, delay: 0, options: UIView.AnimationOptions.curveEaseIn, animations: {
                self.view.layoutIfNeeded()
            }, completion: { (ended) in
            })
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first{
            let currentTouchPoint = touch.location(in: self.view)
            
            if resizeRect.leftTouch {
                if UIScreen.main.bounds.maxX - currentTouchPoint.x <= 300 {
                    self.closeBookshelf()
                }
            }
        }
    }
    @IBOutlet var rightScreenSidePanGesture: UIScreenEdgePanGestureRecognizer!
    @IBAction func rightScreenSidePanned(_ sender: UIScreenEdgePanGestureRecognizer) {
        if sender.state == .began {
            if self.bookshelf.isHidden {
                self.showBookshelf()
            }
        }
        
    }
    
    // MARK: Documents Collection View
    @IBOutlet var documentsCollectionView: UICollectionView!
    
    let reuseIdentifier = "cell"
    var items = [Document]()
    
    var selectedTopicDocuments: [Document]?
    
    private enum BookshelfState {
        case All
        case Topic
    }
    private var bookshelfState = BookshelfState.All
    private enum BookshelfFilter {
        case All
        case TAGME
        case Spotlight
        case BioPortal
        case CHEBI
    }
    private var bookshelfFilter = BookshelfFilter.All
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath as IndexPath) as! DocumentUICollectionViewCell
        
        let document = self.items[indexPath.item]
        cell.document = document
        cell.titleLabel.text = document.title
        cell.previewImage.image = document.previewImage
        cell.previewImage.layer.masksToBounds = true
        cell.previewImage.layer.cornerRadius = 90
        
        switch document.documentType {
            
        case .Spotlight:
            cell.previewImage.layer.borderColor = #colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)
            break
        case .TAGME:
            cell.previewImage.layer.borderColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
            break
        case .BioPortal:
            cell.previewImage.layer.borderColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            break
        case .Chemistry:
            cell.previewImage.layer.borderColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
            break
        case .Other:
            cell.previewImage.layer.borderColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            break
        }
        cell.previewImage.layer.borderWidth = 3
        
        cell.layer.cornerRadius = 2
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate protocol
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // handle tap events
        showDocumentDetail(document: self.items[indexPath.item])
    }
    
    private func updateBookshelf() {
        DispatchQueue.main.async {
            if self.bookshelfState == .All {
                print("Updating Bookshelf.")
                self.clearFilteredDocumentsButton.isHidden = true
                self.items = self.getFilteredDocuments(documents: self.sketchnote.documents)
                self.documentsCollectionView.refreshLayout()
                self.documentsCollectionView.reloadData()
            }
            else if self.bookshelfState == .Topic {
                if self.selectedTopicDocuments != nil {
                    self.clearFilteredDocumentsButton.isHidden = false
                    self.items = self.getFilteredDocuments(documents: self.selectedTopicDocuments!)
                    
                }
                else {
                    self.items = [Document]()
                }
                self.documentsCollectionView.refreshLayout()
                self.documentsCollectionView.reloadData()
            }
            
            self.updateBookshelfState(state: self.bookshelfState)
        }
    }
    
    private func updateBookshelfState(state: BookshelfState) {
        self.bookshelfState = state
        switch self.bookshelfState {
        case .All:
            self.clearFilteredDocumentsButton.isHidden = true
            self.selectedTopicDocuments = nil
        case .Topic:
            self.clearFilteredDocumentsButton.isHidden = false
        }
    }
    
    private func getFilteredDocuments(documents: [Document]) -> [Document] {
        switch self.bookshelfFilter {
        case .All:
            return documents
        case .TAGME:
            return documents.filter{ $0.documentType == .TAGME }
        case .Spotlight:
            return documents.filter{ $0.documentType == .Spotlight }
        case .BioPortal:
            return documents.filter{ $0.documentType == .BioPortal }
        case .CHEBI:
            return documents.filter{ $0.documentType == .Chemistry }
        }
    }
    
    var bookshelfUpdateTimer: Repeater?
    private func startBookshelfUpdateTimer() {
        DispatchQueue.main.async {
            self.bookshelfUpdateIndicator.isHidden = false
            if !self.bookshelfUpdateIndicator.isAnimating {
                self.bookshelfUpdateIndicator.startAnimating()
            }
            if self.bookshelfUpdateTimer != nil {
                log.info("Bookshelf Update Timer reset.")
                self.bookshelfUpdateTimer!.reset(nil)
            }
            else {
                log.info("Bookshelf Update Timer started.")
                self.bookshelfUpdateTimer = Repeater.once(after: .seconds(2)) { timer in
                    DispatchQueue.main.async {
                        self.updateBookshelf()
                        self.bookshelfUpdateIndicator.stopAnimating()
                        self.bookshelfUpdateIndicator.isHidden = true
                    }
                    
                }
            }
        }
    }
    
    func sketchnoteHasNewDocument(sketchnote: Sketchnote, document: Document) { // Sketchnote delegate
        DispatchQueue.main.async {
            if self.bookshelfState == .All && self.documentTypeMatchesBookshelfFilter(type: document.documentType) {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.items.append(document)
                let indexPath = IndexPath(row: self.items.count - 1, section: 0)
                self.documentsCollectionView.insertItems(at: [indexPath])
                CATransaction.commit()
                self.documentsCollectionView.scrollToItem(at: indexPath, at: .bottom , animated: true)
            }
            self.topicsBadgeHub.setCount(self.sketchnote.documents.count)
        }
    }
    
    private func documentTypeMatchesBookshelfFilter(type: DocumentType) -> Bool {
        if self.bookshelfFilter == .All {
            return true
        }
        switch type {
        case .Spotlight:
            if self.bookshelfFilter == .Spotlight {
                return true
            }
        case .TAGME:
            if self.bookshelfFilter == .TAGME {
                return true
            }
        case .BioPortal:
            if self.bookshelfFilter == .BioPortal {
                return true
            }
        case .Chemistry:
            if self.bookshelfFilter == .CHEBI {
                return true
            }
        case .Other:
            return true
        }
        return false
    }
    
    func sketchnoteHasRemovedDocument(sketchnote: Sketchnote, document: Document) { // Sketchnote delegate
        self.startBookshelfUpdateTimer()
    }
    
    func sketchnoteDocumentHasChanged(sketchnote: Sketchnote, document: Document) { // Sketchnote delegate
        self.startBookshelfUpdateTimer()
    }
    
    func sketchnoteHasChanged(sketchnote: Sketchnote) { // Sketchnote delegate
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in
            return self.makeDocumentContextMenu(document: self.items[indexPath.row])
        })
    }
    private func makeDocumentContextMenu(document: Document) -> UIMenu {
        let hideAction = UIAction(title: "Hide", image: UIImage(systemName: "eye.slash")) { action in
            self.sketchnote.removeDocument(document: document)
            DocumentsManager.hide(document: document)
            if self.bookshelfState == .Topic {
                if self.selectedTopicDocuments != nil && self.selectedTopicDocuments!.contains(document) {
                    self.selectedTopicDocuments!.removeAll{$0 == document}
                }
            }
            self.updateBookshelf()
        }
        return UIMenu(title: document.title, children: [hideAction])
    }
    
    //MARK: Document Detail View
    
    @IBOutlet var documentDetailView: UIView!
    @IBOutlet var documentTitleLabel: UILabel!
    @IBOutlet var documentDetailScrollView: UIScrollView!
    var documentDetailStackView = UIStackView()
    @IBOutlet weak var documentDetailTypeView: UIView!
    @IBOutlet weak var documentDetailTypeLabel: UILabel!
    @IBOutlet weak var documentDetailPreviewImageView: UIImageView!
    
    private func setupDocumentDetailView() {
        documentDetailStackView.axis = .vertical
        documentDetailStackView.distribution = .equalSpacing
        documentDetailStackView.alignment = .fill
        documentDetailStackView.spacing = 5
        documentDetailScrollView.addSubview(documentDetailStackView)
        documentDetailStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            documentDetailStackView.topAnchor.constraint(equalTo: documentDetailScrollView.topAnchor),
            documentDetailStackView.leadingAnchor.constraint(equalTo: documentDetailScrollView.leadingAnchor),
            documentDetailStackView.trailingAnchor.constraint(equalTo: documentDetailScrollView.trailingAnchor),
            documentDetailStackView.bottomAnchor.constraint(equalTo: documentDetailScrollView.bottomAnchor),
            documentDetailStackView.widthAnchor.constraint(equalTo: documentDetailScrollView.widthAnchor)
            ])
        
        documentDetailPreviewImageView.layer.masksToBounds = true
        documentDetailPreviewImageView.layer.cornerRadius = 75
        documentDetailPreviewImageView.layer.borderWidth = 1
        documentDetailPreviewImageView.layer.borderColor = UIColor.black.cgColor
        documentDetailTypeView.layer.masksToBounds = true
        documentDetailTypeView.layer.cornerRadius = 15
    }
    
    private func showDocumentDetail(document: Document) {
        for view in documentDetailStackView.subviews {
            view.removeFromSuperview()
        }
        
        documentTitleLabel.text = document.title
        documentDetailTypeLabel.text = "Document"
        documentDetailPreviewImageView.image = nil
        if let previewImage = document.previewImage {
            documentDetailPreviewImageView.image = previewImage
        }
        document.accept(visitor: self)
        
        documentDetailView.isHidden = false
        documentsCollectionView.isHidden = true
    }
    private func showTopicDocuments(documents: [Document]) {
        for view in documentDetailStackView.subviews {
            view.removeFromSuperview()
        }
        documentDetailView.isHidden = true
        documentsCollectionView.isHidden = false
        self.items = getFilteredDocuments(documents: documents)
        self.documentsCollectionView.refreshLayout()
        self.documentsCollectionView.reloadData()
        if bookshelfUpdateTimer != nil {
            bookshelfUpdateTimer!.reset(nil)
            //bookshelfUpdateTimer = nil
        }
        clearFilteredDocumentsButton.isHidden = false
    }
    @IBAction func clearTopicDocumentsTapped(_ sender: UIButton) {
        self.clearTopicDocuments()
    }
    private func clearTopicDocuments() {
        self.updateBookshelfState(state: .All)
        self.updateBookshelf()
    }
    
    func process(document: Document) {
        if let description = document.description {
            self.setDetailDescription(text: description)
        }
    }
    
    func process(document: SpotlightDocument) {
        documentDetailTypeView.backgroundColor = #colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)
        documentDetailTypeLabel.text = "Spotlight"
        if let label = document.label {
            documentTitleLabel.text = label
        }
        if let description = document.description {
            self.setDetailDescription(text: description)
        }
        if let mapImage = document.mapImage {
            let mapImageView = UIImageView(image: mapImage)
            documentDetailStackView.addArrangedSubview(mapImageView)
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(mapImageTapped(tapGestureRecognizer:)))
            mapImageView.isUserInteractionEnabled = true
            mapImageView.addGestureRecognizer(tapGestureRecognizer)
        }
    }
    
    func process(document: TAGMEDocument) {
        documentDetailTypeView.backgroundColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
        documentDetailTypeLabel.text = "TAGME"
        documentTitleLabel.text = document.title
        if let description = document.description {
            self.setDetailDescription(text: description)
        }
        if let mapImage = document.mapImage {
            let mapImageView = UIImageView(image: mapImage)
            documentDetailStackView.addArrangedSubview(mapImageView)
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(mapImageTapped(tapGestureRecognizer:)))
            mapImageView.isUserInteractionEnabled = true
            mapImageView.addGestureRecognizer(tapGestureRecognizer)
        }
    }
    
    func process(document: BioPortalDocument) {
        documentDetailTypeView.backgroundColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        documentDetailTypeLabel.text = "BioPortal"
        if let definition = document.definition {
            self.setDetailDescription(text: definition)
        }
    }
    
    func process(document: CHEBIDocument) {
        documentDetailTypeView.backgroundColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1)
        documentDetailTypeLabel.text = "CHEBI"
        if let definition = document.definition {
            self.setDetailDescription(text: definition)
        }
        if let moleculeImage = document.moleculeImage {
            let mapImageView = UIImageView(image: moleculeImage)
            documentDetailStackView.addArrangedSubview(mapImageView)
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(mapImageTapped(tapGestureRecognizer:)))
            mapImageView.isUserInteractionEnabled = true
            mapImageView.addGestureRecognizer(tapGestureRecognizer)
        }
    }
    
    private func setDetailDescription(text: String) {
        let descriptionLabel = UILabel(frame: documentDetailStackView.frame)
        descriptionLabel.text = text
        descriptionLabel.numberOfLines = 50
        descriptionLabel.textColor = .white
        documentDetailStackView.addArrangedSubview(descriptionLabel)
    }
    
    
    @objc func mapImageTapped(tapGestureRecognizer: UITapGestureRecognizer)
    {
        let tappedImage = tapGestureRecognizer.view as! UIImageView
        let newImageView = UIImageView(image: tappedImage.image)
        newImageView.frame = UIScreen.main.bounds
        newImageView.backgroundColor = .black
        newImageView.contentMode = .scaleAspectFit
        newImageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissFullscreenMapImage))
        newImageView.addGestureRecognizer(tap)
        self.view.addSubview(newImageView)
        self.navigationController?.isNavigationBarHidden = true
        self.tabBarController?.tabBar.isHidden = true
    }
    @objc func dismissFullscreenMapImage(_ sender: UITapGestureRecognizer) {
        self.navigationController?.isNavigationBarHidden = true
        self.tabBarController?.tabBar.isHidden = true
        sender.view?.removeFromSuperview()
    }
    @IBAction func documentDetailViewBrowseTapped(_ sender: UIButton) {
        documentDetailView.isHidden = true
        documentsCollectionView.isHidden = false
    }
    
    // MARK: Collection view document filtering
    @IBOutlet weak var filterDocumentsButton: UIButton!
    @IBAction func filterDocumentsButtonTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
        
        var allImage: UIImage? = nil
        var spotlightImage: UIImage? = nil
        var bioportalImage: UIImage? = nil
        var chebiImage: UIImage? = nil
        var tagmeImage: UIImage? = nil
        switch self.bookshelfFilter {
        case .All:
            allImage = #imageLiteral(resourceName: "CheckmarkIcon")
        case .TAGME:
            tagmeImage = #imageLiteral(resourceName: "CheckmarkIcon")
        case .Spotlight:
            spotlightImage = #imageLiteral(resourceName: "CheckmarkIcon")
        case .BioPortal:
            bioportalImage = #imageLiteral(resourceName: "CheckmarkIcon")
        case .CHEBI:
            chebiImage = #imageLiteral(resourceName: "CheckmarkIcon")
        }
        
        let allAction = PopMenuDefaultAction(title: "All", image: allImage, color: #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1), didSelect: { action in
            self.bookshelfFilter = .All
            self.updateBookshelf()
            self.filterDocumentsButton.setTitle("All", for: .normal)
            
        })
        let spotlightAction = PopMenuDefaultAction(title: "Spotlight", image: spotlightImage, color: #colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1), didSelect: { action in
            self.bookshelfFilter = .Spotlight
            self.updateBookshelf()
            self.filterDocumentsButton.setTitle("Spotlight", for: .normal)
        })
        let bioportalAction = PopMenuDefaultAction(title: "BioPortal", image: bioportalImage, color: #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1), didSelect: { action in
            self.bookshelfFilter = .BioPortal
            self.updateBookshelf()
            self.filterDocumentsButton.setTitle("BioPortal", for: .normal)
        })
        let chebiAction = PopMenuDefaultAction(title: "CHEBI", image: chebiImage, color: #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1), didSelect: { action in
            self.bookshelfFilter = .CHEBI
            self.updateBookshelf()
            self.filterDocumentsButton.setTitle("CHEBI", for: .normal)
        })
        let tagmeAction = PopMenuDefaultAction(title: "TAGME", image: tagmeImage, color: #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1), didSelect: { action in
            self.bookshelfFilter = .TAGME
            self.updateBookshelf()
            self.filterDocumentsButton.setTitle("TAGME", for: .normal)
        })
        
        popMenu.addAction(allAction)
        popMenu.addAction(tagmeAction)
        popMenu.addAction(spotlightAction)
        popMenu.addAction(bioportalAction)
        popMenu.addAction(chebiAction)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    //MARK: Drawing insertion mode
    private func setupDrawingRegions() {
        if let drawingRegionRects = sketchnote.drawingViewRects {
            for rect in drawingRegionRects {
                let region = UIView(frame: rect)
                region.layer.borderColor = UIColor.black.cgColor
                region.layer.borderWidth = 1
                drawingInsertionCanvas.addSubview(region)
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleDrawingRegionTap(_:)))
                region.addGestureRecognizer(tapGesture)
                region.isUserInteractionEnabled = true
                drawingViews.append(region)
            }
        }
    }
    private func toggleDrawingRegions(isHidden: Bool, canInteract: Bool) {
        for drawingView in drawingViews {
            drawingView.isUserInteractionEnabled = canInteract
        }
        drawingInsertionCanvas.isHidden = isHidden
        drawingInsertionCanvas.isUserInteractionEnabled = canInteract
    }
    @IBOutlet weak var drawingInsertionCanvas: UIView!
    
    var isManageDrawings = false
    @IBAction func manageDrawingsTapped(_ sender: UIButton) {
        self.toggleManageDrawings()
    }
    
    private func toggleManageDrawings() {
        isManageDrawings = !isManageDrawings
        if isManageDrawings {
            drawingsButton.isEnabled = false
            topicsButton.isEnabled = false
            toggleDrawingRegions(isHidden: false, canInteract: true)
            canvasView.isUserInteractionEnabled = false
            canvasView.resignFirstResponder()
            if topicsShown {
                topicsShown = false
                topicsButton.tintColor = .white
                topicsButton.setTitleColor(.white, for: .normal)
            }
            manageDrawingsButton.tintColor = self.view.tintColor
        }
        else {
            drawingsButton.isEnabled = true
            topicsButton.isEnabled = true
            if drawingViewsShown {
                toggleDrawingRegions(isHidden: false, canInteract: false)
            }
            else {
                toggleDrawingRegions(isHidden: true, canInteract: false)
            }
            canvasView.isUserInteractionEnabled = true
            canvasView.becomeFirstResponder()
            manageDrawingsButton.tintColor = .white
        }
    }

    var currentDrawingRegion: UIView?
    var startPoint: CGPoint?
    var endPoint: CGPoint?
    @IBAction func drawingRegionPanGesture(_ sender: UIPanGestureRecognizer) {
        let tapPoint = sender.location(in: drawingInsertionCanvas)
        switch sender.state {
        case .began:
            startPoint = tapPoint
            currentDrawingRegion = UIView(frame: CGRect(x: tapPoint.x, y: tapPoint.y, width: 1, height: 1))
            currentDrawingRegion?.layer.borderColor = UIColor.black.cgColor
            currentDrawingRegion?.layer.borderWidth = 1
            drawingInsertionCanvas.addSubview(currentDrawingRegion!)
            break
        case .changed:
            endPoint = tapPoint
            if let currentDrawingRegion = currentDrawingRegion {
                currentDrawingRegion.frame = CGRect(x: min(startPoint!.x, endPoint!.x), y: min(startPoint!.y, endPoint!.y), width: abs(startPoint!.x - endPoint!.x), height: abs(startPoint!.y - endPoint!.y))
            }
        case .ended:
            endPoint = tapPoint
            if let currentDrawingRegion = currentDrawingRegion {
                if currentDrawingRegion.frame.width >= 150 {
                    self.sketchnote.addDrawingViewRect(rect: currentDrawingRegion.frame)
                    self.drawingViews.append(currentDrawingRegion)
                    
                    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleDrawingRegionTap(_:)))
                    currentDrawingRegion.addGestureRecognizer(tapGesture)
                    currentDrawingRegion.isUserInteractionEnabled = true
                }
                else {
                    currentDrawingRegion.removeFromSuperview()
                }
            }
        case .cancelled:
            if let currentDrawingRegion = currentDrawingRegion {
                    currentDrawingRegion.removeFromSuperview()
            }
        default:
            break
        }
    }
    @objc func handleDrawingRegionTap(_ sender: UITapGestureRecognizer) {
        if sender.view != nil {
            let popMenu = PopMenuViewController(sourceView: sender.view, actions: [PopMenuAction](), appearance: nil)
            let closeAction = PopMenuDefaultAction(title: "Close")
            let action = PopMenuDefaultAction(title: "Delete Drawing Region", didSelect: { action in
                if let drawingRegion = sender.view {
                    drawingRegion.removeFromSuperview()
                    self.sketchnote.removeDrawingViewRect(rect: drawingRegion.frame)
                }
            })
            popMenu.addAction(action)
            popMenu.addAction(closeAction)
            self.present(popMenu, animated: true, completion: nil)
        }
    }
    
    // MARK: Log view for text recognition
    @IBOutlet weak var logView: UIView!
    @IBOutlet weak var recognizedTextLogView: UITextView!
    @IBAction func openLogView(_ sender: UIButton) {
        logView.isHidden = false
    }
    @IBAction func closeLogView(_ sender: UIButton) {
        logView.isHidden = true
    }
    
}
public class HoritonzalHelpLine: UIView  {
    
    public init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        backgroundColor = .clear
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    public override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setLineWidth(2.0)
        context.setStrokeColor(UIColor.label.cgColor)
        context.move(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: self.frame.width, y: 0))
        context.strokePath()
    }
}
public class VerticalHelpLine: UIView  {
    
    public init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        backgroundColor = .clear
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    public override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setLineWidth(2.0)
        context.setStrokeColor(UIColor.label.cgColor)
        context.move(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: 0, y: self.frame.height))
        context.strokePath()
    }
}

extension String {
    func groups(for regexPattern: String) -> [[String]] {
        do {
            let text = self
            let regex = try NSRegularExpression(pattern: regexPattern)
            let matches = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            return matches.map { match in
                return (0..<match.numberOfRanges).map {
                    let rangeBounds = match.range(at: $0)
                    guard let range = Range(rangeBounds, in: text) else {
                        return ""
                    }
                    return String(text[range])
                }
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}
extension UICollectionView{
    func refreshLayout() {
        let oldLayout = collectionViewLayout as! UICollectionViewFlowLayout
        let newLayout = UICollectionViewFlowLayout()
        newLayout.estimatedItemSize = oldLayout.estimatedItemSize
        newLayout.footerReferenceSize = oldLayout.footerReferenceSize
        newLayout.headerReferenceSize = oldLayout.headerReferenceSize
        newLayout.itemSize = oldLayout.itemSize
        newLayout.minimumInteritemSpacing = oldLayout.minimumInteritemSpacing
        newLayout.minimumLineSpacing = oldLayout.minimumLineSpacing
        newLayout.scrollDirection = oldLayout.scrollDirection
        newLayout.sectionFootersPinToVisibleBounds = oldLayout.sectionFootersPinToVisibleBounds
        newLayout.sectionHeadersPinToVisibleBounds = oldLayout.sectionHeadersPinToVisibleBounds
        newLayout.sectionInset = oldLayout.sectionInset
        newLayout.sectionInsetReference = oldLayout.sectionInsetReference
        collectionViewLayout = newLayout
    }
}
