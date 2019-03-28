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
import CTSlidingUpPanel

class SketchNoteViewController: UIViewController, ExpandableButtonDelegate, SketchViewDelegate {

    @IBOutlet weak var topContainer: UIView!
    @IBOutlet var sketchView: SketchView!
    @IBOutlet weak var colorPickerContainer: UIView!
    @IBOutlet weak var toolsView: UIView!
    @IBOutlet weak var clearButton: UIBarButtonItem!
    @IBOutlet weak var redoButton: UIBarButtonItem!
    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet var documentsButton: LGButton!
    @IBOutlet var closeButton: UIBarButtonItem!
    
    var bottomController:CTBottomSlideController?;
    @IBOutlet var docsView: UIView!
    @IBOutlet var docsContentView: UIStackView!
    var documentViews = [DocumentView]()
    
    var colorSlider: ColorSlider!
    var toolsMenu: ExpandableButtonView!
    var toolSizeMenu: ExpandableButtonView!
    
    var sketchnote: Sketchnote?
    var new = false
    
    var helpLines = [SimpleLine]()
    var helpLinesShown = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        docsView.addBlurBackground()
        docsView.curveTopCorners()
        
        bottomController = CTBottomSlideController(parent: view, bottomView: docsView,
                                                   tabController: nil,
                                                   navController: self.navigationController, visibleHeight: 65)
        //0 is bottom and 1 is top. 0.5 would be center
        bottomController?.setAnchorPoint(anchor: 0.7)
        bottomController?.hidePanel()

        colorSlider = ColorSlider(orientation: .horizontal, previewSide: .bottom)
        colorSlider.color = .black
        colorSlider.frame = CGRect(x: 0, y: 0, width: 231, height: 55)
        colorPickerContainer.addSubview(colorSlider)
        colorSlider.addTarget(self, action: #selector(changedColor(_:)), for: .valueChanged)
        
        setupToolsMenu()
        setupToolSizeMenu()
        
        sketchView.sketchViewDelegate = self
        sketchView.lineColor = colorSlider.color
        sketchView.drawTool = .pen
        sketchView.lineWidth = 2
        
        //Drawing Recognition
        if let path = Bundle.main.path(forResource: "labels", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let labelNames = data.components(separatedBy: .newlines).filter { $0.count > 0 }
                self.labelNames.append(contentsOf: labelNames)
            } catch {
                print("error loading labels: \(error)")
            }
        }
        
        if sketchnote != nil {
            if new == true {
                sketchnote?.image = sketchView.asImage()
            }
            else {
                if sketchnote?.image != nil {
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
        } else {
            sketchnote = Sketchnote(image: sketchView.asImage(), relatedDocuments: nil, drawings: nil)
        }
        
        setupHelpLines()
    }
    
    private func setupHelpLines() {
        var height = CGFloat(40)
        while (CGFloat(height) < self.sketchView.frame.height) {
            let line = SimpleLine(frame: CGRect(x: 0, y: height, width: self.sketchView.frame.width, height: 2))
            line.isUserInteractionEnabled = false
            line.isHidden = true
            self.sketchView.addSubview(line)
            self.helpLines.append(line)
            
            height = height + 40
        }
        
    }
    
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
            sketchnote?.image = sketchView.asImage()
            sketchnote?.setUpdateDate()
            print("Closing & Saving sketchnote")
        }
    }
    
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
    }
    @IBAction func redoTapped(_ sender: UIBarButtonItem) {
        sketchView.redo()
    }
    @IBAction func undoTapped(_ sender: UIBarButtonItem) {
        sketchView.undo()
    }
    @IBAction func linesTapped(_ sender: UIBarButtonItem) {
        self.helpLinesShown = !self.helpLinesShown
        
        for helpLine in self.helpLines {
            helpLine.isHidden = !self.helpLinesShown
        }
    }
    @IBAction func documentsTapped(_ sender: LGButton) {
        documentsButton.isLoading = true
        self.processOCR(image: sketchView.asImage())
    }
    
    func tapCameraButton() {
        // Camera
        let cameraAction = UIAlertAction(title: "Camera", style: .default) { _ in
            self.setImageFromCamera()
        }
        // Gallery
        let galleryAction = UIAlertAction(title: "Gallery", style: .default) { _ in
            self.setImageFromGallery()
        }
        // Cancel
        let cancelAction = UIAlertAction(title: "Cancel", style: .default) { _ in }
        
        let alertController = UIAlertController(title: "Please select a Picture", message: nil, preferredStyle: .alert)
        alertController.addAction(cameraAction)
        alertController.addAction(galleryAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    private func setImageFromCamera() {
        PhotoRequestManager.requestPhotoFromCamera(self){ [weak self] result in
            switch result {
            case .success(let image):
                self?.sketchView.loadImage(image: image)
            case .faild:
                print("failed")
            case .cancel:
                break
            }
        }
    }
    
    private func setImageFromGallery() {
        PhotoRequestManager.requestPhotoLibrary(self){ [weak self] result in
            switch result {
            case .success(let image):
                self?.sketchView.loadImage(image: image)
            case .faild:
                print("failed")
            case .cancel:
                break
            }
        }
    }
    
    private func processOCR(image: UIImage) {
        let vision = Vision.vision()
        let textRecognizer = vision.onDeviceTextRecognizer()
        
        let image = VisionImage(image: image)
        
        textRecognizer.process(image) { result, error in
            self.documentsButton.isLoading = false
            guard error == nil, let result = result else {
                let alertController = UIAlertController(title: "Error", message: "No documents could be found.", preferredStyle: .alert)
                let alertAction = UIAlertAction(title: "Close", style: .default)
                alertController.addAction(alertAction)
                self.present(alertController, animated: true)
                return
            }
            let resultText = result.text
            self.sketchnote?.recognizedText = resultText
            //SemanticHelper.performBabelfyOnSketchnote(text: resultText, viewController: self)
            SemanticHelper.performSpotlightOnSketchnote(text: resultText, viewController: self)
        }
    }
    
    func displayBabelfyDocuments(text: String, json: NSArray) {
        documentsButton.isLoading = false
        bottomController?.expandPanel()
        
        /*var results = [String: String]()
        for item in json {
            let coherenceScore = item["coherenceScore"] as! Double
            let score = item["score"] as! Double
            if coherenceScore >= 0.4 || score >= 0.4 {
                let startIndex = (item["charFragment"] as! [String: Int])["start"]
                let endIndex = (item["charFragment"] as! [String: Int])["end"]
                
                let concept = text[startIndex!..<(endIndex!+1)]
                let conceptURL = item["DBpediaURL"] as! String
                if results[concept] == nil && !concept.isEmpty {
                    if !conceptURL.isEmpty {
                        results[concept] = conceptURL
                        let node = DocumentView(frame: panel.scrollView.frame)
                        node.titleLabel.text = concept
                        panel.scrollView.addSubview(node)
                        //documentsView.addBabelfyDocument(title: concept, url: conceptURL)
                    }
                }
            }
        }*/
        //let array = json.flatMap { $0 as? String }
        for docView in documentViews {
            docView.removeFromSuperview()
        }
        documentViews = [DocumentView]()
        
        for item in json {
            let array2 = item as! NSArray
            let node = DocumentView(frame: docsContentView.frame)
            node.titleLabel.text = array2[0] as? String
            node.center.x = docsContentView.center.x
            docsContentView.addArrangedSubview(node)
            documentViews.append(node)
        }
    }
    
    func displaySpotlightDocuments(text: String, json: Any) {
        documentsButton.isLoading = false
        bottomController?.expandPanel()

        for docView in documentViews {
            docView.removeFromSuperview()
        }
        documentViews = [DocumentView]()
        
        var results = [String: String]()
        let result = json as! [String: Any]
        let resources = result["Resources"] as? [[String: Any]]
        if resources != nil {
            for res in resources! {
                let concept = res["@surfaceForm"] as! String
                let conceptURL = res["@URI"] as! String
                if results[concept] == nil && !concept.isEmpty {
                    if !conceptURL.isEmpty {
                        results[concept] = conceptURL
                        let node = DocumentView(frame: docsContentView.frame)
                        node.titleLabel.text = concept
                        node.urlString = conceptURL
                        node.center.x = docsContentView.center.x
                        docsContentView.insertArrangedSubview(node, at: 0)
                        documentViews.append(node)
                        
                        let document = Document(title: concept, description: nil, URL: conceptURL, type: .Spotlight)
                        if document != nil {
                            print("Adding document: " + document!.title)
                            self.sketchnote!.addDocument(document: document!)
                        }
                    }
                }
            }
            
        }
    }
    
    @IBAction func docsOkayButton(_ sender: LGButton) {
        bottomController?.hidePanel()
    }
    
    // Drawing recognition
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
                    if score > 0.5 {
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
    func drawView(_ view: SketchView, didEndDrawUsingTool tool: AnyObject) {
        guard let tool = tool as? PenTool else { return }
        recognizeSketch(tool: tool)
        
        /*
        let croppedCGImage:CGImage = (newView.asImage().cgImage?.cropping(to: newPath.boundingBox.applying(CGAffineTransform(scaleX: 1.5, y: 1.5))))!
        let croppedImage = UIImage(cgImage: croppedCGImage)
        */
    }
    
    private func recognizeSketch(tool: PenTool) {
        let rectView = UIView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        rectView.backgroundColor = .black
        let translation = CGAffineTransform(translationX: -tool.path.boundingBox.minX, y: -tool.path.boundingBox.minY)
        let scale = CGAffineTransform(scaleX: 1, y: 1)
        let newPath = tool.path.copy(strokingWithWidth: 500 * 0.04, lineCap: .round, lineJoin: .round, miterLimit: 0, transform: translation.concatenating(scale))
        let layer = CAShapeLayer()
        layer.path = newPath
        layer.strokeColor = UIColor.white.cgColor
        layer.fillColor = UIColor.white.cgColor
        layer.frame = newPath.boundingBox
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: rectView.layer.bounds.midX, y: rectView.layer.bounds.midY)
        rectView.layer.addSublayer(layer)
        
        
        let croppedCGImage:CGImage = (rectView.asImage().cgImage)!
        let croppedImage = UIImage(cgImage: croppedCGImage)
        
        let resized = croppedImage.resize(newSize: CGSize(width: 28, height: 28))
        //sketchView.addSubview(rectView)
        
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
    }

    func resizePath(Fitin frame : CGRect , path : CGPath) -> CGPath{
        
        
        let boundingBox = path.boundingBox
        let boundingBoxAspectRatio = boundingBox.width / boundingBox.height
        let viewAspectRatio = frame.width  / frame.height
        var scaleFactor : CGFloat = 1.0
        if (boundingBoxAspectRatio > viewAspectRatio) {
            // Width is limiting factor
            
            scaleFactor = frame.width / boundingBox.width
        } else {
            // Height is limiting factor
            scaleFactor = frame.height / boundingBox.height
        }
        
        
        var scaleTransform = CGAffineTransform.identity
        scaleTransform = scaleTransform.scaledBy(x: scaleFactor, y: scaleFactor)
        scaleTransform.translatedBy(x: -boundingBox.minX, y: -boundingBox.minY)
        
        let scaledSize = boundingBox.size.applying(CGAffineTransform (scaleX: scaleFactor, y: scaleFactor))
        let centerOffset = CGSize(width: (frame.width - scaledSize.width ) / scaleFactor * 2.0, height: (frame.height - scaledSize.height) /  scaleFactor * 2.0 )
        scaleTransform = scaleTransform.translatedBy(x: centerOffset.width, y: centerOffset.height)
        //CGPathCreateCopyByTransformingPath(path, &scaleTransform)
        let  scaledPath = path.copy(using: &scaleTransform)
        
        
        return scaledPath!
    }
}
extension UIView
{
    func fixInView(_ container: UIView!) -> Void{
        self.translatesAutoresizingMaskIntoConstraints = false;
        self.frame = container.frame;
        container.addSubview(self);
        NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: container, attribute: .leading, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: container, attribute: .trailing, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: container, attribute: .top, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: container, attribute: .bottom, multiplier: 1.0, constant: 0).isActive = true
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
