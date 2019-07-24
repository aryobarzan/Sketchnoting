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

// This is the controller for the other page of the application, i.e. not the home page, for the page displayed when the user wants to edit a note.

class SketchNoteViewController: UIViewController, ExpandableButtonDelegate, SketchViewDelegate, UIPencilInteractionDelegate, UICollectionViewDataSource, UICollectionViewDelegate, DocumentVisitor {

    @IBOutlet weak var topContainer: UIView!
    @IBOutlet var sketchView: SketchView!
    @IBOutlet weak var toolsView: UIView!
    @IBOutlet var documentsButton: LGButton!
    @IBOutlet var clearButton: UIBarButtonItem!
    @IBOutlet var closeButton: UIBarButtonItem!
    @IBOutlet var redoButton: LGButton!
    @IBOutlet var undoButton: LGButton!
    @IBOutlet var helpLinesButton: LGButton!
    @IBOutlet var drawingsButton: LGButton!
    
    @IBOutlet var bookshelf: UIView!
    
    var colorSlider: ColorSlider!
    var toolsMenu: ExpandableButtonView!
    var toolSizeMenu: ExpandableButtonView!
    
    var sketchnote: Sketchnote!
    var new = false
    var storedPathArray: NSMutableArray?
    
    var helpLines = [SimpleLine]()
    var helpLinesShown = false
    
    var drawingViews = [UIView]()
    var drawingViewsShown = false
    
    var spotlightHelper: SpotlightHelper!
    var bioportalHelper: BioPortalHelper!
    
    // This function sets up the page and every element contained within it.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        
        self.setupDocumentDetailScrollView()
        self.bookshelfLeftDragView.curveTopCorners(size: 5)

        colorSlider = ColorSlider(orientation: .horizontal, previewSide: .bottom)
        colorSlider.color = .black
        colorSlider.frame = CGRect(x: 106, y: 2, width: 231, height: 50)
        toolsView.addSubview(colorSlider)
        colorSlider.addTarget(self, action: #selector(changedColor(_:)), for: .valueChanged)
        
        setupToolsMenu()
        setupToolSizeMenu()
        
        sketchView.sketchViewDelegate = self
        sketchView.lineColor = colorSlider.color
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
            if let documents = sketchnote?.relatedDocuments {
                for doc in documents {
                    self.displayInBookshelf(document: doc)
                }
            }
            // This is the case where the user has created a new note and is not editing an existing one.
        } else {
            sketchnote = Sketchnote(image: sketchView.asImage(), relatedDocuments: nil, drawings: nil)
        }
        
        // The inserted drawing regions for the existing note are reloaded on the canvas.
        if sketchnote != nil && sketchnote!.drawingViewRects != nil {
            for rect in sketchnote!.drawingViewRects! {
                let drawingView = UIView(frame: rect)
                drawingView.layer.borderWidth = 1
                drawingView.layer.borderColor = UIColor.black.cgColor
                self.sketchView.addSubview(drawingView)
                drawingView.isHidden = true
                drawingView.isUserInteractionEnabled = false
                self.drawingViews.append(drawingView)
                
            }
            if sketchnote!.drawingViewRects!.count > 0 && !self.drawingViewsShown {
                self.toggleDrawingViews()
            }
        }
        
        // Help lines are horizontal lines displayed as a help to the user on the canvas, in order to let them write in straight lines.
        setupHelpLines()
        
        // Setup long press on canvas for inserting drawing region
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleSketchViewLongPress(_:)))
        longPressGesture.minimumPressDuration = 1.5
        self.sketchView.addGestureRecognizer(longPressGesture)
        
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        view.addInteraction(interaction)
        
        spotlightHelper = SpotlightHelper(viewController: self)!
        bioportalHelper = BioPortalHelper(viewController: self)!
    }
    
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        switch UIPencilInteraction.preferredTapAction {
        case .ignore:
            break
        case .showColorPalette:
            print("Color Palette Apple Pencil interaction. This has no effect in this app")
        case .switchEraser:
            self.toggleDrawTool()
            break
        case .switchPrevious:
            self.toggleDrawTool()
            break
        default:
            print("Unknown Pen action")
        }
    }
    
    private func toggleDrawTool() {
        if self.sketchView.drawTool == .eraser {
            self.sketchView.drawTool = .pen
            self.toolSelected(image: #imageLiteral(resourceName: "Pencil"))
        } else {
            self.sketchView.drawTool = .eraser
            self.toolSelected(image: #imageLiteral(resourceName: "Eraser"))
        }
    }
    
    // This function handles the insertion of a drawing region on the note's canvas.
    @objc func handleSketchViewLongPress(_ sender: UILongPressGestureRecognizer) {
        if (sender.state == UIGestureRecognizer.State.began)
        {
            let tapLocation = sender.location(in: sketchView)
            let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
            let closeAction = PopMenuDefaultAction(title: "Close")
            let action = PopMenuDefaultAction(title: "Insert Drawing", didSelect: { action in
                print("Inserting Drawing")
                var x = tapLocation.x
                var y = tapLocation.y
                if (x + 75) > self.sketchView.frame.width {
                    x = self.sketchView.frame.width - 150
                }
                else if (x - 75) < 0 {
                    x = 0
                }
                else {
                    x = x - 75
                }
                if (y + 75) > self.sketchView.frame.height {
                    x = self.sketchView.frame.height - 150
                }
                else if (y - 75) < 0 {
                    y = 0
                }
                else {
                    y = y - 75
                }
                let drawingView = UIView(frame: CGRect(x: x, y: y, width: 150, height: 150))
                drawingView.layer.borderWidth = 1
                drawingView.layer.borderColor = UIColor.black.cgColor
                self.sketchView.addSubview(drawingView)
                drawingView.isHidden = true
                drawingView.isUserInteractionEnabled = false
                self.drawingViews.append(drawingView)
                if !self.drawingViewsShown {
                    self.toggleDrawingViews()
                }
                self.sketchnote!.addDrawingViewRect(rect: drawingView.frame)
            })
            popMenu.addAction(action)
            popMenu.addAction(closeAction)
            self.present(popMenu, animated: true, completion: nil)
        }
    }
    
    // When the user closes the note, this function loops through each drawing region inserted on the note's canvas and generates an input image of the drawing within that drawing region for the drawing recognition model.
    private func processDrawingRecognition() {
        if self.helpLinesShown {
            self.toggleHelpLines()
        }
        // Clear all already recognized drawings from the note, as the entire canvas is re-scanned from scratch
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
                        let newPath = path.copy(strokingWithWidth: 150 * 0.04, lineCap: .round, lineJoin: .round, miterLimit: 0)
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
                        let newPath = path.copy(strokingWithWidth: 150 * 0.04, lineCap: .round, lineJoin: .round, miterLimit: 0)
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
        while (CGFloat(height) < self.sketchView.frame.height) {
            let line = SimpleLine(frame: CGRect(x: 0, y: height, width: self.view.frame.width, height: 1))
            line.isUserInteractionEnabled = false
            line.isHidden = true
            self.sketchView.addSubview(line)
            self.helpLines.append(line)
            height = height + 40
        }
    }
    private func toggleHelpLines() {
        self.helpLinesShown = !self.helpLinesShown
        
        for helpLine in self.helpLines {
            helpLine.isHidden = !self.helpLinesShown
        }
        
        if self.helpLinesShown == true {
            helpLinesButton.gradientStartColor = UIColor(red: 95.0/255.0, green: 193.0/255.0, blue: 148.0/255.0, alpha: 1)
            helpLinesButton.gradientEndColor = UIColor(red: 0.0, green: 122.0/255.0, blue: 255.0/255.0, alpha: 1)
        }
        else {
            helpLinesButton.gradientEndColor = nil
            helpLinesButton.gradientStartColor = nil
            helpLinesButton.gradientHorizontal = false
        }
    }
    
    // This function is called when the user closes the page, i.e. stops editing the note, and the app returns to the home page.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
        case "Placeholder":
            print("Placeholder")
        default:
            guard let button = sender as? UIBarButtonItem, button === closeButton else {
                print("Close button not pressed, cancelling")
                return
            }
            for helpLine in self.helpLines {
                helpLine.removeFromSuperview()
            }
            self.processDrawingRecognition()
            sketchnote?.image = sketchView.asImage()
            sketchnote?.setUpdateDate()
            self.storedPathArray = sketchView.pathArray
            print("Closing & Saving sketchnote")
        }
    }
    
    
    
    func willOpen(expandableButtonView: ExpandableButtonView) {
        if expandableButtonView == toolsMenu {
            if toolSizeMenu.state == ExpandableButtonView.State.opened {
                toolSizeMenu.close()
            }
            else {
                toolSizeMenu.isHidden = true
            }
        }
    }
    
    func didOpen(expandableButtonView: ExpandableButtonView) {
        if expandableButtonView == toolsMenu {
            toolSizeMenu.isHidden = true
        }
    }
    
    func willClose(expandableButtonView: ExpandableButtonView) {
        if expandableButtonView == toolsMenu {
            toolSizeMenu.isHidden = false
        }
    }
    
    func didClose(expandableButtonView: ExpandableButtonView) {
    }
    
    @objc func changedColor(_ slider: ColorSlider) {
        let color = slider.color
        sketchView.lineColor = color
    }
    
    private func toolSelected(image: UIImage) {
        toolsMenu.openImage = image
        toolsMenu.closeImage = image
    }
    
    private func toolSizeSelected(image: UIImage) {
        toolSizeMenu.openImage = image
        toolSizeMenu.closeImage = image
    }
    
    
    @IBAction func clearTapped(_ sender: UIBarButtonItem) {
        sketchView.clear()
        sketchView.subviews.forEach { $0.removeFromSuperview() }
        self.setupHelpLines()
        sketchnote?.relatedDocuments = [Document]()
        sketchnote?.drawings = [String]()
        sketchnote?.recognizedText = ""
    }
    @IBAction func redoTapped(_ sender: LGButton) {
        sketchView.redo()
    }
    @IBAction func undoTapped(_ sender: LGButton) {
        sketchView.undo()
    }
    @IBAction func helpLinesTapped(_ sender: LGButton) {
        self.toggleHelpLines()
    }
    @IBAction func drawingsTapped(_ sender: LGButton) {
        self.toggleDrawingViews()
    }
    private func toggleDrawingViews() {
        self.drawingViewsShown = !self.drawingViewsShown
        
        for drawingView in self.drawingViews {
            drawingView.isHidden = !self.drawingViewsShown
        }
        
        if self.drawingViewsShown == true {
            drawingsButton.gradientStartColor = UIColor(red: 95.0/255.0, green: 193.0/255.0, blue: 148.0/255.0, alpha: 1)
            drawingsButton.gradientEndColor = UIColor(red: 0.0, green: 122.0/255.0, blue: 255.0/255.0, alpha: 1)
        }
        else {
            drawingsButton.gradientEndColor = nil
            drawingsButton.gradientStartColor = nil
            drawingsButton.gradientHorizontal = false
        }
    }
    
    @IBAction func documentsTapped(_ sender: LGButton) {
        documentsButton.isLoading = true
        //self.processOCR(image: self.generateOCRImage())
        self.processHandwritingRecognition()
    }
    
    //MARK: Handwriting recognition process
    let handwritingRecognizer = HandwritingRecognizer()
    
    // This function generates the input image for the handwriting recognition model.
    private func generateOCRImage() -> UIImage {
        let canvas = UIView(frame: self.sketchView.frame)
        canvas.backgroundColor = .black
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
                    let newPath = path.copy(strokingWithWidth: penTool.lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 0)
                    let layer = CAShapeLayer()
                    layer.path = newPath
                    layer.strokeColor = UIColor.white.cgColor
                    layer.fillColor = UIColor.white.cgColor
                    canvas.layer.addSublayer(layer)
                }
            }
            else {
            }
        }
        return canvas.asImage()
    }
    
    /*private func processOCR(image: UIImage) {
        let visionText = self.handwritingRecognizer.recognize(image: image)
        if let visionText = visionText {
            self.sketchnote?.recognizedText = visionText.text
            self.annotateText(text: visionText.text)
        }
        else {
            self.documentsButton.isLoading = false
            self.showMessage("No documents could be found!", type: .error)
        }
    }*/
    
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
        handwritingRecognizer.recognize(note: sketchnote, penTools: newPenTools, canvasFrame: self.sketchView.frame) { (success, textData) in
            if success {
                if let textData = textData {
                    self.sketchnote.textDataArray.append(textData)
                    self.annotateText(text: textData.spellchecked)
                    print(textData.spellchecked)
                }
            }
            else {
                self.documentsButton.isLoading = false
                self.showMessage("No documents could be found!", type: .error)
            }
        }
    }
    
    func annotateText(text: String) {
        self.items = [Document]()
        documentsCollectionView.reloadData()
        
        self.documentsButton.isLoading = false
        self.bookshelf.isHidden = false
        if self.isBookshelfDraggedOut {
            self.bookshelfLeftConstraint.constant -= 300
            UIView.animate(withDuration: 0.25, delay: 0, options: UIView.AnimationOptions.curveEaseIn, animations: {
                self.view.layoutIfNeeded()
            }, completion: { (ended) in
            })
            self.isBookshelfDraggedOut = false
        }
        
        self.spotlightHelper.fetch(text: text)
        self.bioportalHelper.fetch(text: text)
        self.bioportalHelper.fetchCHEBI(text: text)
    }
    
    func displayNoDocumentsFound() {
        let alertController = UIAlertController(title: "No documents found.", message: "", preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "Close", style: .default)
        alertController.addAction(alertAction)
        self.present(alertController, animated: true)
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
    
    
    // **************************
    // MARK: View Setup Functions - The following functions are used to setup some views of the page.
    private func setupToolsMenu() {
        let insets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        // Tools
        let items = [
            ExpandableButtonItem(
                image: #imageLiteral(resourceName: "Pencil"),
                highlightedImage: #imageLiteral(resourceName: "Pencil"),
                imageEdgeInsets: insets,
                action: {_ in
                    self.sketchView.drawTool = .pen
                    self.toolSelected(image: #imageLiteral(resourceName: "Pencil"))
            }
            ),
            ExpandableButtonItem(
                image: #imageLiteral(resourceName: "Eraser"),
                highlightedImage: #imageLiteral(resourceName: "Eraser"),
                imageEdgeInsets: insets,
                action: {_ in
                    self.sketchView.drawTool = .eraser
                    self.toolSelected(image: #imageLiteral(resourceName: "Eraser"))
            }
            )
        ]
        // Tools
        
        toolsMenu = ExpandableButtonView(frame: CGRect(x: 2, y: 2, width: 50, height: 50), direction: .right, items: items)
        toolsMenu.backgroundColor = UIColor.lightGray
        toolsMenu.arrowWidth = 1
        toolsMenu.separatorWidth = 2
        toolsMenu.separatorInset = 6
        toolsMenu.openImage = #imageLiteral(resourceName: "Pencil")
        toolsMenu.closeImage = #imageLiteral(resourceName: "Pencil")
        toolsMenu.closeOnAction = true
        toolsMenu.layer.cornerRadius = 25
        toolsView.addSubview(toolsMenu)
        toolsMenu.delegate = self
    }
    
    private func setupToolSizeMenu() {
        let insets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        // Tools
        let items = [
            ExpandableButtonItem(
                image: #imageLiteral(resourceName: "ToolSize1"),
                highlightedImage: #imageLiteral(resourceName: "ToolSize1"),
                imageEdgeInsets: insets,
                action: {_ in
                    self.sketchView.lineWidth = 2
                    self.toolSizeSelected(image: #imageLiteral(resourceName: "ToolSize1"))
            }
            ),
            ExpandableButtonItem(
                image: #imageLiteral(resourceName: "ToolSize2"),
                highlightedImage: #imageLiteral(resourceName: "ToolSize2"),
                imageEdgeInsets: insets,
                action: {_ in
                    self.sketchView.lineWidth = 4
                    self.toolSizeSelected(image: #imageLiteral(resourceName: "ToolSize2"))
            }
            ),
            ExpandableButtonItem(
                image: #imageLiteral(resourceName: "ToolSize3"),
                highlightedImage: #imageLiteral(resourceName: "ToolSize3"),
                imageEdgeInsets: insets,
                action: {_ in
                    self.sketchView.lineWidth = 6
                    self.toolSizeSelected(image: #imageLiteral(resourceName: "ToolSize3"))
            }
            ),
            ExpandableButtonItem(
                image: #imageLiteral(resourceName: "ToolSize4"),
                highlightedImage: #imageLiteral(resourceName: "ToolSize4"),
                imageEdgeInsets: insets,
                action: {_ in
                    self.sketchView.lineWidth = 8
                    self.toolSizeSelected(image: #imageLiteral(resourceName: "ToolSize4"))
            }
            )
        ]
        // Tools
        
        toolSizeMenu = ExpandableButtonView(frame: CGRect(x: 55, y: 2, width: 50, height: 50), direction: .right, items: items)
        toolSizeMenu.backgroundColor = UIColor.lightGray
        toolSizeMenu.arrowWidth = 1
        toolSizeMenu.separatorWidth = 2
        toolSizeMenu.separatorInset = 6
        toolSizeMenu.openImage = #imageLiteral(resourceName: "ToolSize1")
        toolSizeMenu.closeImage = #imageLiteral(resourceName: "ToolSize1")
        toolSizeMenu.closeOnAction = true
        toolSizeMenu.layer.cornerRadius = 25
        toolsView.addSubview(toolSizeMenu)
        toolSizeMenu.delegate = self
    }
    
    //MARK: Bookshelf actions
    @IBAction func bookshelfCloseTapped(_ sender: LGButton) {
        self.bookshelf.isHidden = true
    }
    @IBAction func bookshelfHighlightTapped(_ sender: UISwitch) {
    }
    
    //MARK: Bookshelf resize
    @IBOutlet var bookshelfRightConstraint: NSLayoutConstraint!
    @IBOutlet var bookshelfTopConstraint: NSLayoutConstraint!
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
                    })
                    closeBookshelfLabel.isHidden = true
                }
            }
        }
    }
    
    @IBOutlet var documentsCollectionView: UICollectionView!
    
    let reuseIdentifier = "cell" // also enter this string as the cell identifier in the storyboard
    var items = [Document]()
    
    
    // MARK: - UICollectionViewDataSource protocol
    
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
        case .BioOntology:
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
        self.items.append(document)
        self.documentsCollectionView.reloadData()
        
        self.sketchnote?.relatedDocuments = items
    }
    
    func displayInBookshelf(documents: [Document]) {
        for doc in documents {
            self.items.append(doc)
        }
        self.documentsCollectionView.reloadData()
        
        self.sketchnote?.relatedDocuments = items
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
}
public class SimpleLine: UIView  {
    
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
