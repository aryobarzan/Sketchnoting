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
import SafariServices

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

class NoteViewController: UIViewController, UIPencilInteractionDelegate, UICollectionViewDelegate, NoteDelegate, PKCanvasViewDelegate, PKToolPickerObserver, UIScreenshotServiceDelegate, NoteOptionsDelegate, DocumentsViewControllerDelegate, NotePagesDelegate, VNDocumentCameraViewControllerDelegate, UIDocumentPickerDelegate, DraggableImageViewDelegate, DraggableTextViewDelegate, RelatedNotesVCDelegate, TextBoxViewControllerDelegate, MoveFileViewControllerDelegate, UIPopoverPresentationControllerDelegate, NoteInfoDelegate, PDFViewDelegate {
    
    //private var documentsVC: DocumentsViewController!
    private var documentsVC: NeoDocumentsVC!
    
    @IBOutlet var backdropView: UIView!
    @IBOutlet var canvasView: PKCanvasView!
    
    @IBOutlet weak var topicsButton: UIButton!
    @IBOutlet weak var bookshelfButton: UIButton!
    @IBOutlet weak var manageDrawingsButton: UIButton!
    @IBOutlet weak var optionsButton: UIButton!
    @IBOutlet weak var previousPageButton: UIButton!
    @IBOutlet weak var nextPageButton: UIButton!
    @IBOutlet weak var newPageButton: UIButton!
    @IBOutlet weak var noteTitleButton: UIButton!
    
    @IBOutlet weak var closeButton: UIButton!
    var topicsBadgeHub: BadgeHub!
    
    @IBOutlet var bookshelf: UIView!
    @IBOutlet var documentsUnderlyingView: UIView!
            
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
    
    var noteForRelatedNotes: (URL, Note)?
    
    @IBOutlet weak var tagsButton: UIButton!
    
    private lazy var topicsOverlayView: UIView = {
      precondition(isViewLoaded)
      let topicsOverlayView = UIView(frame: .zero)
      topicsOverlayView.translatesAutoresizingMaskIntoConstraints = false
        topicsOverlayView.isUserInteractionEnabled = false
        topicsOverlayView.isOpaque = false
      return topicsOverlayView
    }()
    
    // Main properties
    var note: (URL, Note)!
    
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
        
        pdfView.delegate = self
        pdfView.autoScales = false
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = 0.1
        pdfView.scaleFactor = 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
            self.documentsVC = storyboard.instantiateViewController(withIdentifier: "NeoDocumentsVC") as? NeoDocumentsVC
            self.addChild(self.documentsVC)
            self.documentsVC.delegate = self
            self.documentsUnderlyingView.addSubview(self.documentsVC.view)
            self.documentsVC.view.frame = self.documentsUnderlyingView.bounds
            self.documentsVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.documentsVC.didMove(toParent: self)
            self.documentsVC.collectionView.collectionViewLayout.invalidateLayout()
            self.documentsVC.setup(note: self.note)
            self.bookshelfLeftDragView.curveTopCorners(size: 5)
            self.bookshelfButton.isEnabled = true
        }
        
        self.rightScreenSidePanGesture.edges = [.right]
        self.topicsBadgeHub = BadgeHub(view: topicsButton)
        self.topicsBadgeHub.scaleCircleSize(by: 0.55)
        self.topicsBadgeHub.moveCircleBy(x: 4, y: -6)
        
        bioportalHelper = BioPortalHelper()
        
        canvasView.bringSubviewToFront(drawingInsertionCanvas)
        
        self.oldDocuments = self.note.1.getDocuments()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.notifiedReceiveSketchnote(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_RECEIVE_NOTE), object: nil)
        
        canvasView.addSubview(topicsOverlayView)
           NSLayoutConstraint.activate([
             topicsOverlayView.topAnchor.constraint(equalTo: canvasView.topAnchor),
             topicsOverlayView.leadingAnchor.constraint(equalTo: canvasView.leadingAnchor),
             topicsOverlayView.trailingAnchor.constraint(equalTo: canvasView.trailingAnchor),
             topicsOverlayView.bottomAnchor.constraint(equalTo: canvasView.bottomAnchor),
             ])
        
        self.noteTitleButton.setTitle(" \(note.1.getName())", for: .normal)
        self.load(page: note.1.getCurrentPage())
    }
        
    override func viewWillAppear(_ animated: Bool) {
        note.1.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.refreshHelpLines()
        
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
                //self.processDrawingRecognition()
                note.1.getCurrentPage().canvasDrawing = self.canvasView.drawing
                NeoLibrary.save(note: note.1, url: note.0)
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
                    destinationViewController.note = self.note
                }
            }
            break
        case "ShowNoteOptions":
            if let destination = segue.destination as? NoteOptionsViewController {
                destination.delegate = self
                destination.note = note
            }
            break
        case "ViewNoteText":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? NoteTextViewController {
                    destinationViewController.note = note
                }
            }
            break
        case "ShareNote":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? ShareNoteViewController {
                    destinationViewController.note = note
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
                    destinationViewController.filesToMove = [note]
                }
            }
            break
        case "ShowNoteInfo":
            if let destination = segue.destination as? NoteInfoViewController {
                destination.delegate = self
                destination.note = self.note
            }
            break
        case "EditCurrentNoteTags":
            let destinationNC = segue.destination as! UINavigationController
            destinationNC.popoverPresentationController?.delegate = self
            if let destination = destinationNC.topViewController as? TagsViewController {
                destination.note = note
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
    func load(page: NotePage) {
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
    
    private var pdfAnnotations = [PDFAnnotation : [Document]]()
    
    private func addPDFAnnotation(text: String, document: Document) {
        if let doc = pdfView.document {
            let found = doc.findString(text, withOptions: [.caseInsensitive])
            print(text)
            for f in found {
                for p in f.pages {
                    print(1)
                    let annotation = PDFAnnotation(bounds: f.bounds(for: p), forType: .highlight, withProperties: nil)
                    annotation.color = .systemBlue
                    p.addAnnotation(annotation)
                    if (pdfAnnotations[annotation] != nil) {
                        var docs = pdfAnnotations[annotation]!
                        docs.append(document)
                        pdfAnnotations[annotation] = docs
                    }
                    else {
                        pdfAnnotations[annotation] = [document]
                    }
                }
            }
            //pdfView.document = doc
        }
    }
    private func clearPDFAnnotations() {
        for annotation in pdfAnnotations {
            if let doc = pdfView.document {
                if let page = doc.page(at: 0) {
                    page.removeAnnotation(annotation.key)
                }
            }
        }
        pdfAnnotations = [PDFAnnotation : [Document]]()
    }
    
    private func setupTopicAnnotations(recognitionImageSize: CGSize) {
        self.conceptHighlights = [UIView : [Document]]()
        self.removeDetectionAnnotations()
        self.clearPDFAnnotations()
        
        let transform = self.transformMatrix(recognitionImageSize)

        let documents = note.1.getDocuments()
        if let pdfDoc = pdfView.document, let page = pdfDoc.page(at: 0), let body = page.string {
            if !body.isEmpty {
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
                    self.addPDFAnnotation(text: documentTitle, document: document)
                }
            }
        }
        if let textData = note.1.getCurrentPage().getNoteText() {
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
                        self.note.1.getCurrentPage().addDrawing(label: recognition.0, region: region.frame)
                        NeoLibrary.save(note: self.note.1, url: self.note.0)
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
        self.gridView!.type = note.1.helpLinesType
        gridView!.draw(self.backdropView.frame)
    }
    
    private func toggleHelpLinesType() {
        switch note.1.helpLinesType {
        case .None:
            note.1.helpLinesType = .Horizontal
            break
        case .Horizontal:
            note.1.helpLinesType = .Grid
            break
        case .Grid:
            note.1.helpLinesType = .None
            break
        }
        refreshHelpLines()
        NeoLibrary.save(note: note.1, url: note.0)
    }

    private func hideAllHelpLines() {
        if let gridView = gridView {
            gridView.removeFromSuperview()
        }
    }
    
    private func setupNoteImages() {
        noteImageViews = [DraggableImageView : NoteImage]()
        for image in note.1.getCurrentPage().images {
            displayNoteImage(image: image)
        }
    }
    
    private func displayNoteImage(image: NoteImage) {
        let frame = CGRect(x: image.location.x, y: image.location.y, width: image.size.width, height: image.size.height)
        let draggableView = DraggableImageView(frame: frame)
        draggableView.image = image.image
        draggableView.delegate = self
        self.canvasView.addSubview(draggableView)
        self.canvasView.sendSubviewToBack(draggableView)
        self.noteImageViews[draggableView] = image
        draggableView.center = image.location
    }
    
    private func setupNoteTypedTexts() {
        noteTextViews = [DraggableTextView : NoteTypedText]()
        for typedText in note.1.getCurrentPage().typedTexts {
            displayTypedText(typedText: typedText)
        }
    }
    
    private func displayTypedText(typedText: NoteTypedText) {
        let textView = self.createNoteTypedTextView(typedText: typedText)
        self.addTypedTextViewToCanvas(textView: textView, typedText: typedText)
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
            self.clearPDFAnnotations()
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
                
                let regionSizes = [75, 100, 125]
                let offsets = [0, 10, 20, -10, -20]
                var bestPredictionLabel: String?
                var bestScore: Double?
                var bestRegion: UIView?
                for regionSize in regionSizes {
                    for offset in offsets {
                        let region = UIView(frame: CGRect(x: Int(loc.x)-regionSize/2+offset, y: Int(loc.y)-regionSize/2+offset, width: regionSize, height: regionSize))
                        let image = UIImage(cgImage: merged.cgImage!.cropping(to: region.frame)!)
                        if let recognition = self.drawingRecognition.recognize(image: image) {
                            if bestPredictionLabel == nil || bestScore! < recognition.1 {
                                bestPredictionLabel = recognition.0
                                bestScore = recognition.1
                                bestRegion = region
                            }
                        }
                    }
                }
                if bestPredictionLabel != nil {
                    log.info("Recognized drawing at touched point: \(bestPredictionLabel!) (\(Double(round(1000*bestScore!*100)/1000))% confidence)")
                    let drawing = NoteDrawing(label: bestPredictionLabel!, region: bestRegion!.frame)
                    if !self.note.1.getCurrentPage().hasDrawing(drawing: drawing) {
                        bestRegion!.layer.borderColor = UIColor.label.cgColor
                        bestRegion!.layer.borderWidth = 1
                        self.drawingInsertionCanvas.addSubview(bestRegion!)
                        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleDrawingRegionTap(_:)))
                        bestRegion!.addGestureRecognizer(tapGesture)
                        bestRegion!.isUserInteractionEnabled = true
                        self.drawingViews.append(bestRegion!)
                        self.note.1.getCurrentPage().addDrawing(drawing: drawing)
                        NeoLibrary.save(note: self.note.1, url: self.note.0)
                        self.view.makeToast("Recognized drawing: \(bestPredictionLabel!)", duration: 1.0, position: .center)
                        self.canvasView.rippleFill(location: loc, color: .systemGreen)
                    }
                    else {
                        self.view.makeToast("Drawing is already recognized: \(bestPredictionLabel!)", duration: 1.0, position: .center)
                        self.canvasView.rippleFill(location: loc, color: .systemOrange)
                    }
                }
                else {
                    self.view.makeToast("No drawing recognized. Try long-pressing in the center of your drawing!", duration: 1.0, position: .center)
                    self.canvasView.rippleFill(location: loc, color: .systemRed)
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
            self.noteForRelatedNotes = self.note
            self.performSegue(withIdentifier: "showRelatedNoteEditing", sender: self)
            break
        case .ViewText:
            self.performSegue(withIdentifier: "ViewNoteText", sender: self)
            break
        case .CopyNote:
            SKClipboard.copy(note: note.1)
            self.view.makeToast("Copied note to SKClipboard.", title: note.1.getName())
            break
        case .CopyText:
            UIPasteboard.general.string = note.1.getText()
            self.view.makeToast("Copied text to Clipboard.", title: note.1.getName())
            break
        case .MoveFile:
            self.performSegue(withIdentifier: "MoveFileNoteEditing", sender: self)
            break
        case .ClearPage:
            note.1.getCurrentPage().clear()
            self.load(page: note.1.getCurrentPage())
            self.saveCurrentPage()
            break
        case .DeletePage:
            _ = note.1.deletePage(index: note.1.activePageIndex)
            self.load(page: note.1.getCurrentPage())
            NeoLibrary.save(note: note.1, url: note.0)
            break
        case .Share:
            self.performSegue(withIdentifier: "ShareNote", sender: self)
            break
        case .ClearPDFPage:
            note.1.getCurrentPage().backdropPDFData = nil
            self.pdfView.document = nil
            NeoLibrary.save(note: note.1, url: note.0)
        case .ResetTextRecognition:
            note.1.clearDocuments()
            self.clearConceptHighlights()
            documentsVC.clear()
            documentsVC.update(note: self.note)
            self.processHandwritingRecognition()
            break
        case .DeleteNote:
            self.isDeletingNote = true
            NeoLibrary.delete(url: note.0)
            self.performSegue(withIdentifier: "CloseNote", sender: self)
            break
        case .MoleculeEditor:
            self.performSegue(withIdentifier: "ShowMoleculeEditor", sender: self)
            break
        case .HelpLines:
            self.toggleHelpLinesType()
            break
        }
    }
    
    // MoveFileViewControllerDelegate
    func movedFiles(items: [(URL, File)]) {
        self.view.makeToast("Note moved.", duration: 1.0, position: .center)
    }
    
    func pdfScaleChanged(scale: Float) {
        pdfView.scaleFactor = CGFloat(scale)
        note.1.getCurrentPage().pdfScale = scale
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
                    self.note.1.getCurrentPage().clearNoteText()
                    if let noteText = noteText {
                        self.note.1.getCurrentPage().setNoteText(noteText: noteText)
                        self.startSaveTimer()
                        if self.topicsShown {
                            self.setupTopicAnnotations(recognitionImageSize: image.size)
                        }
                        self.annotateText(text: self.note.1.getText())
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
        let page = note.1.getCurrentPage()
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
            log.info("Checking Internet connection for annotation services.")
            switch connectivity.status {
                case .connected, .connectedViaWiFi, .connectedViaCellular:
                    log.info("Internet Connection detected.")
                    if SettingsManager.isAnnotationServiceAvailable() {
                        SettingsManager.updateAnnotationServiceAvailability()
                        DispatchQueue.global(qos: .background).async {
                            if SettingsManager.getAnnotatorStatus(annotator: .TAGME) {
                                TAGMEHelper.shared.fetch(text: text, note: self.note)
                            }
                            if SettingsManager.getAnnotatorStatus(annotator: .WAT) {
                                WATHelper.shared.fetch(text: text, note: self.note)
                            }
                            if SettingsManager.getAnnotatorStatus(annotator: .BioPortal) {
                                self.bioportalHelper.fetch(text: text, note: self.note)
                            }
                            if SettingsManager.getAnnotatorStatus(annotator: .CHEBI) {
                                self.bioportalHelper.fetchCHEBI(text: text, note: self.note)
                            }
                        }
                    }
                    else {
                        self.view.makeToast("You cannot annotate your note right now, please wait 10 seconds.", duration: 4.0, position: .center)
                    }
                    break
                default:
                    log.error("Internet Connection not detected: Annotation not possible.")
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
            note.1.getCurrentPage().canvasDrawing = self.canvasView.drawing
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
        NeoLibrary.save(note: note.1, url: note.0)
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
    
    var openNote : (URL, Note)?
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(340), height: CGFloat(210))
    }
    
    private func updateBookshelf() {
        documentsVC.update(note: self.note)
    }
    
    // MARK: NoteDelegate
    func noteHasNewDocument(note: Note, document: Document) {
        documentsVC.update(note: self.note)
        self.updateTopicsCount()
        NeoLibrary.save(note: self.note.1, url: self.note.0)
    }
    func noteHasRemovedDocument(note: Note, document: Document) {
        documentsVC.update(note: self.note)
        self.updateTopicsCount()
        NeoLibrary.save(note: self.note.1, url: self.note.0)
    }
    func noteDocumentHasChanged(note: Note, document: Document) {
        documentsVC.update(note: self.note)
        NeoLibrary.save(note: self.note.1, url: self.note.0)
    }
    func noteHasChanged(note: Note) {
    }
    
    // Related Notes VC delegate
    func openRelatedNote(url: URL, note: Note) {
        self.openNote = (url, note)
        self.saveCurrentPage()
        if self.textRecognitionTimer != nil {
            self.textRecognitionTimer!.invalidate()
        }
        if self.saveTimer != nil {
            self.saveTimer!.invalidate()
        }
        //self.documentsVC.bookshelfUpdateTimer?.reset(nil)
        self.performSegue(withIdentifier: "CloseNote", sender: self)
    }
    func mergedNotes(note1: Note, note2: Note) {
        self.updatePaginationButtons()
    }
    
    private func showTopicDocuments(documents: [Document]) {
        //documentsVC.showTopicDocuments(documents: documents)
    }
    
    //MARK: Drawing insertion mode
    private func setupDrawingRegions() {
        for drawing in note.1.getCurrentPage().getDrawings() {
            let region = UIView(frame: drawing.getRegion())
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
                if currentDrawingRegion.frame.width >= 50 {
                    UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                        let whiteBackground = UIColor.white.image(CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
                        var canvasImage = canvasView.drawing.image(from: UIScreen.main.bounds, scale: 1.0)
                        canvasImage = canvasImage.blackAndWhite() ?? canvasImage.toGrayscale
                        DispatchQueue.main.async {
                            var merged = whiteBackground.mergeWith(withImage: canvasImage)
                            merged = merged.invertedImage() ?? merged
                            let image = UIImage(cgImage: merged.cgImage!.cropping(to: currentDrawingRegion.frame)!)
                            if let recognition = self.drawingRecognition.recognize(image: image) {
                                log.info("Recognized drawing: \(recognition)")
                                self.view.makeToast("Recognized drawing: \(recognition.0)")
                                self.note.1.getCurrentPage().addDrawing(label: recognition.0, region: currentDrawingRegion.frame)
                                self.drawingViews.append(currentDrawingRegion)
                                
                                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleDrawingRegionTap(_:)))
                                currentDrawingRegion.addGestureRecognizer(tapGesture)
                                currentDrawingRegion.isUserInteractionEnabled = true
                                NeoLibrary.save(note: self.note.1, url: self.note.0)
                            }
                        }
                    }
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
                    self.note.1.getCurrentPage().removeDrawing(region: drawingRegion.frame)
                    NeoLibrary.save(note: self.note.1, url: self.note.0)
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
        note.1.getCurrentPage().canvasDrawing = self.canvasView.drawing
        NeoLibrary.save(note: note.1, url: note.0)
        log.info("Saved note for current page.")
    }
    
    func previousPage() {
        if note.1.hasPreviousPage() {
            self.view.makeToast("Page \(note.1.activePageIndex)/\(note.1.pages.count)", duration: 1.0, position: .center)
            self.pageChanged = true
            if self.saveTimer != nil {
                self.saveCurrentPage()
            }
            note.1.previousPage()
            self.load(page: note.1.getCurrentPage())
        }
    }
    func nextPage() {
        if note.1.hasNextPage() {
            self.view.makeToast("Page \(note.1.activePageIndex+2)/\(note.1.pages.count)", duration: 1.0, position: .center)
            self.pageChanged = true
            if self.saveTimer != nil {
                self.saveCurrentPage()
            }
            note.1.nextPage()
            self.load(page: note.1.getCurrentPage())
        }
    }
    
    @IBAction func newItemTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .none()
        let newPageAction = PopMenuDefaultAction(title: "New Page", image: UIImage(systemName: "plus.circle"), color: .link, didSelect: { action in
            let newPage = NotePage()
            self.note.1.add(page: newPage)
            self.saveCurrentPage()
            self.note.1.nextPage()
            self.load(page: self.note.1.getCurrentPage())
            self.saveCurrentPage()
        })
        popMenu.addAction(newPageAction)
        let importItemsAction = PopMenuDefaultAction(title: "Import Files", image: UIImage(systemName: "doc"), didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            self.displayDocumentPicker()
        })
        popMenu.addAction(importItemsAction)
        let scanAction = PopMenuDefaultAction(title: "Scan Documents", image: UIImage(systemName: "doc.text.viewfinder"), didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            let scannerVC = VNDocumentCameraViewController()
            scannerVC.delegate = self
            self.present(scannerVC, animated: true)
        })
        popMenu.addAction(scanAction)
        let imageImportAction = PopMenuDefaultAction(title: "Camera Roll", image: UIImage(systemName: "photo"), didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            self.displayImagePicker()
        })
        popMenu.addAction(imageImportAction)
        if (SKClipboard.hasItems()) {
            if let copiedNote = SKClipboard.getNote() {
                let pasteNoteAction = PopMenuDefaultAction(title: "Paste Note", image: UIImage(systemName: "square.stack.3d.down.right.fill"), didSelect: { action in
                    self.note.1.add(pages: copiedNote.pages)
                    self.saveCurrentPage()
                    self.view.makeToast("Pasted \(copiedNote.pages.count) page(s).", duration: 2, position: .center)
                })
                popMenu.addAction(pasteNoteAction)
            }
            if let copiedPage = SKClipboard.getPage() {
                let pastePageAction = PopMenuDefaultAction(title: "Paste Page", image: UIImage(systemName: "doc"), didSelect: { action in
                    self.note.1.add(page: copiedPage)
                    self.saveCurrentPage()
                    self.view.makeToast("Pasted page.", duration: 1, position: .center)
                })
                popMenu.addAction(pastePageAction)
            }
            if let copiedImage = SKClipboard.getImage() {
                let pasteImageAction = PopMenuDefaultAction(title: "Paste Image", image: UIImage(systemName: "photo"), didSelect: { action in
                    self.note.1.getCurrentPage().images.append(copiedImage)
                    self.displayNoteImage(image: copiedImage)
                    self.saveCurrentPage()
                    self.view.makeToast("Pasted image.", duration: 1, position: .center)
                })
                popMenu.addAction(pasteImageAction)
            }
            if let copiedTypedText = SKClipboard.getTypedText() {
                let pasteTypedTextAction = PopMenuDefaultAction(title: "Paste Typed Text", image: UIImage(systemName: "text.alignleft"), didSelect: { action in
                    self.note.1.getCurrentPage().typedTexts.append(copiedTypedText)
                    self.displayTypedText(typedText: copiedTypedText)
                    self.saveCurrentPage()
                    self.view.makeToast("Pasted typed text.", duration: 1, position: .center)
                })
                popMenu.addAction(pasteTypedTextAction)
            }
        }
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
        let types: [String] = ImportHelper.noteEditingUTTypes
        let documentPicker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .pageSheet
        documentPicker.allowsMultipleSelection = true
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if urls.count > 0 {
            self.view.makeToast("Imported the selected documents.")
            let (notes, images, pdfs, texts) = ImportHelper.importItems(urls: urls)
            for n in notes {
                log.info("Added pages of imported note to currently open note.")
                note.1.pages += n.1.pages
            }
            for img in images {
                self.addNoteImage(image: img)
            }
            var setPDFForCurrentPage = false
            for pdf in pdfs {
                for i in 0..<pdf.pageCount {
                    if let pdfPage = pdf.page(at: i) {
                        if !setPDFForCurrentPage {
                            setPDFForCurrentPage = true
                            note.1.getCurrentPage().backdropPDFData = pdfPage.dataRepresentation
                            self.pdfView.document = PDFDocument(data: pdfPage.dataRepresentation!)
                        }
                        else {
                            let newPage = NotePage()
                            newPage.backdropPDFData = pdfPage.dataRepresentation
                            note.1.pages.insert(newPage, at: note.1.activePageIndex + 1)
                        }
                    }
                }
            }
            for text in texts {
                note.1.getCurrentPage().typedTexts.append(text)
                let textView = self.createNoteTypedTextView(typedText: text)
                self.addTypedTextViewToCanvas(textView: textView, typedText: text)
            }
            NeoLibrary.save(note: note.1, url: note.0)
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
            note.1.getCurrentPage().updateNoteTypedText(typedText: typedText)
            self.startSaveTimer()
        }
    }
    
    func draggableTextViewLocationChanged(source: DraggableTextView, location: CGPoint) {
        if let typedText = self.noteTextViews[source] {
            typedText.location = location
            note.1.getCurrentPage().updateNoteTypedText(typedText: typedText)
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
            let copyAction = PopMenuDefaultAction(title: "Copy", didSelect: { action in
                SKClipboard.copy(typedText: typedText)
                self.view.makeToast("Copied note typed text to SKClipboard.")
            })
            popMenu.addAction(copyAction)
            let copyTextAction = PopMenuDefaultAction(title: "Copy Text", didSelect: { action in
                UIPasteboard.general.string = typedText.text
            })
            popMenu.addAction(copyTextAction)
            let action = PopMenuDefaultAction(title: "Delete", didSelect: { action in
                self.note.1.getCurrentPage().deleteTypedText(typedText: typedText)
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
                self.note.1.getCurrentPage().updateNoteTypedText(typedText: typedText)
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
            note.1.getCurrentPage().updateNoteTypedText(typedText: typedText)
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
        note.1.getCurrentPage().images.append(noteImage)
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
            note.1.getCurrentPage().updateNoteImage(noteImage: noteImage)
            self.startSaveTimer()
        }
    }
    
    func draggableImageViewLocationChanged(source: DraggableImageView, location: CGPoint) {
        if let noteImage = self.noteImageViews[source] {
            noteImage.location = location
            note.1.getCurrentPage().updateNoteImage(noteImage: noteImage)
            self.startSaveTimer()
        }
    }
    
    func draggableImageViewDelete(source: DraggableImageView) {
        let popMenu = PopMenuViewController(sourceView: source, actions: [PopMenuAction](), appearance: nil)
        let closeAction = PopMenuDefaultAction(title: "Close")
        let copyAction = PopMenuDefaultAction(title: "Copy", didSelect: { action in
            if let noteImage =  self.noteImageViews[source] {
                SKClipboard.copy(image: noteImage)
                self.view.makeToast("Copied note image to SKClipboard.")
            }
        })
        let action = PopMenuDefaultAction(title: "Delete Image", didSelect: { action in
            if let noteImage =  self.noteImageViews[source] {
                self.note.1.getCurrentPage().deleteImage(noteImage: noteImage)
                source.removeFromSuperview()
                self.noteImageViews[source] = nil
                self.startSaveTimer()
            }
            
        })
        popMenu.addAction(copyAction)
        popMenu.addAction(action)
        popMenu.addAction(closeAction)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    private func updatePaginationButtons() {
        previousPageButton.isEnabled = note.1.hasPreviousPage()
        nextPageButton.isEnabled = note.1.hasNextPage()
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
    }
    
    // MARK: Documents View Controller delegate
    func resetDocuments() {
        self.clearConceptHighlights()
        note.1.clearDocuments()
        NeoLibrary.save(note: note.1, url: note.0)
        self.annotateText(text: note.1.getText())
        if let doc = pdfView.document {
            if let page = doc.page(at: 0) {
                if page.string != nil && !page.string!.isEmpty {
                    self.annotateText(text: page.string!)
                }
            }
        }
    }
    var oldDocuments: [Document]!
    func updateTopicsCount() {
        self.topicsBadgeHub.setCount(note.1.getDocuments(forCurrentPage: true).count)
        let differences = zip(oldDocuments, note.1.getDocuments()).map {$0.0 == $0.1}
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
        if note.1.activePageIndex != index {
            if self.saveTimer != nil {
                self.saveCurrentPage()
            }
            note.1.activePageIndex = index
            self.load(page: note.1.getCurrentPage())
        }
    }
    func notePagesReordered(note: Note) {
        self.note.1 = note
        self.updatePaginationButtons()
        self.saveCurrentPage()
    }
    func notePageDeleted(note: Note) {
        self.note.1 = note
        self.load(page: self.note.1.getCurrentPage())
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
                        var text = ""
                        for doc in documents {
                            text.append(doc.title.lowercased() + ",")
                        }
                        documentsVC.hideDetailView()
                        documentsVC.performSearch(searchText: text)
                        if bookshelf.isHidden {
                            showBookshelf()
                        }
                    }
                }
                if !found {
                    if let pdfDoc = pdfView.document, let page = pdfDoc.page(at: 0) {
                        let tapLocation = pdfView.convert(sender.location(in: canvasView), to: page)
                        if let annotation = page.annotation(at: tapLocation) {
                            if let docs = pdfAnnotations[annotation] {
                                found = true
                                var text = ""
                                for doc in docs {
                                    text.append(doc.title.lowercased() + ",")
                                }
                                documentsVC.hideDetailView()
                                documentsVC.performSearch(searchText: text)
                                if bookshelf.isHidden {
                                    showBookshelf()
                                }
                            }
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
    
    
    // MARK: NoteInfoDelegate
    func noteRenamed(newName: String, newURL: URL) {
        self.noteTitleButton.setTitle(" \(newName)", for: .normal)
        self.note.0 = newURL
        self.note.1.setName(name: newName)
        self.saveCurrentPage()
        self.documentsVC.note = self.note
    }
}
