//
//  SketchNoteViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import PencilKit
import VisionKit
import MobileCoreServices
import PDFKit

import Firebase
import NVActivityIndicatorView
import Repeat
import ViewAnimator
import Connectivity
import GPUImage
import PopMenu
import GPUImage
import Highlightr
import Toast

class NoteViewController: UIViewController, UIPencilInteractionDelegate, UICollectionViewDelegate, NoteDelegate, PKCanvasViewDelegate, PKToolPickerObserver, UIScreenshotServiceDelegate, NoteOptionsDelegate, DocumentsViewControllerDelegate, NotePagesDelegate, VNDocumentCameraViewControllerDelegate, UIDocumentPickerDelegate, DraggableImageViewDelegate, DraggableTextViewDelegate, RelatedNotesVCDelegate, TextBoxViewControllerDelegate, MoveFileViewControllerDelegate, UIPopoverPresentationControllerDelegate {
    
    
    private var documentsVC: DocumentsViewController!
    
    @IBOutlet var backdropView: UIView!
    @IBOutlet var canvasView: PKCanvasView!
    
    @IBOutlet weak var topicsButton: UIButton!
    @IBOutlet weak var bookshelfButton: UIButton!
    @IBOutlet weak var manageDrawingsButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!
    @IBOutlet weak var previousPageButton: UIButton!
    @IBOutlet weak var nextPageButton: UIButton!
    @IBOutlet weak var newPageButton: UIButton!
    
    @IBOutlet weak var closeButton: UIButton!
    var topicsBadgeHub: BadgeHub!
    
    @IBOutlet var bookshelf: UIView!
    @IBOutlet var documentsUnderlyingView: UIView!
        
    @IBOutlet weak var helpLinesButton: UIButton!
    
    @IBOutlet var canvasViewLongPressGesture: UILongPressGestureRecognizer!
    var drawingViews = [UIView]()
    var drawingViewsShown = false
    
    var bioportalHelper: BioPortalHelper!
    
    var conceptHighlights = [UIView : [Document]]()
    
    var isDeletingNote = false
    
    var gridView: GridView?
    
    var conceptHighlightsInitialized = false
    
    var noteImageViews = [DraggableImageView : NoteImage]()
    @IBOutlet weak var pdfView: PDFView!
    
    var noteTextViews = [DraggableTextView : NoteTypedText]()
    
    var noteForRelatedNotes: Note?
    
    @IBOutlet weak var tagsButton: UIButton!
    
    private lazy var topicsOverlayView: UIView = {
      precondition(isViewLoaded)
      let topicsOverlayView = UIView(frame: .zero)
      topicsOverlayView.translatesAutoresizingMaskIntoConstraints = false
        topicsOverlayView.isUserInteractionEnabled = false
        topicsOverlayView.isOpaque = false
      return topicsOverlayView
    }()
    
    
    @IBAction func testEditorButtonTapped(_ sender: UIButton) {
        self.performSegue(withIdentifier: "ShowMoleculeEditor", sender: self)
    }
    // This function sets up the page and every element contained within it.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.tabBarController?.tabBar.isHidden = true
        
        self.canvasView.allowsFingerDrawing = false
        self.canvasView.delegate = self
        if let window = parent?.view.window {
            let toolPicker = PKToolPicker.shared(for: window)!
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            toolPicker.addObserver(self)
            canvasView.becomeFirstResponder()
        }
        canvasViewLongPressGesture.allowedTouchTypes = [0]
                
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        view.addInteraction(interaction)
        
        pdfView.autoScales = false
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = 0.1
        pdfView.scaleFactor = 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
            self.documentsVC = storyboard.instantiateViewController(withIdentifier: "DocumentsViewController") as? DocumentsViewController
            self.documentsVC.delegate = self
            self.addChild(self.documentsVC)
            self.documentsUnderlyingView.addSubview(self.documentsVC.view)
            self.documentsVC.view.frame = self.documentsUnderlyingView.bounds
            self.documentsVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.documentsVC.didMove(toParent: self)
            self.documentsVC.collectionView.refreshLayout()
            self.documentsVC.setNote(note: DataManager.activeNote!)
            self.bookshelfLeftDragView.curveTopCorners(size: 5)
            self.bookshelfButton.isEnabled = true
        }
        
        self.rightScreenSidePanGesture.edges = [.right]
        self.topicsBadgeHub = BadgeHub(view: topicsButton)
        self.topicsBadgeHub.scaleCircleSize(by: 0.55)
        self.topicsBadgeHub.moveCircleBy(x: 4, y: -6)
        
        bioportalHelper = BioPortalHelper()
        
        canvasView.bringSubviewToFront(drawingInsertionCanvas)
        
        self.oldDocuments = DataManager.activeNote!.getDocuments()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.notifiedReceiveSketchnote(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_RECEIVE_NOTE), object: nil)
        
        canvasView.addSubview(topicsOverlayView)
           NSLayoutConstraint.activate([
             topicsOverlayView.topAnchor.constraint(equalTo: canvasView.topAnchor),
             topicsOverlayView.leadingAnchor.constraint(equalTo: canvasView.leadingAnchor),
             topicsOverlayView.trailingAnchor.constraint(equalTo: canvasView.trailingAnchor),
             topicsOverlayView.bottomAnchor.constraint(equalTo: canvasView.bottomAnchor),
             ])
        
        self.load(page: DataManager.activeNote!.getCurrentPage())
    }
        
    override func viewWillAppear(_ animated: Bool) {
        DataManager.activeNote!.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.refreshHelpLines()
        self.refreshHelpLinesButton()
        
        if traitCollection.userInterfaceStyle == .dark {
            for drawingRegionView in drawingViews {
                drawingRegionView.layer.borderColor = UIColor.white.cgColor
            }
        }
    }
    
    // This function is called when the user closes the page, i.e. stops editing the note, and the app returns to the home page.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
        case "Placeholder":
            log.info("Placeholder")
            break
        case "CloseNote":
            if !isDeletingNote {
                self.stopTimers()
                if topicsShown {
                    toggleConceptHighlight()
                }
                self.processDrawingRecognition()
                DataManager.activeNote!.setUpdateDate()
                DataManager.activeNote!.getCurrentPage().canvasDrawing = self.canvasView.drawing
                DataManager.saveCurrentNote()
                log.info("Closing & saving note.")
            }
            else {
                log.info("Deleting note.")
            }
            break
        case "ShowNotePages":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? NotePagesViewController {
                    destinationViewController.delegate = self
                }
            }
            break
        case "NoteOptions":
            if let destination = segue.destination as? NoteOptionsTableViewController {
                destination.delegate = self
                destination.canDeletePage = (DataManager.activeNote!.pages.count > 1)
            }
            break
        case "ViewNoteText":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? NoteTextViewController {
                    destinationViewController.note = DataManager.activeNote!
                }
            }
            break
        case "ShareNote":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? ShareNoteViewController {
                    destinationViewController.note = DataManager.activeNote!
                }
            }
            break
        case "showRelatedNoteEditing":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? RelatedNotesViewController {
                    if let n = noteForRelatedNotes {
                        destinationViewController.delegate = self
                        destinationViewController.note = n
                        destinationViewController.context = .NoteEditing
                    }
                }
            }
            break
        case "ShowTextBoxVC":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? TextBoxViewController {
                    if let textView = self.draggableTextViewBeingEdited {
                        if let typedText = self.noteTextViews[textView] {
                            destinationViewController.delegate = self
                            destinationViewController.noteTypedText = typedText
                        }
                    }
                }
            }
            break
        case "MoveFileNoteEditing":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? MoveFileViewController {
                    destinationViewController.delegate = self
                    var temp = [File]()
                    temp.append(DataManager.activeNote!)
                    destinationViewController.filesToMove = temp
                }
            }
            break
        case "EditCurrentNoteTags":
            let destinationNC = segue.destination as! UINavigationController
            destinationNC.popoverPresentationController?.delegate = self
            if let destination = destinationNC.topViewController as? TagsViewController {
                destination.note = DataManager.activeNote!
            }
            break
        default:
            log.error("Default segue case triggered.")
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) { // Handle screen orientation change
        super.viewWillTransition(to: size, with: coordinator)
        if let gridView = gridView {
            gridView.removeFromSuperview()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshHelpLines()
        }
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
        self.refreshHelpLines()
    }
    
    // Notification Center events
    @objc func notifiedReceiveSketchnote(_ noti : Notification)  {
        self.view.makeToast("A note has been shared with you: View it on the home page.")
    }
    
    // ----------------
    func load(page: NotePage = DataManager.activeNote!.getCurrentPage()) {
        // Load canvas
        self.canvasView.drawing = page.canvasDrawing
        
        // Clear any existing images and text boxes
        self.clearFloatingViews()
        // Setup images and text boxes for this page
        self.setupNoteImages()
        self.setupNoteTypedTexts()
        
        // Clear any existing topic highlights on the canvas
        self.clearConceptHighlights()
        // Setup concept highlights
        if self.previousStateOfTopicsShown {
            self.setupTopicAnnotations(recognitionImageSize: canvasView.frame.size)
        }
        self.updateTopicsCount()
        
        // Reset drawing regions
        self.drawingViews = [UIView]()
        setupDrawingRegions()
        
        // Reset PDF backdrop
        pdfView.document = nil
        if let backdropPDF = page.getPDFDocument() {
            pdfView.document = backdropPDF
            if let pdfScale = page.pdfScale {
                pdfView.scaleFactor = CGFloat(pdfScale)
            }
            else {
                pdfView.scaleFactor = 1.0
            }
        }
        
        self.updatePaginationButtons()

        self.canvasView.becomeFirstResponder()
    }
    
    // Topic Highlights (new)
    private func drawFrame(_ frame: CGRect, in color: UIColor, transform: CGAffineTransform) -> UIView {
      let transformedRect = frame.applying(transform)
      let view = UIUtilities.addRectangle(
        transformedRect,
        to: self.topicsOverlayView,
        color: color
      )
      return view
    }
    
    private func removeDetectionAnnotations() {
      for topicView in topicsOverlayView.subviews {
        topicView.removeFromSuperview()
      }
    }
    
    private func setupTopicAnnotations(recognitionImageSize: CGSize) {
        self.conceptHighlights = [UIView : [Document]]()
        self.removeDetectionAnnotations()
        let transform = self.transformMatrix(recognitionImageSize)

        let documents = DataManager.activeNote!.getDocuments()
        if let textData = DataManager.activeNote!.getCurrentPage().getNoteText() {
            for document in documents {
                var documentTitle = document.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let tagmeDocument = document as? TAGMEDocument {
                    if let spot = tagmeDocument.spot {
                        documentTitle = spot.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    }
                }
                else if let watDocument = document as? WATDocument {
                    if let spot = watDocument.spot {
                        documentTitle = spot.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    }
                }
                if textData.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().contains(documentTitle) {
                    for block in textData.blocks {
                        for line in block.lines {
                            for element in line.elements {
                                let elementText = element.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                if elementText == documentTitle {
                                    let v = drawFrame(element.frame, in: .green, transform: transform)
                                    self.addTopicFrame(topicFrame: v, document: document)
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
                                            let fr = CGRect(x: line.elements[index].frame.minX, y: line.elements[index].frame.minY, width: width, height: line.elements[index].frame.height)
                                            let v = drawFrame(fr, in: .green, transform: transform)
                                            self.addTopicFrame(topicFrame: v, document: document)
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
//        let page = SKFileManager.activeNote!.getCurrentPage().getPDFDocument()!.page(at: 0)!
//        //let f = page.selectionForWord(at: CGPoint(x: 100, y: 100))?.bounds(for: page)
//        let sel = SKFileManager.activeNote!.getCurrentPage().getPDFDocument()!.findString("Cryptography", withOptions: .caseInsensitive)
//        let f = sel[0].bounds(for: sel[0].pages[0])
//        let test = UIView(frame: f)
//        test.frame = test.convert(test.bounds, to: pdfView.documentView!)
//        test.backgroundColor = .blue
//        pdfView.addSubview(test)
//        print(sel)
//        print(f)
//        let transform2 = self.transformMatrix2(pdfView.documentView!.frame.size)
//        let v = drawFrame(f, in: .blue, transform: transform2)
//        self.addTopicFrame(topicFrame: v, document: SKFileManager.activeNote!.documents[0])
    }
    private func addTopicFrame(topicFrame: UIView, document: Document) {
        if let existingTopicAnnotation = conceptHighlightExists(new: topicFrame.frame) {
            var newDocs = self.conceptHighlights[existingTopicAnnotation]!
            newDocs.append(document)
            self.conceptHighlights[existingTopicAnnotation] = newDocs
        }
        else {
            self.conceptHighlights[topicFrame] = [Document]()
            var newDocs = self.conceptHighlights[topicFrame]!
            newDocs.append(document)
            self.conceptHighlights[topicFrame] = newDocs
            topicFrame.isUserInteractionEnabled = false
        }
    }
    
    private func transformMatrix(_ recognitionImageSize: CGSize) -> CGAffineTransform {
      let imageViewWidth = canvasView.frame.size.width
      let imageViewHeight = canvasView.frame.size.height
      let imageWidth = recognitionImageSize.width
      let imageHeight = recognitionImageSize.height

      let imageViewAspectRatio = imageViewWidth / imageViewHeight
      let imageAspectRatio = imageWidth / imageHeight
      let scale = (imageViewAspectRatio > imageAspectRatio) ?
        imageViewHeight / imageHeight :
        imageViewWidth / imageWidth

      let scaledImageWidth = imageWidth * scale
      let scaledImageHeight = imageHeight * scale
      let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
      let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)

      var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
      transform = transform.scaledBy(x: scale, y: scale)
      return transform
    }
//    private func transformMatrix2(_ recognitionImageSize: CGSize) -> CGAffineTransform {
//      let imageViewWidth = pdfView.frame.size.width
//      let imageViewHeight = pdfView.frame.size.height
//      let imageWidth = recognitionImageSize.width
//      let imageHeight = recognitionImageSize.height
//
//      let imageViewAspectRatio = imageViewWidth / imageViewHeight
//      let imageAspectRatio = imageWidth / imageHeight
//      let scale = (imageViewAspectRatio > imageAspectRatio) ?
//        imageViewHeight / imageHeight :
//        imageViewWidth / imageWidth
//
//      let scaledImageWidth = imageWidth * scale
//      let scaledImageHeight = imageHeight * scale
//      let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
//      let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)
//
//      var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
//      transform = transform.scaledBy(x: scale, y: scale)
//      return transform
//    }
    
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        switch SettingsManager.pencilSideButton() {
        case .ManageDrawings:
            toggleManageDrawings()
            break
        case .System:
            break
        }
    }
    
    // Drawing recognition
    // In case the user's drawing has been recognized with at least a >30% confidence, the recognized drawing's label, e.g. "light bulb", is stored for the sketchnote.
    private var drawingRecognition = DrawingRecognition()
    private func processDrawingRecognition() {
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            let whiteBackground = UIColor.white.image(CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
            var canvasImage = canvasView.drawing.image(from: UIScreen.main.bounds, scale: 1.0)
            canvasImage = canvasImage.blackAndWhite() ?? canvasImage.toGrayscale
            DispatchQueue.main.async {
                var merged = whiteBackground.mergeWith(withImage: canvasImage)
                merged = merged.invertedImage() ?? merged
                for region in self.drawingViews {
                    let image = UIImage(cgImage: merged.cgImage!.cropping(to: region.frame)!)
                    if let recognition = self.drawingRecognition.recognize(image: image) {
                        log.info("Recognized drawing: \(recognition)")
                        DataManager.activeNote!.getCurrentPage().addDrawing(drawing: recognition.0)
                        DataManager.saveCurrentNote()
                    }
                }
            }
        }
    }
    
    private func refreshHelpLines() {
        if let gridView = gridView {
            gridView.removeFromSuperview()
        }
        gridView = GridView(frame: self.backdropView.frame)
        gridView!.backgroundColor = .clear
        if traitCollection.userInterfaceStyle == .light {
            gridView!.lineColor = .black
        }
        self.backdropView.addSubview(gridView!)
        self.gridView!.type = DataManager.activeNote!.helpLinesType
        gridView!.draw(self.backdropView.frame)
        refreshHelpLinesButton()
    }
    
    @IBAction func helpLinesButtonTapped(_ sender: UIButton) {
        self.toggleHelpLinesType()
    }
    
    private func toggleHelpLinesType() {
        switch DataManager.activeNote!.helpLinesType {
        case .None:
            DataManager.activeNote!.helpLinesType = .Horizontal
            break
        case .Horizontal:
            DataManager.activeNote!.helpLinesType = .Grid
            break
        case .Grid:
            DataManager.activeNote!.helpLinesType = .None
            break
        }
        refreshHelpLines()
        refreshHelpLinesButton()
        DataManager.saveCurrentNote()
    }
    
    private func refreshHelpLinesButton() {
        switch DataManager.activeNote!.helpLinesType {
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
        if let gridView = gridView {
            gridView.removeFromSuperview()
        }
    }
    
    private func setupNoteImages() {
        noteImageViews = [DraggableImageView : NoteImage]()
        for image in DataManager.activeNote!.getCurrentPage().images {
            let frame = CGRect(x: image.location.x, y: image.location.y, width: image.size.width, height: image.size.height)
            let draggableView = DraggableImageView(frame: frame)
            draggableView.image = image.image
            draggableView.delegate = self
            self.canvasView.addSubview(draggableView)
            self.canvasView.sendSubviewToBack(draggableView)
            self.noteImageViews[draggableView] = image
            draggableView.center = image.location
        }
    }
    
    private func setupNoteTypedTexts() {
        noteTextViews = [DraggableTextView : NoteTypedText]()
        for typedText in DataManager.activeNote!.getCurrentPage().typedTexts {
            let textView = self.createNoteTypedTextView(typedText: typedText)
            self.addTypedTextViewToCanvas(textView: textView, typedText: typedText)
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
    
    private func toggleConceptHighlight() {
        topicsShown = !topicsShown
        if topicsShown {
            setupTopicAnnotations(recognitionImageSize: canvasView.frame.size)
            topicsButton.tintColor = self.view.tintColor
            topicsButton.setTitleColor(self.view.tintColor, for: .normal)
        }
        else {
            topicsButton.tintColor = .white
            topicsButton.setTitleColor(.white, for: .normal)
            self.removeDetectionAnnotations()
        }
    }
    
    var topicsShown = false
    @IBAction func topicsTapped(_ sender: UIButton) {
        self.toggleConceptHighlight()
    }
    
    private func clearConceptHighlights() {
        removeDetectionAnnotations()
        self.conceptHighlights = [UIView : [Document]]()
        topicsButton.tintColor = .white
        topicsButton.setTitleColor(.white, for: .normal)
    }
    
    @IBAction func canvasViewLongPressed(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            var isRecognizingDrawing = true
            for (view, doc) in conceptHighlights {
                if view.frame.contains(sender.location(in: canvasView)) {
                    isRecognizingDrawing = false
                    log.info("Highlighting concept")
                    let documentPreviewVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "DocumentPreviewViewController") as? DocumentPreviewViewController
                    if let documentPreviewVC = documentPreviewVC {
                        documentPreviewVC.modalPresentationStyle = .popover
                        documentPreviewVC.popoverPresentationController?.sourceView = view
                        present(documentPreviewVC, animated: true, completion: nil)
                        doc[0].retrieveImage(type: .Standard, completion: { result in
                            switch result {
                            case .success(let value):
                                if let value = value {
                                    DispatchQueue.main.async {
                                        documentPreviewVC.imageView.image = value
                                    }
                                }
                            case .failure(_):
                                log.error("No preview image found for document.")
                            }
                        })
                        documentPreviewVC.titleLabel.text = doc[0].title
                        documentPreviewVC.bodyTextView.text = doc[0].description
                    }
                }
            }
            if isRecognizingDrawing {
                self.processDrawingRecognition(atTouch: sender.location(in: canvasView))
            }
        }
    }
    
    private func processDrawingRecognition(atTouch loc: CGPoint) {
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            let whiteBackground = UIColor.white.image(CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
            var canvasImage = self.canvasView.drawing.image(from: UIScreen.main.bounds, scale: 1.0)
            canvasImage = canvasImage.blackAndWhite() ?? canvasImage.toGrayscale
             
            var merged = whiteBackground.mergeWith(withImage: canvasImage)
            merged = merged.invertedImage() ?? merged
            DispatchQueue.main.async {
                
                let regionSizes = [100, 150, 200]
                var bestPredictionLabel: String?
                var bestScore: Double?
                var bestRegion: UIView?
                for regionSize in regionSizes {
                    let region = UIView(frame: CGRect(x: Int(loc.x)-regionSize/2, y: Int(loc.y)-regionSize/2, width: regionSize, height: regionSize))
                    let image = UIImage(cgImage: merged.cgImage!.cropping(to: region.frame)!)
                    if let recognition = self.drawingRecognition.recognize(image: image) {
                        if bestPredictionLabel == nil || bestScore! < recognition.1 {
                            bestPredictionLabel = recognition.0
                            bestScore = recognition.1
                            bestRegion = region
                        }
                    }
                }
                if bestPredictionLabel != nil {
                    log.info("Recognized drawing at touched point: \(bestPredictionLabel!)")
                    if !DataManager.activeNote!.getCurrentPage().drawingViewRects.contains(bestRegion!.frame) {
                        bestRegion!.layer.borderColor = UIColor.label.cgColor
                        bestRegion!.layer.borderWidth = 1
                        self.drawingInsertionCanvas.addSubview(bestRegion!)
                        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleDrawingRegionTap(_:)))
                        bestRegion!.addGestureRecognizer(tapGesture)
                        bestRegion!.isUserInteractionEnabled = true
                        self.drawingViews.append(bestRegion!)
                        DataManager.activeNote!.getCurrentPage().addDrawing(drawing: bestPredictionLabel!)
                        DataManager.saveCurrentNote()
                        self.view.makeToast("Recognized drawing: \(bestPredictionLabel!)", duration: 1.0, position: .center)
                    }
                    else {
                        self.view.makeToast("Drawing is already recognized: \(bestPredictionLabel!)", duration: 1.0, position: .center)
                    }
                }
                else {
                    self.view.makeToast("No drawing recognized. Try long-pressing in the center of your drawing!", duration: 1.0, position: .center)
                }
            }
        }
    }
    
    func noteOptionSelected(option: NoteOption) {
        switch option {
        case .Annotate:
            self.processHandwritingRecognition()
            break
        case .RelatedNotes:
            self.noteForRelatedNotes = DataManager.activeNote!
            self.performSegue(withIdentifier: "showRelatedNoteEditing", sender: self)
            break
        case .SetTitle:
            let alertController = UIAlertController(title: "Rename Note", message: nil, preferredStyle: .alert)
            let confirmAction = UIAlertAction(title: "Set", style: .default) { (_) in
                let name = alertController.textFields?[0].text
                DataManager.activeNote!.setName(name: name ?? "Untitled")
                DataManager.save(file: DataManager.activeNote!)
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
            UIPasteboard.general.string = DataManager.activeNote!.getText()
            self.view.makeToast("Copied text to Clipboard.", title: DataManager.activeNote!.getName())
            break
        case .MoveFile:
            self.performSegue(withIdentifier: "MoveFileNoteEditing", sender: self)
            break
        case .ClearPage:
            DataManager.activeNote!.getCurrentPage().clear()
            self.load()
            self.saveCurrentPage()
            break
        case .DeletePage:
            _ = DataManager.activeNote!.deletePage(index: DataManager.activeNote!.activePageIndex)
            self.load()
            DataManager.saveCurrentNote()
            break
        case .Share:
            self.performSegue(withIdentifier: "ShareNote", sender: self)
            break
        case .ClearPDFPage:
            DataManager.activeNote!.getCurrentPage().backdropPDFData = nil
            self.pdfView.document = nil
            DataManager.save(file: DataManager.activeNote!)
        case .ResetDocuments:
            self.resetDocuments()
            break
        case .ResetTextRecognition:
            DataManager.activeNote!.clearDocuments()
            documentsVC.items = [Document]()
            self.clearConceptHighlights()
            documentsVC.updateBookshelfState(state: .All)
            documentsVC.bookshelfFilter = .All
            self.processHandwritingRecognition()
            break
        case .DeleteNote:
            self.isDeletingNote = true
            DataManager.delete(file: DataManager.activeNote!)
            self.performSegue(withIdentifier: "CloseNote", sender: self)
        }
    }
    
    // MoveFileViewControllerDelegate
    func movedFiles(files: [File]) {
        self.view.makeToast("Note moved.", duration: 1.0, position: .center)
    }
    
    func pdfScaleChanged(scale: Float) {
        pdfView.scaleFactor = CGFloat(scale)
        DataManager.activeNote!.getCurrentPage().pdfScale = scale
        self.startSaveTimer()
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
    
    //MARK: Handwriting recognition process
    let handwritingRecognizer = HandwritingRecognizer()
    
    private func processHandwritingRecognition() {
        self.generateHandwritingRecognitionImage(completion: { image in
            self.handwritingRecognizer.recognize(spellcheck: false, image: image) { (success, noteText) in
                if success {
                    DataManager.activeNote!.getCurrentPage().clearNoteText()
                    if let noteText = noteText {
                        DataManager.activeNote!.getCurrentPage().setNoteText(noteText: noteText)
                        self.startSaveTimer()
                        if self.topicsShown {
                            self.setupTopicAnnotations(recognitionImageSize: image.size)
                        }
                        self.annotateText(text: DataManager.activeNote!.getText())
                        log.info(noteText.spellchecked)
                    }
                }
                else {
                    log.error("Handwriting recognition returned no result.")
                }
            }
        })
    }
    private func generateHandwritingRecognitionImage(completion: @escaping (UIImage) -> Void){
        let page = DataManager.activeNote!.getCurrentPage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            var image = canvasView.drawing.image(from: canvasView.bounds, scale: 1.0)
            let canvasImage = image
            var pdfImage: UIImage?
            if let _ = page.getPDFDocument() {
                pdfImage = pdfView.asImage()
            }
            DispatchQueue.global(qos: .utility).async {
                if let pdfImage = pdfImage {
                    image = pdfImage.mergeWith2(withImage: canvasImage)
                }
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }
    
    var connectivity: Connectivity?
    func annotateText(text: String) {
        self.clearConceptHighlights()
        
        connectivity = Connectivity()
        connectivity!.framework = .network
        connectivity!.checkConnectivity { connectivity in
            log.info("Checking Internet connection.")
            switch connectivity.status {
                case .connected, .connectedViaWiFi, .connectedViaCellular:
                    log.info("Internet Connection detected.")
                    DispatchQueue.global(qos: .background).async {
                        if SettingsManager.getAnnotatorStatus(annotator: .TAGME) {
                            TAGMEHelper.shared.fetch(text: text, note: DataManager.activeNote!)
                        }
                        if SettingsManager.getAnnotatorStatus(annotator: .WAT) {
                            WATHelper.shared.fetch(text: text, note: DataManager.activeNote!)
                        }
                        if SettingsManager.getAnnotatorStatus(annotator: .BioPortal) {
                            self.bioportalHelper.fetch(text: text, note: DataManager.activeNote!)
                        }
                        if SettingsManager.getAnnotatorStatus(annotator: .CHEBI) {
                            self.bioportalHelper.fetchCHEBI(text: text, note: DataManager.activeNote!)
                        }
                    }
                    break
                default:
                    log.info("Internet Connection not detected.")
                    break
            }
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
        let animation = AnimationType.from(direction: .right, offset: 500)
        bookshelf.animate(animations: [animation])
    }
    
    private func closeBookshelf() {
        bookshelfButton.tintColor = .white
        bookshelfLeftConstraint.constant = UIScreen.main.bounds.maxX - 500
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
        if (canvasView.tool is PKInkingTool && (canvasView.tool as! PKInkingTool).inkType != PKInkingTool.InkType.marker) || canvasView.tool is PKEraserTool {
            if SettingsManager.automaticAnnotation() {
                self.startRecognitionTimer()
            }
        }
    }
    
    var pageChanged = false
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        self.resetHandwritingRecognition = true
        if pageChanged {
            pageChanged = false
        }
        else {
            DataManager.activeNote!.getCurrentPage().canvasDrawing = self.canvasView.drawing
            self.startSaveTimer()
        }
    }
    
    private func startRecognitionTimer() {
        if textRecognitionTimer != nil {
            textRecognitionTimer!.invalidate()
            textRecognitionTimer = nil
        }
        textRecognitionTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(onRecognitionTimerFires), userInfo: nil, repeats: false)
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
        }
        saveTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(onSaveTimerFires), userInfo: nil, repeats: false)
    }
    @objc func onSaveTimerFires()
    {
        saveTimer?.invalidate()
        saveTimer = nil
        log.info("Auto-saving note.")
        DataManager.saveCurrentNote()
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
    let reuseSimilarNoteIdentifier = "NoteCollectionViewCell"
    
    // MARK: - UICollectionViewDelegate protocol
    
    var openNote : Note?
    
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
    func noteHasNewDocument(note: Note, document: Document) {
        documentsVC.noteHasNewDocument(note: note, document: document)
        DataManager.saveCurrentNote()
    }
    func noteHasRemovedDocument(note: Note, document: Document) {
        documentsVC.noteDocumentHasChanged(note: note, document: document)
        DataManager.saveCurrentNote()
    }
    func noteDocumentHasChanged(note: Note, document: Document) {
        documentsVC.noteDocumentHasChanged(note: note, document: document)
        DataManager.saveCurrentNote()
    }
    func noteHasChanged(note: Note) {
    }
    
    // Related Notes VC delegate
    func openRelatedNote(note: Note) {
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
    }
    func mergedNotes(note1: Note, note2: Note) {
        self.updatePaginationButtons()
    }
    
    private func showTopicDocuments(documents: [Document]) {
        documentsVC.showTopicDocuments(documents: documents)
    }
    
    //MARK: Drawing insertion mode
    private func setupDrawingRegions() {
        let drawingRegionRects = DataManager.activeNote!.getCurrentPage().drawingViewRects
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
            self.view.makeToast("Draw a square around your drawing(s).", duration: 1.5, position: .center)
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
            if traitCollection.userInterfaceStyle == .dark {
                currentDrawingRegion?.layer.borderColor = UIColor.white.cgColor
            }
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
                    DataManager.activeNote!.getCurrentPage().addDrawingViewRect(rect: currentDrawingRegion.frame)
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
                    DataManager.activeNote!.getCurrentPage().removeDrawingViewRect(rect: drawingRegion.frame)
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
    
    var previousStateOfTopicsShown = false
    private func saveCurrentPage() {
        self.stopTimers()
        previousStateOfTopicsShown = topicsShown
        if topicsShown {
            self.toggleConceptHighlight()
        }
        self.processDrawingRecognition()
        DataManager.activeNote!.setUpdateDate()
        DataManager.activeNote!.getCurrentPage().canvasDrawing = self.canvasView.drawing
        DataManager.save(file: DataManager.activeNote!)
        log.info("Saved note for current page.")
    }
    
    func previousPage() {
        if DataManager.activeNote!.hasPreviousPage() {
            self.view.makeToast("Page \(DataManager.activeNote!.activePageIndex)/\(DataManager.activeNote!.pages.count)", duration: 1.0, position: .center)
            self.pageChanged = true
            if self.saveTimer != nil {
                self.saveCurrentPage()
            }
            DataManager.activeNote!.previousPage()
            self.load()
        }
    }
    func nextPage() {
        if DataManager.activeNote!.hasNextPage() {
            self.view.makeToast("Page \(DataManager.activeNote!.activePageIndex+2)/\(DataManager.activeNote!.pages.count)", duration: 1.0, position: .center)
            self.pageChanged = true
            if self.saveTimer != nil {
                self.saveCurrentPage()
            }
            DataManager.activeNote!.nextPage()
            self.load()
        }
    }
    
    @IBAction func newPageTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
        let newPageAction = PopMenuDefaultAction(title: "New Page", image: UIImage(systemName: "plus.circle"),  didSelect: { action in
            let newPage = NotePage()
            DataManager.activeNote!.pages.insert(newPage, at: DataManager.activeNote!.activePageIndex + 1)
            self.saveCurrentPage()
            DataManager.activeNote!.nextPage()
            self.load()
            self.saveCurrentPage()
        })
        popMenu.addAction(newPageAction)
        let importItemsAction = PopMenuDefaultAction(title: "Import Note(s)/Image(s)...", image: UIImage(systemName: "doc"),  didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            self.displayDocumentPicker()
        })
        popMenu.addAction(importItemsAction)
        let scanAction = PopMenuDefaultAction(title: "Scan Document(s)...", image: UIImage(systemName: "doc.text.viewfinder"),  didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            let scannerVC = VNDocumentCameraViewController()
            scannerVC.delegate = self
            self.present(scannerVC, animated: true)
        })
        popMenu.addAction(scanAction)
        let imageImportAction = PopMenuDefaultAction(title: "Camera Roll...", image: UIImage(systemName: "photo"),  didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            self.displayImagePicker()
        })
        popMenu.addAction(imageImportAction)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true, completion: nil)
        for i in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: i)
            self.addNoteImage(image: image)
        }
        self.saveCurrentPage()
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        log.error(error)
        controller.dismiss(animated: true, completion: nil)
    }
    
    private func displayImagePicker() {
        ImagePickerHelper.displayImagePickerWithImageOutput(vc: self, completion: { images in
            for img in images {
                self.addNoteImage(image: img)
            }
            self.saveCurrentPage()
        })
    }
    
    private func displayDocumentPicker() {
        let types: [String] = ImportHelper.importUTTypes
        let documentPicker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .pageSheet
        documentPicker.allowsMultipleSelection = true
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if urls.count > 0 {
            self.view.makeToast("Imported the selected documents.")
            let (notes, images, pdfs, texts) = ImportHelper.importItems(urls: urls, n: DataManager.activeNote!)
            for img in images {
                self.addNoteImage(image: img)
            }
            var setPDFForCurrentPage = false
            for pdf in pdfs {
                for i in 0..<pdf.pageCount {
                    if let pdfPage = pdf.page(at: i) {
                        if !setPDFForCurrentPage {
                            setPDFForCurrentPage = true
                            DataManager.activeNote!.getCurrentPage().backdropPDFData = pdfPage.dataRepresentation
                            self.pdfView.document = PDFDocument(data: pdfPage.dataRepresentation!)
                        }
                        else {
                            let newPage = NotePage()
                            newPage.backdropPDFData = pdfPage.dataRepresentation
                            DataManager.activeNote!.pages.insert(newPage, at: DataManager.activeNote!.activePageIndex + 1)
                        }
                    }
                }
            }
            for text in texts {
                DataManager.activeNote!.getCurrentPage().typedTexts.append(text)
                let textView = self.createNoteTypedTextView(typedText: text)
                self.addTypedTextViewToCanvas(textView: textView, typedText: text)
            }
            DataManager.save(file: DataManager.activeNote!)
        }
    }
    
    private func createNoteTypedTextView(typedText: NoteTypedText) -> DraggableTextView {
        let frame = CGRect(x: typedText.location.x, y: typedText.location.y, width: typedText.size.width, height: typedText.size.height)
        let draggableView = DraggableTextView(frame: frame)
        let highlightr = Highlightr()!
        var highlightedText = highlightr.highlight(typedText.text)
        if !typedText.codeLanguage.isEmpty {
            highlightedText = highlightr.highlight(typedText.text, as: typedText.codeLanguage)
        }
        draggableView.attributedText = highlightedText
        draggableView.adjustFontSize()
        return draggableView
    }
    
    private func addTypedTextViewToCanvas(textView: DraggableTextView, typedText: NoteTypedText) {
        textView.draggableDelegate = self
        self.canvasView.addSubview(textView)
        self.canvasView.sendSubviewToBack(textView)
        self.noteTextViews[textView] = typedText
        textView.center = typedText.location
    }
    
    func draggableTextViewSizeChanged(source: DraggableTextView, scale: CGSize) {
        if let typedText = self.noteTextViews[source] {
            typedText.size = scale
            log.info(scale)
            DataManager.activeNote!.getCurrentPage().updateNoteTypedText(typedText: typedText)
            self.startSaveTimer()
        }
    }
    
    func draggableTextViewLocationChanged(source: DraggableTextView, location: CGPoint) {
        if let typedText = self.noteTextViews[source] {
            typedText.location = location
            DataManager.activeNote!.getCurrentPage().updateNoteTypedText(typedText: typedText)
            self.startSaveTimer()
        }
    }
    
    var draggableTextViewBeingEdited: DraggableTextView?
    func draggableTextViewLongPressed(source: DraggableTextView) {
        if let typedText =  self.noteTextViews[source] {
            let popMenu = PopMenuViewController(sourceView: source, actions: [PopMenuAction](), appearance: nil)
            let editOption = PopMenuDefaultAction(title: "Edit...", didSelect: { action in
                popMenu.dismiss(animated: true, completion: nil)
                self.draggableTextViewBeingEdited = source
                self.performSegue(withIdentifier: "ShowTextBoxVC", sender: self)
            })
            popMenu.addAction(editOption)
            let languageOption = PopMenuDefaultAction(title: "Change Language... (\(typedText.codeLanguage.lowercased().capitalizingFirstLetter()))", didSelect: { action in
                popMenu.dismiss(animated: true, completion: nil)
                self.showTypedTextLanguageOptions(source: source, typedText: typedText)
            })
            popMenu.addAction(languageOption)
            let copyTextAction = PopMenuDefaultAction(title: "Copy Text", didSelect: { action in
                UIPasteboard.general.string = typedText.text
            })
            popMenu.addAction(copyTextAction)
            let action = PopMenuDefaultAction(title: "Delete", didSelect: { action in
                DataManager.activeNote!.getCurrentPage().deleteTypedText(typedText: typedText)
                source.removeFromSuperview()
                self.noteTextViews[source] = nil
                self.startSaveTimer()
                self.view.makeToast("Deleted text box.", duration: 1, position: .center)
            })
            popMenu.addAction(action)
            let closeAction = PopMenuDefaultAction(title: "Close")
            popMenu.addAction(closeAction)
            self.present(popMenu, animated: true, completion: nil)
        }
    }
    
    private func showTypedTextLanguageOptions(source: DraggableTextView, typedText: NoteTypedText) {
        let alert = UIAlertController(title: "Code Language (\(typedText.codeLanguage.lowercased().capitalizingFirstLetter()))", message: "Choose the language for the syntax highlight.", preferredStyle: .alert)
        for lang in NoteTypedText.supportedLanguages {
            alert.addAction(UIAlertAction(title: NSLocalizedString(lang.lowercased().capitalizingFirstLetter(), comment: ""), style: .default, handler: { _ in
                typedText.codeLanguage = lang
                source.removeFromSuperview()
                self.noteTextViews[source] = nil
                self.addTypedTextViewToCanvas(textView: self.createNoteTypedTextView(typedText: typedText), typedText: typedText)
                self.highlightedTextView = nil
                DataManager.activeNote!.getCurrentPage().updateNoteTypedText(typedText: typedText)
                self.startSaveTimer()
                self.view.makeToast("Changed code language to \(lang.lowercased().capitalizingFirstLetter()).", duration: 1, position: .center)
            }))
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .default, handler: { _ in
            log.info("Cancelled: changing code language of text box.")
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func draggableTextViewTextChanged(source: DraggableTextView, text: String) {
        if let typedText = self.noteTextViews[source] {
            typedText.text = text
            DataManager.activeNote!.getCurrentPage().updateNoteTypedText(typedText: typedText)
            self.startSaveTimer()
        }
    }
    
    // TextBoxViewControllerDelegate
    func noteTypedTextSaveTriggered(typedText: NoteTypedText) {
        if let textView = draggableTextViewBeingEdited {
            if self.noteTextViews[textView] != nil {
                draggableTextViewTextChanged(source: textView, text: typedText.text)
                let highlightr = Highlightr()!
                var highlightedText = highlightr.highlight(typedText.text)
                if !typedText.codeLanguage.isEmpty {
                    highlightedText = highlightr.highlight(typedText.text, as: typedText.codeLanguage)
                }
                textView.attributedText = highlightedText
                textView.adjustFontSize()
            }
        }
    }
    
    private func addNoteImage(image: UIImage) {
        let noteImage = NoteImage(image: image)
        DataManager.activeNote!.getCurrentPage().images.append(noteImage)
        let frame = CGRect(x: 50, y: 50, width: 0.25 * image.size.width, height: 0.25 * image.size.height)
        let draggableView = DraggableImageView(frame: frame)
        draggableView.draggableView.lastScale = 1.0
        draggableView.image = image
        draggableView.delegate = self
        self.canvasView.addSubview(draggableView)
        self.canvasView.sendSubviewToBack(draggableView)
        self.noteImageViews[draggableView] = noteImage
    }
    
    func draggableImageViewSizeChanged(source: DraggableImageView, scale: CGSize) {
        if let noteImage = self.noteImageViews[source] {
            noteImage.size = scale
            log.info(scale)
            DataManager.activeNote!.getCurrentPage().updateNoteImage(noteImage: noteImage)
            self.startSaveTimer()
        }
    }
    
    func draggableImageViewLocationChanged(source: DraggableImageView, location: CGPoint) {
        if let noteImage = self.noteImageViews[source] {
            noteImage.location = location
            DataManager.activeNote!.getCurrentPage().updateNoteImage(noteImage: noteImage)
            self.startSaveTimer()
        }
    }
    
    func draggableImageViewDelete(source: DraggableImageView) {
        let popMenu = PopMenuViewController(sourceView: source, actions: [PopMenuAction](), appearance: nil)
        let closeAction = PopMenuDefaultAction(title: "Close")
        let action = PopMenuDefaultAction(title: "Delete Image", didSelect: { action in
            if let noteImage =  self.noteImageViews[source] {
                DataManager.activeNote!.getCurrentPage().deleteImage(noteImage: noteImage)
                source.removeFromSuperview()
                self.noteImageViews[source] = nil
                self.startSaveTimer()
            }
            
        })
        popMenu.addAction(action)
        popMenu.addAction(closeAction)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    private func updatePaginationButtons() {
        previousPageButton.isEnabled = DataManager.activeNote!.hasPreviousPage()
        nextPageButton.isEnabled = DataManager.activeNote!.hasNextPage()
    }
    
    private func clearFloatingViews() {
        for (view, _) in noteImageViews {
            view.removeFromSuperview()
        }
        for (view, _) in noteTextViews {
            view.removeFromSuperview()
        }
        self.noteImageViews = [DraggableImageView : NoteImage]()
        self.noteTextViews = [DraggableTextView : NoteTypedText]()
    }
    
    private func stopTimers() {
        if textRecognitionTimer != nil {
            textRecognitionTimer!.invalidate()
            textRecognitionTimer = nil
        }
        if saveTimer != nil {
            saveTimer!.invalidate()
            saveTimer = nil
        }
        documentsVC.bookshelfUpdateTimer?.reset(nil)
    }
    
    // MARK: Documents View Controller delegate
    func resetDocuments() {
        self.clearConceptHighlights()
        DataManager.activeNote!.clearDocuments()
        documentsVC.clear()
        DataManager.saveCurrentNote()
        self.annotateText(text: DataManager.activeNote!.getText())
    }
    var oldDocuments: [Document]!
    func updateTopicsCount() {
        self.topicsBadgeHub.setCount(DataManager.activeNote!.getDocuments(forCurrentPage: true).count)
        let differences = zip(oldDocuments, DataManager.activeNote!.getDocuments()).map {$0.0 == $0.1}
        if differences.count > 0 {
            if self.topicsShown {
                self.setupTopicAnnotations(recognitionImageSize: canvasView.frame.size)
            }
        }
    }
    
    private func showNotePagesBottomSheet() {
        self.performSegue(withIdentifier: "ShowNotePages", sender: self)
    }

    func notePageSelected(index: Int) {
        if DataManager.activeNote!.activePageIndex != index {
            if self.saveTimer != nil {
                self.saveCurrentPage()
            }
            DataManager.activeNote!.activePageIndex = index
            self.load()
        }
    }
    func notePagesReordered() {
        self.updatePaginationButtons()
    }
    func notePageDeleted() {
        self.load()
        self.saveCurrentPage()
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
    @IBAction func canvasTapped(_ sender: UITapGestureRecognizer) {
        if sender.state == .recognized {
            var found = false
            if self.topicsShown {
                for (view, documents) in self.conceptHighlights {
                    if view.frame.contains(sender.location(in: canvasView)) {
                        found = true
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
            if !found {
                if let highlightedImage = self.highlightedImage {
                    highlightedImage.setHighlight(isHighlighted: false)
                    canvasView.sendSubviewToBack(highlightedImage)
                    self.highlightedImage = nil
                }
                for (view, _) in noteImageViews {
                    if view.frame.contains(sender.location(in: canvasView)) {
                        self.highlightedImage = view
                        view.setHighlight(isHighlighted: true)
                        log.info("Tapped image on canvas.")
                        canvasView.bringSubviewToFront(view)
                        break
                    }
                }
                if let highlightedTextView = self.highlightedTextView {
                    highlightedTextView.setHighlight(isHighlighted: false)
                    canvasView.sendSubviewToBack(highlightedTextView)
                    self.highlightedTextView = nil
                }
                for (view, _) in noteTextViews {
                    if view.frame.contains(sender.location(in: canvasView)) {
                        self.highlightedTextView = view
                        view.setHighlight(isHighlighted: true)
                        log.info("Tapped text box on canvas.")
                        canvasView.bringSubviewToFront(view)
                        break
                    }
                }
            }
        }
    }
    var highlightedImage: DraggableImageView?
    var highlightedTextView: DraggableTextView?
    
    // MARK: Tags
}
