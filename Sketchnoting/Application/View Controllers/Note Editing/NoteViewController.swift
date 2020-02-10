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
import NVActivityIndicatorView
import Repeat
import NotificationBannerSwift
import ViewAnimator
import MaterialComponents.MaterialBottomSheet

import PencilKit

class NoteViewController: UIViewController, UIPencilInteractionDelegate, UICollectionViewDataSource, UICollectionViewDelegate, NoteXDelegate, PKCanvasViewDelegate, PKToolPickerObserver, UIScreenshotServiceDelegate, NoteOptionsDelegate, DocumentsViewControllerDelegate, BookshelfOptionsDelegate, NotePagesDelegate {
    
    private var documentsVC: DocumentsViewController!
    
    @IBOutlet var backdropView: UIView!
    @IBOutlet var canvasView: PKCanvasView!
    
    @IBOutlet var topicsButton: UIButton!
    @IBOutlet var bookshelfButton: UIButton!
    @IBOutlet var drawingsButton: UIButton!
    @IBOutlet var manageDrawingsButton: UIButton!
    @IBOutlet var optionsButton: UIButton!
    @IBOutlet var previousPageButton: UIButton!
    @IBOutlet var nextPageButton: UIButton!
    @IBOutlet var newPageButton: UIButton!
    @IBOutlet var pageButton: UIButton!
    
    @IBOutlet var closeButton: UIButton!
    var topicsBadgeHub: BadgeHub!
    
    @IBOutlet var bookshelf: UIView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var documentsUnderlyingView: UIView!
        
    var helpLinesHorizontal = [HoritonzalHelpLine]()
    var helpLinesVertical = [VerticalHelpLine]()
    @IBOutlet weak var helpLinesButton: UIButton!
    
    @IBOutlet weak var bookshelfSegmentedControl: UISegmentedControl!
    @IBOutlet weak var relatedNotesSegmentedControl: UISegmentedControl!
    
    @IBOutlet var canvasViewLongPressGesture: UILongPressGestureRecognizer!
    var drawingViews = [UIView]()
    var drawingViewsShown = false
    
    var spotlightHelper: SpotlightHelper!
    var bioportalHelper: BioPortalHelper!
    var tagmeHelper: TAGMEHelper!
    
    var conceptHighlights = [UIView : [Document]]()
    
    var isDeletingNote = false
    
    // This function sets up the page and every element contained within it.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        

        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        self.documentsVC = storyboard.instantiateViewController(withIdentifier: "DocumentsViewController") as? DocumentsViewController
        documentsVC.delegate = self
        addChild(documentsVC)
        documentsUnderlyingView.addSubview(documentsVC.view)
        documentsVC.view.frame = documentsUnderlyingView.bounds
        documentsVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        documentsVC.didMove(toParent: self)
        documentsVC.collectionView.refreshLayout()
        documentsVC.setNote(note: SKFileManager.activeNote!)
        
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
        canvasViewLongPressGesture.allowedTouchTypes = [0]
        
        //Drawing Recognition - This loads the labels for the drawing recognition's CoreML model.
        if let path = Bundle.main.path(forResource: "labels", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let labelNames = data.components(separatedBy: .newlines).filter { $0.count > 0 }
                self.labelNames.append(contentsOf: labelNames)
            } catch {
                log.error("Could not load labels for drawing recognition model: \(error)")
            }
        }
        
        setupHelpLines()
        self.rightScreenSidePanGesture.edges = [.right]
        self.topicsBadgeHub = BadgeHub(view: topicsButton)
        self.topicsBadgeHub.scaleCircleSize(by: 0.55)
        self.topicsBadgeHub.moveCircleBy(x: 4, y: -6)
        self.topicsBadgeHub.setCount(SKFileManager.activeNote!.documents.count)
        
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        view.addInteraction(interaction)
        
        spotlightHelper = SpotlightHelper()
        bioportalHelper = BioPortalHelper()
        tagmeHelper = TAGMEHelper()
        
        canvasView.bringSubviewToFront(drawingInsertionCanvas)
        
        relatedNotesCollectionView.register(UINib(nibName: "SimilarNoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: reuseSimilarNoteIdentifier)
        relatedNotesCollectionView.delegate = self
        relatedNotesCollectionView.dataSource = self
        
        self.oldDocuments = SKFileManager.activeNote!.documents
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.notifiedReceiveSketchnote(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_RECEIVE_NOTE), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        SKFileManager.activeNote!.delegate = self
        
        setupConceptHighlights()
        setupDrawingRegions()
          
        self.canvasView.drawing = SKFileManager.activeNote!.getCurrentPage().canvasDrawing
        updatePaginationButtons()
        
        self.refreshHelpLines()
        self.refreshHelpLinesButton()
        
        self.refreshRelatedNotes()
        self.updateTopicsCount()
    }
    
    // Notification Center events
    @objc func notifiedReceiveSketchnote(_ noti : Notification)  {
        let banner = FloatingNotificationBanner(title: "A user has shared a note with you", subtitle: "You can view it on the home page.", style: .info)
        banner.show()
    }
    
    // This function is called when the user closes the page, i.e. stops editing the note, and the app returns to the home page.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
        case "Placeholder":
            print("Placeholder")
            break
        case "CloseNote":
            if !isDeletingNote {
                if textRecognitionTimer != nil {
                    textRecognitionTimer!.invalidate()
                }
                if saveTimer != nil {
                    saveTimer!.invalidate()
                }
                documentsVC.bookshelfUpdateTimer?.reset(nil)
                for helpLine in self.helpLinesHorizontal {
                    helpLine.removeFromSuperview()
                }
                for helpLine in self.helpLinesVertical {
                    helpLine.removeFromSuperview()
                }
                if topicsShown {
                    toggleConceptHighlight()
                }
                self.processDrawingRecognition()
                SKFileManager.activeNote!.setUpdateDate()
                SKFileManager.activeNote!.getCurrentPage().canvasDrawing = self.canvasView.drawing
                SKFileManager.save(file: SKFileManager.activeNote!)
                log.info("Closing & saving note.")
            }
            else {
                log.info("Deleting note.")
            }
            break
        case "NoteOptions":
            if let destination = segue.destination as? NoteOptionsTableViewController {
                destination.delegate = self
                destination.canDeletePage = (SKFileManager.activeNote!.pages.count > 1)
            }
            break
        case "BookshelfOptions":
            if let destination = segue.destination as? BookshelfOptionsTableViewController {
                destination.delegate = self
                destination.currentFilter = documentsVC.bookshelfFilter
            }
            break
        case "ViewNoteText":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? NoteTextViewController {
                    destinationViewController.note = SKFileManager.activeNote!
                }
                
            }
            break
        case "ShareNote":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? ShareNoteViewController {
                    destinationViewController.note = SKFileManager.activeNote!
                }
            }
            break
        default:
            log.error("Default segue case triggered.")
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
    
    private func processDrawingRecognition() {
        let canvasImage = canvasView.drawing.image(from: CGRect(x: canvasView.frame.minX, y: canvasView.frame.minY, width: canvasView.contentSize.width, height: canvasView.contentSize.height), scale: 1.0)
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) { // Handle screen orientation change
        super.viewWillTransition(to: size, with: coordinator)
        self.refreshHelpLines()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        var drawingViewBorderColor = UIColor.black.cgColor
        if traitCollection.userInterfaceStyle == .dark {
            drawingViewBorderColor = UIColor.white.cgColor
        }
        for drawingRegionView in drawingViews {
            drawingRegionView.layer.borderColor = drawingViewBorderColor
        }
    }
    
    private func setupHelpLines() {
        for helpLine in self.helpLinesHorizontal {
            helpLine.removeFromSuperview()
        }
        for helpLine in self.helpLinesVertical {
            helpLine.removeFromSuperview()
        }
        self.helpLinesHorizontal = [HoritonzalHelpLine]()
        self.helpLinesVertical = [VerticalHelpLine]()
        var height = CGFloat(20)
        while (CGFloat(height) < self.canvasView.bounds.height + 80) {
            let line = HoritonzalHelpLine(frame: CGRect(x: 0, y: height, width: UIScreen.main.bounds.width, height: 1))
            
            line.isUserInteractionEnabled = false
            line.isHidden = true
            self.backdropView.addSubview(line)
            self.helpLinesHorizontal.append(line)
            height = height + 20
        }
        var width = CGFloat(20)
        while (CGFloat(width) < UIScreen.main.bounds.width + 80) {
            let line = VerticalHelpLine(frame: CGRect(x: width, y: 0, width: 1, height: self.canvasView.bounds.height))
    
            line.isUserInteractionEnabled = false
            line.isHidden = true
            self.backdropView.addSubview(line)
            self.helpLinesVertical.append(line)
            width = width + 20
        }
    }
    
    private func refreshHelpLines() {
        self.setupHelpLines()
        
        switch SKFileManager.activeNote!.helpLinesType {
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
        refreshHelpLinesButton()
    }
    
    @IBAction func helpLinesButtonTapped(_ sender: UIButton) {
        self.toggleHelpLinesType()
    }
    
    private func toggleHelpLinesType() {
        switch SKFileManager.activeNote!.helpLinesType {
        case .None:
            SKFileManager.activeNote!.helpLinesType = .Horizontal
            for line in helpLinesHorizontal {
                line.isHidden = false
            }
            for line in helpLinesVertical {
                line.isHidden = true
            }
            break
        case .Horizontal:
            SKFileManager.activeNote!.helpLinesType = .Grid
            for line in helpLinesHorizontal {
                line.isHidden = false
            }
            for line in helpLinesVertical {
                line.isHidden = false
            }
            break
        case .Grid:
            SKFileManager.activeNote!.helpLinesType = .None
            hideAllHelpLines()
            break
        }
        refreshHelpLinesButton()
        SKFileManager.save(file: SKFileManager.activeNote!)
    }
    
    private func refreshHelpLinesButton() {
        switch SKFileManager.activeNote!.helpLinesType {
        case .None:
            helpLinesButton.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
            helpLinesButton.tintColor = .white
            break
        case .Horizontal:
            helpLinesButton.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
            helpLinesButton.tintColor = self.view.tintColor
            break
        case .Grid:
            helpLinesButton.tintColor = self.view.tintColor
            helpLinesButton.setImage(UIImage(systemName: "grid"), for: .normal)
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
    
    // MARK: Highlighting recognized concepts/topics on the canvas
    private func setupConceptHighlights() {
        conceptHighlights = [UIView : [Document]]()
        let documents = SKFileManager.activeNote!.documents
        for textData in SKFileManager.activeNote!.getCurrentPage().noteTextArray {
            for document in documents {
                var documentTitle = document.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let TAGMEdocument = document as? TAGMEDocument {
                    if let spot = TAGMEdocument.spot {
                        documentTitle = spot.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    }
                }
                if textData.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().contains(documentTitle) {
                    for block in textData.blocks {
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
            
            let resolutionView = viewSize.width / viewSize.height
            let resolutionImage = imageSize.width / imageSize.height
            
            var scale: CGFloat
            if resolutionView > resolutionImage {
                scale = viewSize.height / imageSize.height
            } else {
                scale = viewSize.width / imageSize.width
            }
            
            let featureWidthScaled = featureFrame.size.width * scale
            let featureHeightScaled = featureFrame.size.height * scale
            
            let imageWidthScaled = imageSize.width * scale
            let imageHeightScaled = imageSize.height * scale
            let imagePointXScaled = (viewSize.width - imageWidthScaled) / 2
            let imagePointYScaled = (viewSize.height - imageHeightScaled) / 2
            
            let featurePointXScaled = imagePointXScaled + featureFrame.origin.x * scale
            let featurePointYScaled = imagePointYScaled + featureFrame.origin.y * scale
            
            return CGRect(x: featurePointXScaled,
                          y: featurePointYScaled,
                          width: featureWidthScaled,
                          height: featureHeightScaled)
    }
    
    @objc func handleConceptHighlightTap(_ sender: UITapGestureRecognizer) {
        if let conceptHighlightView = sender.view {
            if let documents = self.conceptHighlights[conceptHighlightView] {
                if documentsVC.bookshelfState == .Topic && documentsVC.selectedTopicDocuments != nil && documentsVC.selectedTopicDocuments! == documents {
                    documentsVC.clearTopicDocuments()
                }
                else {
                    documentsVC.selectedTopicDocuments = documents
                    documentsVC.updateBookshelfState(state: .Topic)
                    documentsVC.showTopicDocuments(documents: documents)
                }
                if bookshelf.isHidden {
                    showBookshelf()
                }
            }
        }
    }
    
    private func toggleConceptHighlight() {
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
        for (view, _) in self.conceptHighlights {
            view.isHidden = !topicsShown
        }
    }
    
    var topicsShown = false
    @IBAction func topicsTapped(_ sender: UIButton) {
        self.toggleConceptHighlight()
    }
    
    private func clearConceptHighlights() {
        for (view, _) in conceptHighlights {
            view.removeFromSuperview()
        }
        self.conceptHighlights = [UIView : [Document]]()
        topicsButton.tintColor = .white
        topicsButton.setTitleColor(.white, for: .normal)
    }
    
    @IBAction func canvasViewLongPressed(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            for (view, doc) in conceptHighlights {
                if view.frame.contains(sender.location(in: canvasView)) {
                    log.info("Highlighting concept")
                    let documentPreviewVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "DocumentPreviewViewController") as? DocumentPreviewViewController
                    if let documentPreviewVC = documentPreviewVC {
                        documentPreviewVC.modalPresentationStyle = .popover
                        documentPreviewVC.popoverPresentationController?.sourceView = view
                        present(documentPreviewVC, animated: true, completion:nil)
                        documentPreviewVC.imageView.image = doc[0].previewImage
                        documentPreviewVC.titleLabel.text = doc[0].title
                        documentPreviewVC.bodyTextView.text = doc[0].description

                    }
                }
            }
        }
    }
    
    func noteOptionSelected(option: NoteOption) {
        switch option {
        case .Annotate:
            self.processHandwritingRecognition()
            break
        case .SetTitle:
            let alertController = UIAlertController(title: "Rename Note", message: nil, preferredStyle: .alert)
            let confirmAction = UIAlertAction(title: "Set", style: .default) { (_) in
                let name = alertController.textFields?[0].text
                SKFileManager.activeNote!.setName(name: name ?? "Untitled")
                SKFileManager.save(file: SKFileManager.activeNote!)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
            alertController.addTextField { (textField) in
                textField.placeholder = "Enter Note Name"
            }
            alertController.addAction(confirmAction)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
            break
        case .ViewText:
            self.performSegue(withIdentifier: "ViewNoteText", sender: self)
            break
        case .CopyText:
            UIPasteboard.general.string = SKFileManager.activeNote!.getText()
            let banner = FloatingNotificationBanner(title: SKFileManager.activeNote!.getName(), subtitle: "Copied text to clipboard.", style: .info)
            banner.show()
            break
        case .ClearPage:
            SKFileManager.activeNote!.getCurrentPage().clear()
            updatePage()
            saveCurrentPage()
            break
        case .DeletePage:
            SKFileManager.activeNote!.deletePage(index: SKFileManager.activeNote!.activePageIndex)
            updatePage()
            updatePaginationButtons()
            break
        case .Share:
            self.performSegue(withIdentifier: "ShareNote", sender: self)
            break
        case .ResetDocuments:
            self.resetDocuments()
            break
        case .ResetTextRecognition:
            SKFileManager.activeNote!.documents = [Document]()
            documentsVC.items = [Document]()
            self.clearConceptHighlights()
            documentsVC.updateBookshelfState(state: .All)
            documentsVC.bookshelfFilter = .All
            self.processHandwritingRecognition()
            break
        case .DeleteNote:
            self.isDeletingNote = true
            SKFileManager.delete(file: SKFileManager.activeNote!)
            self.performSegue(withIdentifier: "CloseNote", sender: self)
        }
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
    
    //MARK: Handwriting recognition process
    let handwritingRecognizer = HandwritingRecognizer()
    
    private func processHandwritingRecognition() {
        let image = self.generateHandwritingRecognitionImage()
        handwritingRecognizer.recognize(spellcheck: false, image: image) { (success, noteText) in
            if success {
                SKFileManager.activeNote!.getCurrentPage().clearTextData()
                if let noteText = noteText {
                    SKFileManager.activeNote!.getCurrentPage().noteTextArray.append(noteText)
                    self.annotateText(text: SKFileManager.activeNote!.getText())
                    log.info(noteText.spellchecked)
                }
            }
            else {
                self.activityIndicator.stopAnimating()
                log.error("Handwriting recognition returned no result.")
            }
        }
    }
    private func generateHandwritingRecognitionImage() -> UIImage {
        var noteImage = canvasView.drawing.image(from: CGRect(x: canvasView.frame.minX, y: canvasView.frame.minY, width: canvasView.contentSize.width, height: canvasView.contentSize.height), scale: 1.0)
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
            self.tagmeHelper.fetch(text: text, note: SKFileManager.activeNote!)
            self.bioportalHelper.fetch(text: text, note: SKFileManager.activeNote!)
            self.bioportalHelper.fetchCHEBI(text: text, note: SKFileManager.activeNote!)
        }
    }
    
    
    @IBAction func bookshelfButtonTapped(_ sender: UIButton) {
        let animation = AnimationType.rotate(angle: 360)
        sender.animate(animations: [animation])
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
        let animation = AnimationType.from(direction: .right, offset: 400.0)
        bookshelf.animate(animations: [animation])
    }
    
    private func closeBookshelf() {
        bookshelfButton.tintColor = .white
        bookshelfLeftConstraint.constant = UIScreen.main.bounds.maxX - 400
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
            log.info("Save timer reset.")
        }
        saveTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(onSaveTimerFires), userInfo: nil, repeats: false)
        log.info("Save timer started.")
    }
    @objc func onSaveTimerFires()
    {
        saveTimer?.invalidate()
        saveTimer = nil
        log.info("Auto-saving sketchnote strokes and text data.")
        SKFileManager.activeNote!.getCurrentPage().canvasDrawing = self.canvasView.drawing
        SKFileManager.save(file: SKFileManager.activeNote!)
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
                log.info(top5.map { $0.key + "(" + String($0.value) + ")"}.joined(separator: ", "))
                
                for (label, score) in top5 {
                    if score > 0.4 {
                        log.info("Adding recognized drawing's label: " + label)
                        SKFileManager.activeNote!.getCurrentPage().addDrawing(drawing: label)
                    }
                }
            }
            else {
                log.info("Waiting for drawing")
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
                if (bookshelfLeftConstraint.constant + deltaX) >= 0 && UIScreen.main.bounds.maxX - currentTouchPoint.x >= 400 {
                    bookshelfLeftConstraint.constant += deltaX
                }
                
                
                if UIScreen.main.bounds.maxX - currentTouchPoint.x <= 400 {
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
                if UIScreen.main.bounds.maxX - currentTouchPoint.x <= 400 {
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
    let reuseSimilarNoteIdentifier = "similarNoteCell"
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.relatedNotes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseSimilarNoteIdentifier, for: indexPath as IndexPath) as! SimilarNoteCollectionViewCell
        /*cell.setNote(note: self.relatedNotes[indexPath.item], similarityRating: SKFileManager.activeNote!.similarTo(note: self.relatedNotes[indexPath.item]))*/
        return cell
    }
    
    // MARK: - UICollectionViewDelegate protocol
    
    var openNote : NoteX?
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let note = self.relatedNotes[indexPath.item]
        let alert = UIAlertController(title: "Open Note", message: "Close this note and open the note " + note.getName() + "?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open", style: .default, handler: { action in
            self.openNote = note
            self.saveCurrentPage()
            if self.textRecognitionTimer != nil {
                self.textRecognitionTimer!.invalidate()
            }
            if self.saveTimer != nil {
                self.saveTimer!.invalidate()
            }
            self.documentsVC.bookshelfUpdateTimer?.reset(nil)
            self.performSegue(withIdentifier: "CloseNote", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                log.info("Not opening note.")
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(340), height: CGFloat(210))
    }
    
    private func updateBookshelf() {
        documentsVC.updateBookshelf()
    }
    
    private func updateBookshelfState(state: BookshelfState) {
        documentsVC.updateBookshelfState(state: state)
    }
    
    private func startBookshelfUpdateTimer() {
        documentsVC.startBookshelfUpdateTimer()
    }
    
    // MARK: NoteXDelegate
    func noteHasNewDocument(note: NoteX, document: Document) {
        documentsVC.noteHasNewDocument(note: note, document: document)
    }
    func noteHasRemovedDocument(note: NoteX, document: Document) {
        documentsVC.noteDocumentHasChanged(note: note, document: document)
    }
    func noteDocumentHasChanged(note: NoteX, document: Document) {
        documentsVC.noteDocumentHasChanged(note: note, document: document)
    }
    func noteHasChanged(note: NoteX) {
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in
            return self.makeRelatedNoteContextMenu(note: self.relatedNotes[indexPath.row])
        })
    }
    private func makeRelatedNoteContextMenu(note: NoteX) -> UIMenu {
        let mergeAction = UIAction(title: "Merge", image: UIImage(systemName: "arrow.merge")) { action in
            let alert = UIAlertController(title: "Merge Note", message: "Are you sure you want to merge this note with the related note? This will delete the related note.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Merge", style: .destructive, handler: { action in
                SKFileManager.activeNote!.mergeWith(note: note)
                SKFileManager.save(file: SKFileManager.activeNote!)
                if SKFileManager.activeNote! != note {
                    SKFileManager.delete(file: note)
                }
                log.info("Merged notes.")
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
                  log.info("Not merging note.")
            }))
            self.present(alert, animated: true, completion: nil)
        }
        let mergeTagsAction = UIAction(title: "Merge Tags", image: UIImage(systemName: "tag.fill")) { action in
            SKFileManager.activeNote!.mergeTagsWith(note: note)
            SKFileManager.save(file: SKFileManager.activeNote!)
        }
        return UIMenu(title: note.getName(), children: [mergeAction, mergeTagsAction])
    }
    
    private func showTopicDocuments(documents: [Document]) {
        documentsVC.showTopicDocuments(documents: documents)
    }
    
    // MARK: Collection view document filtering
    @IBOutlet weak var bookshelfOptionsButton: UIButton!
    
    //MARK: Drawing insertion mode
    private func setupDrawingRegions() {
        let drawingRegionRects = SKFileManager.activeNote!.getCurrentPage().drawingViewRects
        for rect in drawingRegionRects {
            let region = UIView(frame: rect)
            region.layer.borderColor = UIColor.label.cgColor
            region.layer.borderWidth = 1
            drawingInsertionCanvas.addSubview(region)
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleDrawingRegionTap(_:)))
            region.addGestureRecognizer(tapGesture)
            region.isUserInteractionEnabled = true
            drawingViews.append(region)
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
                    SKFileManager.activeNote!.getCurrentPage().addDrawingViewRect(rect: currentDrawingRegion.frame)
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
                    SKFileManager.activeNote!.getCurrentPage().removeDrawingViewRect(rect: drawingRegion.frame)
                }
            })
            popMenu.addAction(action)
            popMenu.addAction(closeAction)
            self.present(popMenu, animated: true, completion: nil)
        }
    }
    
    // Mark: Pagination
    @IBAction func previousPageTapped(_ sender: UIButton) {
        previousPage()
    }
    
    @IBAction func nextPageTapped(_ sender: UIButton) {
        nextPage()
    }
    
    func previousPage() {
        if SKFileManager.activeNote!.hasPreviousPage() {
            UIView.animate(withDuration: 1.0, animations: {
                let animation = CATransition()
                animation.duration = 1.2
                animation.startProgress = 0.0
                animation.endProgress = 1.0
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
                animation.type = CATransitionType(rawValue: "pageCurl")
                animation.subtype = CATransitionSubtype(rawValue: "fromLeft")
                animation.isRemovedOnCompletion = false
                animation.fillMode = CAMediaTimingFillMode(rawValue: "extended")
                self.canvasView.layer.add(animation, forKey: "pageFlipAnimation")
            })
        }
        saveCurrentPage()
        SKFileManager.activeNote!.previousPage()
        updatePage()
        updatePaginationButtons()
    }
    func nextPage() {
        if SKFileManager.activeNote!.hasNextPage() {
            UIView.animate(withDuration: 1.0, animations: {
                let animation = CATransition()
                animation.duration = 1.2
                animation.startProgress = 0.0
                animation.endProgress = 1.0
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
                animation.type = CATransitionType(rawValue: "pageCurl")
                animation.subtype = CATransitionSubtype(rawValue: "fromRight")
                animation.isRemovedOnCompletion = false
                animation.fillMode = CAMediaTimingFillMode(rawValue: "extended")
                self.canvasView.layer.add(animation, forKey: "pageFlipAnimation")
                //self.animatedUIView.addSubview(tempUIView)
            })
        }
        saveCurrentPage()
        SKFileManager.activeNote!.nextPage()
        updatePage()
        updatePaginationButtons()
    }
    
    
    @IBAction func pageButtonTapped(_ sender: UIButton) {
        self.showInputDialog(title: "Go to page:", subtitle: nil, actionTitle: "Go", cancelTitle: "Cancel", inputPlaceholder: "Page Number", inputKeyboardType: .numberPad, cancelHandler: nil)
            { (input:String?) in
                if input != nil && Int(input!) != nil {
                    if let pageNumber = Int(input!) {
                        if (pageNumber - 1) >= 0 && (pageNumber - 1) < SKFileManager.activeNote!.pages.count && (pageNumber - 1) != SKFileManager.activeNote!.activePageIndex {
                            self.saveCurrentPage()
                            SKFileManager.activeNote!.activePageIndex = (pageNumber - 1)
                            self.updatePage()
                            self.updatePaginationButtons()
                        }
                    }
                }
            }
    }
    @IBAction func newPageTapped(_ sender: UIButton) {
        let newPage = NoteXPage()
        SKFileManager.activeNote!.pages.insert(newPage, at: SKFileManager.activeNote!.activePageIndex + 1)
        saveCurrentPage()
        SKFileManager.activeNote!.nextPage()
        updatePage()
        saveCurrentPage()
        updatePaginationButtons()
    }
        
    private func updatePaginationButtons() {
        previousPageButton.isEnabled = SKFileManager.activeNote!.hasPreviousPage()
        nextPageButton.isEnabled = SKFileManager.activeNote!.hasNextPage()
        pageButton.setTitle("Page \(SKFileManager.activeNote!.activePageIndex + 1)", for: .normal)
    }
    
    private func updatePage() {
        self.canvasView.drawing = SKFileManager.activeNote!.getCurrentPage().canvasDrawing
        clearConceptHighlights()
        setupConceptHighlights()
        drawingViews = [UIView]()
        setupDrawingRegions()
        if previousStateOfTopicsShown {
            toggleConceptHighlight()
        }
    }
    
    var previousStateOfTopicsShown = false
    private func saveCurrentPage() {
        if textRecognitionTimer != nil {
            textRecognitionTimer!.invalidate()
        }
        if saveTimer != nil {
            saveTimer!.invalidate()
        }
        documentsVC.bookshelfUpdateTimer?.reset(nil)
        previousStateOfTopicsShown = topicsShown
        if topicsShown {
            self.toggleConceptHighlight()
        }
        self.processDrawingRecognition()
        SKFileManager.activeNote!.setUpdateDate()
        SKFileManager.activeNote!.getCurrentPage().canvasDrawing = self.canvasView.drawing
        SKFileManager.save(file: SKFileManager.activeNote!)
        log.info("Saved note for current page.")
    }
    
    // MARK : Related Notes collection view
    @IBOutlet var relatedNotesView: UIView!
    @IBOutlet var relatedNotesCollectionView: UICollectionView!
    @IBOutlet var relatedNotesButton: UIButton!
    var relatedNotes = [NoteX]()
    
    var similarityThreshold = 0.0
    var highSimilarity = 10.0
    @IBAction func documentsRelatedNotesSegmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            relatedNotesView.isHidden = true
            documentsUnderlyingView.isHidden = false
        }
        else {
            documentsUnderlyingView.isHidden = true
            relatedNotesView.isHidden = false
        }
    }
    @IBAction func lookForRelatedNotesTapped(_ sender: UIButton) {
        refreshRelatedNotes()
    }
    
    private func refreshRelatedNotes() {
        self.relatedNotes = [NoteX]()
        var allNotes = SKFileManager.notes
        allNotes.removeAll{$0 == SKFileManager.activeNote!}
        var highSimilarityCount = 0
        var anySimilarityCount = 0
        for note in allNotes {
            let similarity = SKFileManager.activeNote!.similarTo(note: note)
            if similarity > similarityThreshold {
                relatedNotes.append(note)
            }
            if similarity > 0.0 {
                anySimilarityCount += 1
            }
            if similarity > highSimilarity {
                highSimilarityCount += 1
            }
        }
        relatedNotesCollectionView.reloadData()
        
        bookshelfSegmentedControl.setTitle("Related Notes (\(relatedNotes.count))", forSegmentAt: 1)
        relatedNotesSegmentedControl.setTitle("Any (\(anySimilarityCount))", forSegmentAt: 0)
        relatedNotesSegmentedControl.setTitle("High Similarity (\(highSimilarityCount))", forSegmentAt: 1)
    }
    @IBAction func similaritySegmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            similarityThreshold = 0.0
        }
        else {
            similarityThreshold = 10.0
        }
        refreshRelatedNotes()
    }
    
    // MARK: Documents View Controller delegate
    func resetDocuments() {
        self.clearConceptHighlights()
        self.annotateText(text: SKFileManager.activeNote!.getText())
    }
    var oldDocuments: [Document]!
    func updateTopicsCount() {
        self.topicsBadgeHub.setCount(SKFileManager.activeNote!.documents.count)
        let differences = zip(oldDocuments, SKFileManager.activeNote!.documents).map {$0.0 == $0.1}
        if differences.count > 0 {
            setupConceptHighlights()
        }
        bookshelfSegmentedControl.setTitle("Documents (\(SKFileManager.activeNote!.documents.count))", forSegmentAt: 0)
    }
    
    // MARK: Bookshelf Options Delegate
    
    func bookshelfOptionSelected(option: BookshelfOption) {
        documentsVC.setFilter(option: option)
    }
    
    // Note Pages Bottom Sheet
    
    @IBAction func pageBrowserTapped(_ sender: UIButton) {
        showNotePagesBottomSheet()
    }
    private func showNotePagesBottomSheet() {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let notePagesViewController = storyboard.instantiateViewController(withIdentifier: "NotePagesViewController") as! NotePagesViewController
        notePagesViewController.delegate = self
        let bottomNotePagesSheet = MDCBottomSheetController(contentViewController: notePagesViewController)
        self.present(bottomNotePagesSheet, animated: true, completion: nil)
    }

    func notePageSelected(index: Int) {
        if SKFileManager.activeNote!.activePageIndex != index {
            self.saveCurrentPage()
            SKFileManager.activeNote!.activePageIndex = index
            self.updatePage()
            self.updatePaginationButtons()
        }
    }
    func notePagesReordered() {
        self.updatePaginationButtons()
    }
    @IBAction func canvasRightSwiped(_ sender: UISwipeGestureRecognizer) {
        if sender.state == .ended {
            previousPage()
        }
    }
    @IBAction func canvasLeftSwiped(_ sender: UISwipeGestureRecognizer) {
        if sender.state == .ended {
            nextPage()
        }
    }
    @IBAction func canvasUpSwiped(_ sender: UISwipeGestureRecognizer) {
        showNotePagesBottomSheet()
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
        context.setStrokeColor(#colorLiteral(red: 0.8374180198, green: 0.8374378085, blue: 0.8374271393, alpha: 1))
        if UITraitCollection.current.userInterfaceStyle == .dark {
            context.setStrokeColor(#colorLiteral(red: 0.5704585314, green: 0.5704723597, blue: 0.5704649091, alpha: 1))
        }
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
        context.setStrokeColor(#colorLiteral(red: 0.8374180198, green: 0.8374378085, blue: 0.8374271393, alpha: 1))
        if UITraitCollection.current.userInterfaceStyle == .dark {
            context.setStrokeColor(#colorLiteral(red: 0.5704585314, green: 0.5704723597, blue: 0.5704649091, alpha: 1))
        }
        context.move(to: CGPoint(x: 0, y: 0))
        context.addLine(to: CGPoint(x: 0, y: self.frame.height))
        context.strokePath()
    }
}
