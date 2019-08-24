//
//  SketchNoteViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 11/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import LGButton
import Firebase
import PopMenu
import GSMessages

// This is the controller for the other page of the application, i.e. not the home page, but for the page displayed when the user wants to edit a note.

class SketchNoteViewController: UIViewController, ExpandableButtonDelegate, SketchViewDelegate, UIPencilInteractionDelegate, UICollectionViewDataSource, UICollectionViewDelegate, DocumentVisitor, ColorPickerViewDelegate, ColorPickerViewDelegateFlowLayout {

    @IBOutlet weak var topContainer: UIView!
    @IBOutlet var topContainerLeftDragView: UIView!
    @IBOutlet var sketchView: SketchView!
    @IBOutlet var redoButton: LGButton!
    @IBOutlet var undoButton: LGButton!
    @IBOutlet var drawingsButton: LGButton!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet weak var viewToolsButton: LGButton!
    
    @IBOutlet var bookshelf: UIView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet var pencilButton: LGButton!
    @IBOutlet var eraserButton: LGButton!
    var pencilSize : CGFloat = 3
    var eraserSize : CGFloat = 3
    @IBOutlet weak var sizeSlider: SizeSlider!
    
    var sketchnote: Sketchnote!
    var new = false
    var storedPathArray: NSMutableArray?
    
    @IBOutlet var helpLinesButton: LGButton!
    var helpLinesHorizontal = [HoritonzalHelpLine]()
    var helpLinesVertical = [VerticalHelpLine]()
    enum HelpLinesStatus {
        case None
        case Horizontal
        case Grid
    }
    var helpLinesStatus : HelpLinesStatus = .None
    
    var drawingViews = [UIView]()
    var drawingViewsShown = false
    
    var spotlightHelper: SpotlightHelper!
    var bioportalHelper: BioPortalHelper!
    
    var conceptHighlights = [UIView : Document]()
    
    // This function sets up the page and every element contained within it.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        colorPicker.delegate = self
        colorPicker.layoutDelegate = self
        colorPicker.isSelectedColorTappable = false
        colorPicker.colors = [#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), #colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1), #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1), #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1), #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1), #colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1), #colorLiteral(red: 0.1294117719, green: 0.2156862766, blue: 0.06666667014, alpha: 1), #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1), #colorLiteral(red: 0.721568644, green: 0.8862745166, blue: 0.5921568871, alpha: 1), #colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1), #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1), #colorLiteral(red: 0.3098039329, green: 0.2039215714, blue: 0.03921568766, alpha: 1), #colorLiteral(red: 0.3176470697, green: 0.07450980693, blue: 0.02745098062, alpha: 1), #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1), #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1), #colorLiteral(red: 0.9568627477, green: 0.6588235497, blue: 0.5450980663, alpha: 1), #colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1), #colorLiteral(red: 0.5725490451, green: 0, blue: 0.2313725501, alpha: 1), #colorLiteral(red: 0.1921568662, green: 0.007843137719, blue: 0.09019608051, alpha: 1)]
        colorPicker.preselectedIndex = 0
        topContainer.layer.borderColor = UIColor.black.cgColor
        topContainer.layer.borderWidth = 1
        
        
        self.setupDocumentDetailScrollView()
        self.bookshelfLeftDragView.curveTopCorners(size: 5)
        self.topContainerLeftDragView.curveTopCorners(size: 5)
        
        sketchView.sketchViewDelegate = self
        sketchView.lineColor = .black
        sketchView.drawTool = .pen
        sketchView.lineWidth = 2
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
        
        // If the user has not created a new note, but is trying to edit an existing note, this existing note is reloaded.
        // This reload consists of redrawing the user's strokes for that note on the note's canvas on this page.
        if sketchnote != nil {
            if new == true {
                sketchnote?.image = sketchView.asImage()
            }
            else {
                if sketchnote!.paths != nil && sketchnote!.paths!.count > 0 {
                    print("Reloading paths.")
                    self.sketchView.reloadPathArray(array: sketchnote!.paths!)
                }
                    // If the app does not manage to reload the user's drawn strokes (for any reason), the app simply loads a screenshot of the note's last state as a background for the note's canvas on the page. The latter case should preferably never occur.
                else if sketchnote?.image != nil {
                    let imageView = UIImageView(image: sketchnote!.image!)
                    sketchView.addSubview(imageView)
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    NSLayoutConstraint.activate([
                        imageView.topAnchor.constraint(equalTo: sketchView.topAnchor),
                        imageView.leadingAnchor.constraint(equalTo: sketchView.leadingAnchor),
                        imageView.trailingAnchor.constraint(equalTo: sketchView.trailingAnchor),
                        imageView.bottomAnchor.constraint(equalTo: sketchView.bottomAnchor),
                        imageView.widthAnchor.constraint(equalTo: sketchView.widthAnchor),
                        imageView.heightAnchor.constraint(equalTo: sketchView.heightAnchor)
                        ])
                }
            }
            if let documents = sketchnote.documents {
                print("Reloading documents.")
                self.items = documents
                documentsCollectionView.reloadData()
            }
            // This is the case where the user has created a new note and is not editing an existing one.
        } else {
            sketchnote = Sketchnote(image: sketchView.asImage(), relatedDocuments: nil, drawings: nil)
        }
        
        setupHelpLines()
        setupConceptHighlights()
        setupDrawingRegions()
        
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        view.addInteraction(interaction)
        
        spotlightHelper = SpotlightHelper(viewController: self)!
        bioportalHelper = BioPortalHelper(viewController: self)!
        
        self.recognizedTextLogView.text = self.sketchnote.getText(raw: true)
    }
    
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        switch SettingsManager.pencilSideButton() {
        case .ManageDrawings:
            toggleManageDrawings()
            break
        case .ToggleEraserPencil:
            if sketchView.drawTool == .pen {
                setEraserTool()
            }
            else {
                setPencilTool()
            }
            break
        case .ShowHideTools:
            toggleToolsView()
            break
        case .Undo:
            sketchView.undo()
            break
        case .Redo:
            sketchView.redo()
            break
        }
    }
    
    private func setPencilTool() {
        self.sketchView.drawTool = .pen
        self.sketchView.lineWidth = pencilSize
        pencilButton.bgColor = UIColor(red: 85.0/255.0, green: 117.0/255.0, blue: 193.0/255.0, alpha: 1)
        eraserButton.bgColor = .lightGray
        sizeSlider.value = Float(pencilSize)
    }
    private func setEraserTool() {
        self.sketchView.drawTool = .eraser
        self.sketchView.lineWidth = eraserSize
        eraserButton.bgColor = UIColor(red: 85.0/255.0, green: 117.0/255.0, blue: 193.0/255.0, alpha: 1)
        pencilButton.bgColor = .lightGray
        sizeSlider.value = Float(eraserSize)
    }
    @IBAction func pencilButtonTapped(_ sender: LGButton) {
        self.setPencilTool()
    }
    @IBAction func eraserButtonTapped(_ sender: LGButton) {
        self.setEraserTool()
    }
    @IBAction func sizeSliderValueChanged(_ sender: SizeSlider) {
        sender.value = sender.value.rounded()
        switch sketchView.drawTool {
        case .pen:
            pencilSize = CGFloat(sender.value)
            break
        case .eraser:
            eraserSize = CGFloat(sender.value)
            break
        default:
            pencilSize = CGFloat(sender.value)
        }
        self.sketchView.lineWidth = CGFloat(sender.value)
    }
    
    private func processDrawingRecognition() {
        hideAllHelpLines()
        
        self.sketchnote?.drawings = [String]()
        for drawingView in self.drawingViews {
            drawingView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            drawingView.backgroundColor = .black
            drawingView.layer.borderColor = UIColor.clear.cgColor
        }
        for pathObject in self.sketchView.pathArray {
            if let penTool = pathObject as? EraserTool {
                let path = penTool.path
                for drawingView in self.drawingViews {
                    if drawingView.frame.contains(path.boundingBox) {
                        let absoluteFrame = sketchView.convert(sketchView.bounds, to: drawingView)
                        let newPath = path.copy(strokingWithWidth: drawingView.frame.width * 0.04, lineCap: .round, lineJoin: .round, miterLimit: 0)
                        let layer = CAShapeLayer()
                        layer.frame = absoluteFrame
                        layer.path = newPath
                        layer.strokeColor = UIColor.black.cgColor
                        layer.fillColor = UIColor.black.cgColor
                        drawingView.layer.addSublayer(layer)
                        drawingView.setNeedsDisplay()
                        drawingView.isHidden = false
                    }
                }
            }
            else if let penTool = pathObject as? PenTool {
                let path = penTool.path
                for drawingView in self.drawingViews {
                    if drawingView.frame.contains(path.boundingBox) {
                        let absoluteFrame = sketchView.convert(sketchView.bounds, to: drawingView)
                        let newPath = path.copy(strokingWithWidth: drawingView.frame.width * 0.04, lineCap: .round, lineJoin: .round, miterLimit: 0)
                        let layer = CAShapeLayer()
                        layer.frame = absoluteFrame
                        layer.path = newPath
                        layer.strokeColor = UIColor.white.cgColor
                        layer.fillColor = UIColor.white.cgColor
                        drawingView.layer.addSublayer(layer)
                        drawingView.setNeedsDisplay()
                        drawingView.isHidden = false
                    }
                }
            }
            else {
            }
        }
        for drawingView in self.drawingViews {
            let croppedCGImage:CGImage = (drawingView.asImage().cgImage)!
            let croppedImage = UIImage(cgImage: croppedCGImage)
            
            let resized = croppedImage.resize(newSize: CGSize(width: 28, height: 28))
            
            guard let pixelBuffer = resized.grayScalePixelBuffer() else {
                print("couldn't create pixel buffer")
                return
            }
            do {
                currentPrediction = try drawnImageClassifier.prediction(image: pixelBuffer)
            }
            catch {
                print("error making prediction: \(error)")
            }
            drawingView.isHidden = true
        }
    }
    
    private func setupHelpLines() {
        var height = CGFloat(40)
        while (CGFloat(height) < self.sketchView.frame.height + 80) {
            let line = HoritonzalHelpLine(frame: CGRect(x: 0, y: height, width: self.view.frame.width, height: 1))
            line.isUserInteractionEnabled = false
            line.isHidden = true
            self.sketchView.addSubview(line)
            self.helpLinesHorizontal.append(line)
            height = height + 40
        }
        var width = CGFloat(40)
        while (CGFloat(width) < self.sketchView.frame.width + 80) {
            let line = VerticalHelpLine(frame: CGRect(x: width, y: 0, width: 1, height: self.view.frame.height))
            line.isUserInteractionEnabled = false
            line.isHidden = true
            self.sketchView.addSubview(line)
            self.helpLinesVertical.append(line)
            width = width + 40
        }
    }
    
    // MARK: Highlighting recognized concepts/topics on the canvas
    
    @IBOutlet var conceptHighlightsSwitch: UISwitch!
    private func setupConceptHighlights() {
        if let documents = sketchnote.documents {
            for textData in sketchnote.textDataArray {
                for document in documents {
                    var found = false
                    var body = textData.spellchecked!
                    if textData.corrected != nil && !textData.corrected!.isEmpty {
                        body = textData.corrected!
                    }
                    if body.lowercased().contains(document.title.lowercased()) {
                        for block in textData.visionTextWrapper.blocks {
                            for line in block.lines {
                                for element in line.elements {
                                    if element.text.lowercased() == document.title.lowercased() || element.text.lowercased().levenshtein(document.title.lowercased()) <= 2 {
                                        let scaledFrame = createScaledFrame(featureFrame: element.frame, imageSize: textData.imageSize)
                                        let conceptHighlightView = UIView(frame: scaledFrame)
                                        conceptHighlightView.layer.borderWidth = 2
                                        conceptHighlightView.layer.borderColor = UIColor.red.cgColor
                                        self.view.addSubview(conceptHighlightView)
                                        print(conceptHighlightView.frame)
                                        conceptHighlightView.isHidden = true
                                        conceptHighlightView.isUserInteractionEnabled = true
                                        self.conceptHighlights[conceptHighlightView] = document
                                        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleConceptHighlightTap(_:)))
                                        conceptHighlightView.addGestureRecognizer(tapGesture)
 
                                        found = true
                                        break
                                    }
                                }
                                if found {
                                    break
                                }
                            }
                            if found {
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    private func createScaledFrame(featureFrame: CGRect, imageSize: CGSize) -> CGRect {
            let viewSize = sketchView.frame.size
            
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
            return CGRect(x: featurePointXScaled - 15,
                          y: featurePointYScaled - 30,
                          width: featureWidthScaled,
                          height: featureHeightScaled)
    }
    
    @objc func handleConceptHighlightTap(_ sender: UITapGestureRecognizer) {
        if let conceptHighlightView = sender.view {
            if let document = self.conceptHighlights[conceptHighlightView] {
                showDocumentDetail(document: document)
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
    @IBAction func conceptHighlightsSwitchTapped(_ sender: UISwitch) {
        self.toggleConceptHighlight(isHidden: !sender.isOn)
        if sender.isOn {
            if conceptHighlights.isEmpty {
                setupConceptHighlights()
            }
        }
    }
    
    private func clearConceptHighlights() {
        for (view, _) in conceptHighlights {
            view.removeFromSuperview()
        }
        self.conceptHighlights = [UIView : Document]()
        conceptHighlightsSwitch.isOn = false
    }
    
    // This function is called when the user closes the page, i.e. stops editing the note, and the app returns to the home page.
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
        case "Placeholder":
            print("Placeholder")
            break
        case "CloseNote":
            for helpLine in self.helpLinesHorizontal {
                helpLine.removeFromSuperview()
            }
            for helpLine in self.helpLinesVertical {
                helpLine.removeFromSuperview()
            }
            self.toggleConceptHighlight(isHidden: true)
            self.processDrawingRecognition()
            sketchnote.image = sketchView.asImage()
            sketchnote.setUpdateDate()
            self.storedPathArray = sketchView.pathArray
            print("Closing & Saving sketchnote")
        default:
            print("Default segue case triggered.")
        }
    }
    private func toggleToolsView() {
        topContainer.isHidden = !topContainer.isHidden
        if topContainer.isHidden {
            viewToolsButton.bgColor = .lightGray
        }
        else {
            viewToolsButton.bgColor = UIColor(red: 85.0/255.0, green: 117.0/255.0, blue: 193.0/255.0, alpha: 1)
        }
    }
    @IBAction func viewToolsTapped(_ sender: LGButton) {
        toggleToolsView()
    }
    
    @IBAction func moreTapped(_ sender: LGButton) {
        let alert = UIAlertController(title: "Edit Your Note", message: "", preferredStyle: .alert)
        if bookshelf.isHidden {
            alert.addAction(UIAlertAction(title: "View Documents", style: .default, handler: { action in
                self.showBookshelf()
            }))
        }
        alert.addAction(UIAlertAction(title: "Reset Documents", style: .default, handler: { action in
            self.sketchnote.documents = [Document]()
            self.items = [Document]()
            self.clearConceptHighlights()
            self.annotateText(text: self.sketchnote.getText())
        }))
        alert.addAction(UIAlertAction(title: "Reset Text Recognition", style: .default, handler: { action in
            self.sketchnote.clearTextData()
            self.sketchnote.documents = [Document]()
            self.items = [Document]()
            self.clearConceptHighlights()
            self.processHandwritingRecognition()
        }))
        alert.addAction(UIAlertAction(title: "Clear Note", style: .destructive, handler: { action in
            self.sketchView.clear()
            self.sketchView.subviews.forEach { $0.removeFromSuperview() }
            self.setupHelpLines()
            self.sketchnote.clear()
            self.clearConceptHighlights()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    @IBAction func redoTapped(_ sender: LGButton) {
        sketchView.redo()
    }
    @IBAction func undoTapped(_ sender: LGButton) {
        sketchView.undo()
    }
    @IBAction func drawingsTapped(_ sender: LGButton) {
        drawingViewsShown = !drawingViewsShown
        if drawingViewsShown {
            toggleDrawingRegions(isHidden: false, canInteract: false)
            drawingsButton.bgColor = UIColor(red: 85.0/255.0, green: 117.0/255.0, blue: 193.0/255.0, alpha: 1)
        }
        else {
            toggleDrawingRegions(isHidden: true, canInteract: false)
            drawingsButton.bgColor = .lightGray
        }
    }
    @IBAction func toggleHelpLinesTapped(_ sender: LGButton) {
        switch self.helpLinesStatus {
        case .None:
            self.helpLinesStatus = .Horizontal
            helpLinesButton.leftIconString = "dehaze"
            helpLinesButton.bgColor = UIColor(red: 85.0/255.0, green: 117.0/255.0, blue: 193.0/255.0, alpha: 1)
            for line in helpLinesHorizontal {
                line.isHidden = false
            }
            for line in helpLinesVertical {
                line.isHidden = true
            }
            break
        case .Horizontal:
            self.helpLinesStatus = .Grid
            helpLinesButton.leftIconString = "grid_on"
            for line in helpLinesHorizontal {
                line.isHidden = false
            }
            for line in helpLinesVertical {
                line.isHidden = false
            }
            break
        case .Grid:
            self.helpLinesStatus = .None
            helpLinesButton.leftIconString = "grid_off"
            helpLinesButton.bgColor = .lightGray
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
        var newPenTools = [PenTool]()
        for pathObject in self.sketchView.pathArray {
            if let penTool = pathObject as? PenTool {
                let path = penTool.path
                var isDrawing = false
                for drawingView in self.drawingViews {
                    if drawingView.frame.contains(path.boundingBox) {
                        isDrawing = true
                        break
                    }
                }
                if !isDrawing {
                    newPenTools.append(penTool)
                }
            }
            else {
            }
        }
        handwritingRecognizer.recognize(spellcheck: false, note: sketchnote, view: sketchView, penTools: newPenTools, canvasFrame: self.sketchView.bounds) { (success, textData) in
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
    
    func annotateText(text: String) {
        self.activityIndicator.stopAnimating()
        self.clearConceptHighlights()
        self.sketchnote.documents = [Document]()
        self.items = [Document]()
        self.showBookshelf()
        
        self.spotlightHelper.fetch(text: text)
        self.bioportalHelper.fetch(text: text)
        self.bioportalHelper.fetchCHEBI(text: text)
    }
    
    private func showBookshelf() {
        self.bookshelf.isHidden = false
        if self.isBookshelfDraggedOut {
            self.bookshelfLeftConstraint.constant -= 300
            UIView.animate(withDuration: 0.25, delay: 0, options: UIView.AnimationOptions.curveEaseIn, animations: {
                self.view.layoutIfNeeded()
            }, completion: { (ended) in
            })
            self.isBookshelfDraggedOut = false
        }
    }
    
    var timer: Timer?
    func drawView(_ view: SketchView, didEndDrawUsingTool tool: AnyObject) {
        if timer != nil {
            timer!.invalidate()
            timer = nil
            print("Recognition timer reset.")
            
        }
        timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(onTimerFires), userInfo: nil, repeats: false)
        self.activityIndicator.startAnimating()
        print("Recognition timer started.")
    }
    @objc func onTimerFires()
    {
        timer?.invalidate()
        timer = nil
        self.processHandwritingRecognition()
    }
    
    // Drawing recognition
    // In case the user's drawing has been recognized with at least a >50% confidence, the recognized drawing's label, e.g. "light bulb", is stored for the sketchnote.
    private var labelNames: [String] = []
    private let drawnImageClassifier = DrawnImageClassifier()
    private var currentPrediction: DrawnImageClassifierOutput? {
        didSet {
            if let currentPrediction = currentPrediction {
                
                // display top 5 scores
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
    
    //MARK: Tools View drag
    @IBOutlet var toolsViewLeftConstraint: NSLayoutConstraint!
    @IBOutlet var toolsViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var toolsViewRightConstraint: NSLayoutConstraint!
    
    
    var toolsViewTouchPreviousPoint = CGPoint()
    @IBAction func toolsViewPanned(_ sender: UIPanGestureRecognizer) {
        if sender.state == .began {
            toolsViewTouchPreviousPoint = sender.location(in: self.view)
        }
        else if sender.state != .cancelled {
            let currentTouchPoint = sender.location(in: self.view)
            let deltaX = currentTouchPoint.x - toolsViewTouchPreviousPoint.x
            let deltaY = currentTouchPoint.y - toolsViewTouchPreviousPoint.y
            if toolsViewLeftConstraint.constant + deltaX > 5 && toolsViewRightConstraint.constant - deltaX > 5 {
                toolsViewLeftConstraint.constant += deltaX
                toolsViewRightConstraint.constant -= deltaX
            }
            if toolsViewTopConstraint.constant + deltaY >= 20 && toolsViewTopConstraint.constant + deltaY < self.view.frame.maxY - 115 {
                toolsViewTopConstraint.constant += deltaY
            }
                
            toolsViewTouchPreviousPoint = currentTouchPoint
        }
        else {
            toolsViewTouchPreviousPoint = CGPoint()
        }
    }
    
    //MARK: Bookshelf resize
    @IBOutlet var bookshelfRightConstraint: NSLayoutConstraint!
    @IBOutlet var bookshelfLeftConstraint: NSLayoutConstraint!
    @IBOutlet var bookshelfBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet var closeBookshelfLabel: UILabel!
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
            print(touchStart)
            
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
                bookshelfLeftConstraint.constant += deltaX
                
                if UIScreen.main.bounds.maxX - currentTouchPoint.x <= 100 {
                    closeBookshelfLabel.isHidden = false
                }
                else {
                    closeBookshelfLabel.isHidden = true
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
                if UIScreen.main.bounds.maxX - currentTouchPoint.x <= 100 {
                    bookshelfLeftConstraint.constant += 100
                    self.isBookshelfDraggedOut = true
                    UIView.animate(withDuration: 0.25, delay: 0, options: UIView.AnimationOptions.curveEaseIn, animations: {
                        self.view.layoutIfNeeded()
                    }, completion: { (ended) in
                        self.bookshelf.isHidden = true
                    })
                    closeBookshelfLabel.isHidden = true
                }
            }
        }
    }
    
    // MARK: Documents Collection View
    @IBOutlet var documentsCollectionView: UICollectionView!
    
    let reuseIdentifier = "cell" // also enter this string as the cell identifier in the storyboard
    var items = [Document]()
    
    // tell the collection view how many cells to make
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.items.count
    }
    
    // make a cell for each cell index path
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // get a reference to our storyboard cell
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath as IndexPath) as! DocumentUICollectionViewCell
        
        // Use the outlet in our custom class to get a reference to the UILabel in the cell
        cell.titleLabel.text = self.items[indexPath.item].title
        cell.typeLabel.text = self.items[indexPath.item].documentType.rawValue
        cell.previewImage.image = self.items[indexPath.item].previewImage
        cell.backgroundColor = self.getDocumentTypeColor(type: self.items[indexPath.item].documentType)
        
        return cell
    }
    
    //MARK: Bookshelf collection view cell color mapping to document type
    private func getDocumentTypeColor(type: DocumentType) -> UIColor {
        switch(type) {
        case .Spotlight:
            return .gray
        case .BioPortal:
            return .purple
        case .Chemistry:
            return .brown
        case .Other:
            return .white
        }
    }
    
    // MARK: - UICollectionViewDelegate protocol
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // handle tap events
        print("You selected cell #\(indexPath.item)!")
        showDocumentDetail(document: self.items[indexPath.item])
    }
    
    func displayInBookshelf(document: Document) {
        self.sketchnote.addDocument(document: document)
        self.items = self.sketchnote.documents ?? [Document]()
        self.documentsCollectionView.reloadData()
    }
    
    func displayInBookshelf(documents: [Document]) {
        for doc in documents {
            self.items.append(doc)
        }
        self.documentsCollectionView.reloadData()
        
        self.sketchnote?.documents = items
    }
    
    func updateBookshelf() {
        self.documentsCollectionView.reloadData()
    }
    
    //MARK: Document Detail View
    
    @IBOutlet var documentDetailView: UIView!
    @IBOutlet var documentTitleLabel: UILabel!
    @IBOutlet var documentDetailScrollView: UIScrollView!
    var documentDetailStackView = UIStackView()
    
    private func setupDocumentDetailScrollView() {
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
    }
    
    private func showDocumentDetail(document: Document) {
        for view in documentDetailStackView.subviews {
            view.removeFromSuperview()
        }
        
        documentTitleLabel.text = document.title
        document.accept(visitor: self)
        
        documentDetailView.isHidden = false
        documentsCollectionView.isHidden = true
    }
    
    func process(document: Document) {
        if let description = document.description {
            self.setDetailDescription(text: description)
        }
    }
    
    func process(document: SpotlightDocument) {
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
    
    func process(document: BioPortalDocument) {
        if let definition = document.definition {
            let descriptionLabel = UILabel(frame: documentDetailStackView.frame)
            descriptionLabel.text = definition
            descriptionLabel.numberOfLines = 50
            documentDetailStackView.addArrangedSubview(descriptionLabel)
        }
    }
    
    func process(document: CHEBIDocument) {
        if let definition = document.definition {
            let descriptionLabel = UILabel(frame: documentDetailStackView.frame)
            descriptionLabel.text = definition
            descriptionLabel.numberOfLines = 50
            documentDetailStackView.addArrangedSubview(descriptionLabel)
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
        self.navigationController?.isNavigationBarHidden = false
        self.tabBarController?.tabBar.isHidden = false
        sender.view?.removeFromSuperview()
    }
    @IBAction func documentDetailViewBrowseTapped(_ sender: UIButton) {
        documentDetailView.isHidden = true
        documentsCollectionView.isHidden = false
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
    
    @IBOutlet weak var manageDrawingsButton: LGButton!
    var isManageDrawings = false
    @IBAction func manageDrawingsTapped(_ sender: LGButton) {
        toggleManageDrawings()
    }
    private func toggleManageDrawings() {
        isManageDrawings = !isManageDrawings
        if isManageDrawings {
            drawingsButton.isEnabled = false
            conceptHighlightsSwitch.isEnabled = false
            toggleDrawingRegions(isHidden: false, canInteract: true)
            sketchView.isUserInteractionEnabled = false
            if conceptHighlightsSwitch.isOn {
                conceptHighlightsSwitch.isOn = false
                conceptHighlightsSwitch.setOn(false, animated: true)
            }
            manageDrawingsButton.bgColor = UIColor(red: 85.0/255.0, green: 117.0/255.0, blue: 193.0/255.0, alpha: 1)
        }
        else {
            drawingsButton.isEnabled = true
            conceptHighlightsSwitch.isEnabled = true
            if drawingViewsShown {
                toggleDrawingRegions(isHidden: false, canInteract: false)
            }
            else {
                toggleDrawingRegions(isHidden: true, canInteract: false)
            }
            sketchView.isUserInteractionEnabled = true
            manageDrawingsButton.bgColor = .lightGray
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
    
    @IBOutlet weak var colorPicker: ColorPickerView!
    func colorPickerView(_ colorPickerView: ColorPickerView, didSelectItemAt indexPath: IndexPath) {
        sketchView.lineColor = colorPickerView.colors[colorPickerView.indexOfSelectedColor ?? 0]
        sizeSlider.minimumTrackTintColor = colorPickerView.colors[colorPickerView.indexOfSelectedColor ?? 0]
    }
    
    // This is an optional method
    func colorPickerView(_ colorPickerView: ColorPickerView, didDeselectItemAt indexPath: IndexPath) {
        // A color has been deselected
    }
    
    func colorPickerView(_ colorPickerView: ColorPickerView, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 30, height: 30)
    }
    func colorPickerView(_ colorPickerView: ColorPickerView, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(3)
    }
    func colorPickerView(_ colorPickerView: ColorPickerView, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
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
        context.setStrokeColor(UIColor.black.cgColor)
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
        context.setStrokeColor(UIColor.black.cgColor)
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
