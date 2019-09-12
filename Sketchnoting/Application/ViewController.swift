//
//  ViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 22/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import LGButton
import PopMenu
import MultipeerConnectivity
import PDFGenerator
import GSMessages
import SideMenu

// This is the controller for the app's home page view.
// It contains the search bar and all the buttons related to it.
// It also contains note collection views, which in turn contain sketchnote views.

//This controller handles all interactions of the user on the home page, including creating new note collections and new notes, searching, sharing notes, and generating pdfs from notes.
class ViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, NoteCollectionViewCellDelegate, UITableViewDataSource, UITableViewDelegate, TagTableViewCellDelegate, ColorPickerViewDelegate, ColorPickerViewDelegateFlowLayout {
    
    @IBOutlet var newNoteButton: UIButton!
    
    @IBOutlet var searchField: UITextField!
    @IBOutlet var searchFiltersScrollView: UIScrollView!
    var searchFiltersStackView = UIStackView()
    @IBOutlet var searchTypeButton: UIButton!
    private var searchType = SearchType.All
    @IBOutlet var searchPanelButton: UIButton!
    @IBOutlet var clearSearchButton: UIButton!
    
    @IBOutlet var searchPanel: UIView!
    @IBOutlet var noteSortingButton: UIButton!
    @IBOutlet var searchPanelHeightConstraint: NSLayoutConstraint!
    var searchPanelIsOpen = false
    
    @IBOutlet var drawingSearchPanel: UIView!
    @IBOutlet var closeDrawingSearchPanelButton: UIButton!
    @IBOutlet var clearDrawingSearchButton: UIButton!
    @IBOutlet var drawingSearchButton: UIButton!
    @IBOutlet var drawingSearchCanvas: SketchView!
    @IBOutlet var blurView: UIVisualEffectView!
    @IBOutlet var noteLargePreviewView: UIImageView!
    
    @IBOutlet weak var tagsPanel: UIView!
    @IBOutlet weak var tagsTableView: UITableView!
    @IBOutlet weak var newTagTextField: UITextField!
    @IBOutlet weak var newTagColorPickerView: ColorPickerView!
    @IBOutlet weak var tagsPanelTitleLabel: UILabel!
    // When the user taps a sketchnote to open it for editing, the app stores it in this property to remember which note is currently being edited.
    var selectedSketchnote: Sketchnote?
    // The view that is displayed as a pop-up for the user to draw a shape which is used for searching.
    
    // Each search term entered is stored.
    var searchFilters = [SearchFilter]()
    // Each search term is displayed as a button, which when tapped, removes the search term.
    var searchFilterViews = [SearchFilterView]()
    
    var notes: [Sketchnote]!
    
    // This properties are related to note-sharing.
    // Each device is given an ID (peerID).
    // If the user has enabled sharing for its own device, i.e. made their device visible to others, mcSession is instantiated and activated
    // mcAdvertiserAssistant is used internally by the Multipeer Connectivity module.
    var peerID: MCPeerID!
    var mcSession: MCSession!
    var mcAdvertiserAssistant: MCAdvertiserAssistant!
    
    // The note the user has selected to send to other devices is stored here.
    var sketchnoteToShare: Sketchnote?
    // Since the strokes of a note are stored separately from the note itself, the strokes linked to the above variable are stored in this following variable.
    var pathArrayToShare: NSMutableArray?
    // The two above variables are added to this following array and this array is sent to the receiving device(s)
    var dataToShare = [Data]()
    
    // Similarly, a received note from some other device is stored here.
    var receivedSketchnote: Sketchnote?
    // The strokes linked to that received note are stored here.
    var receivedPathArray: NSMutableArray?
    
    // This function initializes the home page view.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Tags table view setup
        tagsPanel.alpha = 0.0
        tagsPanel.layer.masksToBounds = true
        tagsPanel.layer.cornerRadius = 5
        tagsTableView.delegate = self
        tagsTableView.dataSource = self
        newTagColorPickerView.delegate = self
        newTagColorPickerView.layoutDelegate = self
        newTagColorPickerView.isSelectedColorTappable = false
        newTagColorPickerView.colors = [#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), #colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1), #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1), #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1), #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1), #colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1), #colorLiteral(red: 0.1294117719, green: 0.2156862766, blue: 0.06666667014, alpha: 1), #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1), #colorLiteral(red: 0.721568644, green: 0.8862745166, blue: 0.5921568871, alpha: 1), #colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1), #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1), #colorLiteral(red: 0.3098039329, green: 0.2039215714, blue: 0.03921568766, alpha: 1), #colorLiteral(red: 0.3176470697, green: 0.07450980693, blue: 0.02745098062, alpha: 1), #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1), #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1), #colorLiteral(red: 0.9568627477, green: 0.6588235497, blue: 0.5450980663, alpha: 1), #colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1), #colorLiteral(red: 0.5725490451, green: 0, blue: 0.2313725501, alpha: 1), #colorLiteral(red: 0.1921568662, green: 0.007843137719, blue: 0.09019608051, alpha: 1)]
        newTagColorPickerView.preselectedIndex = 0
        
        // The note-sharing related variables are instantiated
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        
        newNoteButton.layer.masksToBounds = true
        newNoteButton.layer.cornerRadius = 25
        
        searchPanelHeightConstraint.constant = 0
        
        drawingSearchPanel.layer.masksToBounds = true
        drawingSearchPanel.layer.cornerRadius = 5
        drawingSearchCanvas.backgroundColor = .black
        drawingSearchCanvas.drawTool = .pen
        drawingSearchCanvas.lineColor = .white
        drawingSearchCanvas.lineWidth = 350 * 0.04
        self.drawingSearchPanel.alpha = 0.0
        self.blurView.alpha = 0.0
        
        noteLargePreviewView.alpha = 0.0
        noteLargePreviewView.layer.masksToBounds = true
        noteLargePreviewView.layer.cornerRadius = 5
        noteLargePreviewView.layer.borderColor = UIColor.black.cgColor
        noteLargePreviewView.layer.borderWidth = 2
        
        // The search views are setup, including the search field and the pop-up view for searching by drawing
        self.searchField.delegate = self
        searchFiltersStackView.isUserInteractionEnabled = true
        searchFiltersStackView.axis = .horizontal
        searchFiltersStackView.distribution = .equalSpacing
        searchFiltersStackView.alignment = .fill
        searchFiltersStackView.spacing = 5
        searchFiltersScrollView.addSubview(searchFiltersStackView)
        searchFiltersStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchFiltersStackView.topAnchor.constraint(equalTo: searchFiltersScrollView.topAnchor),
            searchFiltersStackView.leadingAnchor.constraint(equalTo: searchFiltersScrollView.leadingAnchor),
            searchFiltersStackView.trailingAnchor.constraint(equalTo: searchFiltersScrollView.trailingAnchor),
            searchFiltersStackView.bottomAnchor.constraint(equalTo: searchFiltersScrollView.bottomAnchor),
            searchFiltersStackView.heightAnchor.constraint(equalTo: searchFiltersScrollView.heightAnchor)
            ])
        
        noteCollectionView.register(UINib(nibName: "NoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NoteCollectionViewCell")
        if let notes = NoteLoader.loadSketchnotes() {
            self.notes = notes
        }
        else {
            self.notes = [Sketchnote]()
        }
        
        self.items = self.notes
        noteCollectionView.reloadData()
        
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
    }
    
    // This function handles the cases where the user either creates a new note or wants to edit an existing note.
    // In both cases, the SketchNoteViewController page is loaded and displayed to the user and the note's information is passed on to that page.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch(segue.identifier ?? "") {
        case "NewSketchnote":
            guard let sketchnoteViewController = segue.destination as? SketchNoteViewController else {
                fatalError("Unexpected destination")
            }
            sketchnoteViewController.new = true
            sketchnoteViewController.sketchnote = selectedSketchnote
            break
        case "EditSketchnote":
            guard let sketchnoteViewController = segue.destination as? SketchNoteViewController else {
                fatalError("Unexpected destination")
            }
            sketchnoteViewController.new = false
            sketchnoteViewController.sketchnote = selectedSketchnote
            break
        case "NoteSharing":
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            break
        case "SideMenu":
            print("Side menu opened.")
            guard let sideMenuNavigationController = segue.destination as? UISideMenuNavigationController else {
                print("Could not retrieve side menu navigation controller.")
                return
            }
            sideMenuNavigationController.setNavigationBarHidden(true, animated: false)
            SideMenuManager.default.leftMenuNavigationController = sideMenuNavigationController
            SideMenuManager.default.addScreenEdgePanGesturesToPresent(toView: self.navigationController!.view, forMenu: .left)
            break
        default:
            print("Not creating or editing sketchnote.")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    // This function is called when the user closes a note they were editing and the user returns to the homepage.
    // Upon return, the edited note is saved to disk.
    @IBAction func unwindToHome(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? SketchNoteViewController, let note = sourceViewController.sketchnote {
            NotesManager.shared.update(note: note, pathArray: sourceViewController.storedPathArray)
            
            if SettingsManager.noteSortingByNewest() {
                self.items = self.items.sorted(by: { (note0: Sketchnote, note1: Sketchnote) -> Bool in
                    return note0 > note1
                })
                self.noteCollectionView.reloadData()
            }
            else {
                self.items = self.items.sorted()
                self.noteCollectionView.reloadData()
            }
        }
    }
    
    // When the user taps Return on the on-screen keyboard when the search field is in focus, the entered text is used as a search term and the application runs the search.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        searchField.resignFirstResponder()
        performSearch()
        return true
    }

    @IBAction func newNoteButtonTapped(_ sender: UIButton) {
        clearSearch()
        let newNote = Sketchnote(image: nil, relatedDocuments: nil, drawings: nil)!
        newNote.save()
        self.notes.append(newNote)
        self.items = self.notes
        
        selectedSketchnote = newNote
        performSegue(withIdentifier: "NewSketchnote", sender: self)
    }
    
    @IBAction func noteSortingTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
        let newestFirstAction = PopMenuDefaultAction(title: "Newest First", didSelect: { action in
            UserDefaults.settings.set(true, forKey: SettingsKeys.NoteSortingByNewest.rawValue)
            self.items = self.items.sorted(by: { (note0: Sketchnote, note1: Sketchnote) -> Bool in
                return note0 > note1
            })
            self.noteCollectionView.reloadData()
            
        })
        popMenu.addAction(newestFirstAction)
        let oldestFirstAction = PopMenuDefaultAction(title: "Oldest First", didSelect: { action in
            UserDefaults.settings.set(false, forKey: SettingsKeys.NoteSortingByNewest.rawValue)
            self.items = self.items.sorted()
            self.noteCollectionView.reloadData()
        })
        popMenu.addAction(oldestFirstAction)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    // MARK: Search
    
    @IBAction func searchPanelButtonTapped(_ sender: UIButton) {
        if searchPanelIsOpen {
            self.collapseSearchPanel()
        }
        else {
            self.expandSearchPanel()
        }
    }
    
    private func expandSearchPanel() {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0, animations: {
            self.searchPanelHeightConstraint.constant = 113
            self.view.layoutIfNeeded()
        }, completion: { (ended) in
        })
        searchPanelIsOpen = true
    }
    private func collapseSearchPanel() {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0, animations: {
            self.searchPanelHeightConstraint.constant = 0
            self.view.layoutIfNeeded()
        }, completion: { (ended) in
        })
        searchPanelIsOpen = false
    }
    
    private func performSearch() {
        if !searchField.text!.isEmpty {
            let searchString = searchField.text!.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            createSearchFilter(term: searchString, type: .All)
            clearSearchButton.isHidden = false
            searchField.text = ""
        }
        if self.notes.count == 0 || searchFilters.count == 0 {
            self.clearSearch()
        }
        else {
            clearSearchButton.isHidden = false
            var filteredNotes = [Sketchnote]()
            for note in self.notes {
                if note.applySearchFilters(filters: searchFilters) {
                    filteredNotes.append(note)
                }
            }
            self.items = filteredNotes
            noteCollectionView.reloadData()
        }
    }
    
    private func createSearchFilter(term: String, type: SearchType) {
        let termTrimmed = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filter = SearchFilter(term: termTrimmed, type: self.searchType)
        if !searchFilters.contains(filter) {
            let filterView = SearchFilterView(filter: filter)
            filterView.setContent(filter: filter)
            searchFiltersStackView.insertArrangedSubview(filterView, at: 0)
            searchFilterViews.append(filterView)
            filterView.isUserInteractionEnabled = true
            let filterTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleFilterTap(_:)))
            filterTapGesture.cancelsTouchesInView = false
            filterView.addGestureRecognizer(filterTapGesture)
            
            searchFilters.append(filter)
        }
    }
    
    // By pressing a search term, the search term is removed and the application re-runs the search with the remaining search terms.
    @objc func handleFilterTap(_ sender: UITapGestureRecognizer) {
        let filterView = sender.view as! SearchFilterView
        if filterView.searchFilter != nil {
            if searchFilters.contains(filterView.searchFilter!) {
                searchFilters.removeAll{$0 == filterView.searchFilter!}
            }
        }
        filterView.removeFromSuperview()
        self.performSearch()
    }
    
    @IBAction func drawingSearchButtonTapped(_ sender: UIButton) {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0.0, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.drawingSearchPanel.alpha = 1.0
            self.blurView.alpha = 1.0
            self.blurView.isHidden = false
            self.drawingSearchPanel.isHidden = false
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    @IBAction func clearSearchButtonTapped(_ sender: UIButton) {
        clearSearch()
    }

    private func clearSearch() {
        searchFilters = [SearchFilter]()
        for view in searchFilterViews {
            view.removeFromSuperview()
        }
        searchFilterViews = [SearchFilterView]()
        clearSearchButton.isHidden = true
        searchField.text = ""
        
        self.items = self.notes
        noteCollectionView.reloadData()
    }
    @IBAction func searchTypeButtonTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
        let allAction = PopMenuDefaultAction(title: "All", didSelect: { action in
            self.searchTypeButton.setTitle("All ↓", for: .normal)
            self.searchType = .All
            
        })
        popMenu.addAction(allAction)
        let textAction = PopMenuDefaultAction(title: "Text", didSelect: { action in
            self.searchTypeButton.setTitle("Text ↓", for: .normal)
            self.searchType = .Text
            
        })
        popMenu.addAction(textAction)
        let drawingAction = PopMenuDefaultAction(title: "Drawing", didSelect: { action in
            self.searchTypeButton.setTitle("Drawing ↓", for: .normal)
            self.searchType = .Drawing
            
        })
        popMenu.addAction(drawingAction)
        let documentAction = PopMenuDefaultAction(title: "Document", didSelect: { action in
            self.searchTypeButton.setTitle("Document ↓", for: .normal)
            self.searchType = .Document
            
        })
        popMenu.addAction(documentAction)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    // MARK: Drawing Search
    private func closeDrawingSearchPanel() {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0.0, options: UIView.AnimationOptions.curveEaseOut, animations: {
            self.drawingSearchPanel.alpha = 0.0
            self.blurView.alpha = 0.0
        }, completion: { completed in
            self.blurView.isHidden = true
            self.drawingSearchPanel.isHidden = true
             self.view.layoutIfNeeded()
        })
    }
    @IBAction func closeDrawingSearchTapped(_ sender: UIButton) {
        self.closeDrawingSearchPanel()
    }
    @IBAction func blurViewTapped(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            if !drawingSearchPanel.isHidden {
                 self.closeDrawingSearchPanel()
            }
            else {
                self.closeTagsPanel()
            }
        }
    }
    @IBAction func clearDrawingSearchTapped(_ sender: UIButton) {
        drawingSearchCanvas.clear()
    }
    @IBAction func drawingSearchTapped(_ sender: UIButton) {
        let croppedCGImage:CGImage = (drawingSearchCanvas.asImage().cgImage)!
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
    }
    
    // Drawing recognition
    private var labelNames: [String] = []
    // THis variable is used to run predictions using the drawing recognition model.
    // In this case, this model is used when the user searches by drawing. The user's drawing is fed to the recognition model.
    // If the model recognizes the drawing with at least a >50% confidence, the drawing's label is used as a search term.
    private let drawnImageClassifier = DrawnImageClassifier()
    private var currentPrediction: DrawnImageClassifierOutput? {
        didSet {
            if let currentPrediction = currentPrediction {
                
                let sorted = currentPrediction.category_softmax_scores.sorted { $0.value > $1.value }
                let top5 = sorted.prefix(5)
                print(top5.map { $0.key + "(" + String($0.value) + ")"}.joined(separator: ", "))
                var found = false
                for (label, score) in top5 {
                    if score > 0.5 {
                        self.closeDrawingSearchPanel()
                        if !searchPanelIsOpen {
                            self.expandSearchPanel()
                        }
                        createSearchFilter(term: label, type: .Drawing)
                        self.searchField.text = ""
                        self.performSearch()
                        found = true
                        break
                    }
                }
                if !found {
                    let alert = UIAlertController(title: "No drawing recognized", message: "Try drawing again and make sure the drawing isn't too small.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Okay", style: .cancel, handler: nil))
                    self.present(alert, animated: true)
                }
            }
            else {
                print("Waiting for drawing...")
            }
        }
    }
    
    // Multipeer Connectivity - The following functions are related to the note-sharing feature.

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true)
        // After the user has selected the nearby devices to send a note to, the main sharing function shareNote is called
        if sketchnoteToShare != nil && pathArrayToShare != nil {
            self.shareNote(note: sketchnoteToShare!, pathArray: pathArrayToShare!)
        }
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true)
        sketchnoteToShare = nil
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case MCSessionState.connected:
            print("Connected: \(peerID.displayName)")
            
        case MCSessionState.connecting:
            print("Connecting: \(peerID.displayName)")
            
        case MCSessionState.notConnected:
            print("Not Connected: \(peerID.displayName)")
        default:
            print("Non recognized state of session")
        }
    }
    
    func shareNote(note: Sketchnote, pathArray: NSMutableArray) {
        if mcSession.connectedPeers.count > 0 {
            dataToShare = [Data]()
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(note) {
                dataToShare.append(encoded)
            }
            else {
                print("Encoding failed for note.")
            }
            if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: pathArray, requiringSecureCoding: false) {
                dataToShare.append(encoded)
            }
            else {
                print("Failed to encode path array.")
            }
            do {
                let dataEncoded = try? NSKeyedArchiver.archivedData(withRootObject: dataToShare, requiringSecureCoding: false)
                if dataEncoded != nil {
                    // The note to share is sent to each nearby device that was selected by the user.
                    try mcSession.send(dataEncoded!, toPeers: mcSession.connectedPeers, with: .reliable)
                }
            } catch let error as NSError {
                let ac = UIAlertController(title: "Could not send the note", message: error.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "Close", style: .default))
                present(ac, animated: true)
            }
            self.view.showMessage("Note shared with the selected device(s).", type: .success)
        }
    }
    
    
    // When the user's device receives a shared note, this function is called to let the device know and to handle it.
    // In turn, a NoteShareView is displayed for the user to let them know.
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    }
    
    func joinSession() {
        let mcBrowser = MCBrowserViewController(serviceType: "hws-kb", session: mcSession)
        mcBrowser.delegate = self
        present(mcBrowser, animated: true)
        print("Joining sessions...")
    }
    
    // PDF Generation - The following functions are used for generating a pdf from either a single sketchnote or a note collection.
    // This generated pdf can then be saved to the device's disk.
    
    func generatePDF(noteViewCell: NoteCollectionViewCell) {
        if noteViewCell.sketchnote.image != nil {
            do {
                let data = try PDFGenerator.generated(by: [noteViewCell.sketchnote.image!])
                let activityController = UIActivityViewController(activityItems: [data], applicationActivities: nil)
                self.present(activityController, animated: true, completion: nil)
                if let popOver = activityController.popoverPresentationController {
                    popOver.sourceView = noteViewCell
                }
            } catch (let error) {
                print(error)
            }
        }
    }
    /*func generatePDF(noteCollectionView: NoteCollectionView) {
        if noteCollectionView.noteCollection != nil && noteCollectionView.noteCollection!.notes.count > 0 {
            do {
                var pages = [UIImage]()
                for note in noteCollectionView.noteCollection!.notes {
                    if note.image != nil {
                        pages.append(note.image!)
                    }
                }
                if pages.count > 0 {
                    let data = try PDFGenerator.generated(by: pages)
                    let activityController = UIActivityViewController(activityItems: [data], applicationActivities: nil)
                    self.present(activityController, animated: true, completion: nil)
                    if let popOver = activityController.popoverPresentationController {
                        popOver.sourceView = noteCollectionView.shareButton
                    }
                }
            } catch (let error) {
                print(error)
            }
        }
    }*/
    
    // MARK: Note Collection View
    @IBOutlet weak var noteCollectionView: UICollectionView!
    let reuseIdentifier = "NoteCollectionViewCell" // also enter this string as the cell identifier in the storyboard
    var items = [Sketchnote]()
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath as IndexPath) as! NoteCollectionViewCell
        cell.setNote(note: self.items[indexPath.item])
        cell.delegate = self
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.selectedSketchnote = self.items[indexPath.item]
        self.performSegue(withIdentifier: "EditSketchnote", sender: self)
        print("You selected note view cell #\(indexPath.item)!")
    }
    
    func noteCollectionViewCellMoreTapped(sketchnote: Sketchnote, sender: UIButton, cell: NoteCollectionViewCell) {
        print("More button of note view cell tapped.")
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
        let setTitleAction = PopMenuDefaultAction(title: "Set Title", color: .white, didSelect: { action in
            let alertController = UIAlertController(title: "Title for this note", message: nil, preferredStyle: .alert)
            
            let confirmAction = UIAlertAction(title: "Set", style: .default) { (_) in
                
                let title = alertController.textFields?[0].text
                
                sketchnote.setTitle(title: title ?? "Untitled")
                sketchnote.save()
                cell.titleLabel.text = sketchnote.getTitle()
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
            
            alertController.addTextField { (textField) in
                textField.placeholder = "Enter Note Title"
            }
            
            alertController.addAction(confirmAction)
            alertController.addAction(cancelAction)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.present(alertController, animated: true, completion: nil)
            }
        })
        popMenu.addAction(setTitleAction)
        let copyTextAction = PopMenuDefaultAction(title: "Copy Text", color: .white, didSelect: { action in
            UIPasteboard.general.string = sketchnote.getText()
        })
        popMenu.addAction(copyTextAction)
        let sendAction = PopMenuDefaultAction(title: "Send", color: .white, didSelect: { action in
            self.sketchnoteToShare = sketchnote
            self.pathArrayToShare = sketchnote.paths
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.joinSession()
            }
        })
        popMenu.addAction(sendAction)
        let shareAction = PopMenuDefaultAction(title: "Share", color: .white, didSelect: { action in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.generatePDF(noteViewCell: cell)
            }
        })
        popMenu.addAction(shareAction)
        let action = PopMenuDefaultAction(title: "Delete", color: .red, didSelect: { action in
            self.notes.removeAll{$0 == sketchnote}
            self.items.removeAll{$0 == sketchnote}
            sketchnote.delete()
            self.noteCollectionView.reloadData()
            
        })
        popMenu.addAction(action)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    func noteCollectionViewCellTagTapped(sketchnote: Sketchnote, sender: UIButton, cell: NoteCollectionViewCell) {
        var looseTagsToRemove = [Tag]()
        for tag in sketchnote.tags {
            if !TagsManager.tags.contains(tag) {
                looseTagsToRemove.append(tag)
            }
        }
        if looseTagsToRemove.count > 0 {
            for t in looseTagsToRemove {
                sketchnote.tags.removeAll{$0 == t}
            }
            sketchnote.save()
        }
        self.selectedNoteForTagEditing = sketchnote
        self.tagsPanelState = .EditNote
        self.showTagsPanel()
    }
    
    func noteCollectionViewCellLongPressed(sketchnote: Sketchnote, sender: UILongPressGestureRecognizer, cell: NoteCollectionViewCell) {
        switch sender.state {
        case .began:
            showLargeNotePreview(note: sketchnote)
        case .ended:
            hideLargeNotePreview()
        case .cancelled:
            hideLargeNotePreview()
        case .failed:
            hideLargeNotePreview()
        default:
            break
        }
    }
    
    private func showLargeNotePreview(note: Sketchnote) {
        self.noteLargePreviewView.image = note.image
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0.0, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.noteLargePreviewView.alpha = 1.0
            self.blurView.alpha = 1.0
            self.noteLargePreviewView.isHidden = false
            self.blurView.isHidden = false
            self.view.layoutIfNeeded()
        }, completion: { completed in
        })
    }
    
    private func hideLargeNotePreview() {
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0.0, options: UIView.AnimationOptions.curveEaseOut, animations: {
            self.noteLargePreviewView.alpha = 0.0
            self.blurView.alpha = 0.0
        }, completion: { completed in
            self.noteLargePreviewView.isHidden = true
            self.blurView.isHidden = true
            self.view.layoutIfNeeded()
        })
    }
    
    // MARK: Tags
    private var tagsPanelState = TagsPanelState.EditTags
    private enum TagsPanelState: String {
        case EditTags
        case EditNote
        case NewNote
    }
    private var selectedNoteForTagEditing: Sketchnote?
    
    private func updateTagsPanel() {
        switch self.tagsPanelState {
        case .EditTags:
            self.tagsPanelTitleLabel.text = "Manage Tags"
            self.tagsTableView.allowsSelection = false
            self.tagsTableView.allowsMultipleSelection = false
        case .EditNote:
            self.tagsPanelTitleLabel.text = "Edit Note Tags"
            self.tagsTableView.allowsSelection = true
            self.tagsTableView.allowsMultipleSelection = true
        case .NewNote:
            self.tagsPanelTitleLabel.text = "New Note With Tags"
            self.tagsTableView.allowsSelection = true
            self.tagsTableView.allowsMultipleSelection = true
        }
        tagsTableView.reloadData()
    }
    
    @IBAction func tagsButtonTapped(_ sender: UIButton) {
        showTagsPanel()
    }
    
    private func showTagsPanel() {
        self.updateTagsPanel()
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0.0, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.tagsPanel.alpha = 1.0
            self.blurView.alpha = 1.0
            self.blurView.isHidden = false
            self.tagsPanel.isHidden = false
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    private func closeTagsPanel() {
        if self.tagsPanelState == .EditNote && selectedNoteForTagEditing != nil {
            selectedNoteForTagEditing!.save()
        }
        self.tagsPanelState = .EditTags
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.25, delay: 0.0, options: UIView.AnimationOptions.curveEaseOut, animations: {
            self.tagsPanel.alpha = 0.0
            self.blurView.alpha = 0.0
        }, completion: { completed in
            self.blurView.isHidden = true
            self.tagsPanel.isHidden = true
            self.view.layoutIfNeeded()
        })
    }
    @IBAction func newTagTapped(_ sender: UIButton) {
        if let title = newTagTextField.text {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let newTag = Tag(title: trimmed, color: newTagColorPickerView.colors[newTagColorPickerView.indexOfSelectedColor ?? 0])
                TagsManager.add(tag: newTag)
                tagsTableView.reloadData()
                
                newTagTextField.text = ""
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TagsManager.tags.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tagsTableView.dequeueReusableCell(withIdentifier: "TagTableViewCell", for: indexPath) as! TagTableViewCell
        
        let tag = TagsManager.tags[indexPath.row]
        cell.setTag(tag: tag)
        cell.delegate = self
        
        return cell
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? TagTableViewCell {
            if self.tagsPanelState == .EditNote && selectedNoteForTagEditing != nil {
                for t in selectedNoteForTagEditing!.tags {
                    if cell.noteTag == t {
                        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                        break
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
       self.updateTagSelections()
    }
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.updateTagSelections()
    }
    private func updateTagSelections() {
        if self.tagsPanelState == .EditNote && selectedNoteForTagEditing != nil {
            var selectedTags = [Tag]()
            if let indexPathsForSelectedRows = tagsTableView.indexPathsForSelectedRows {
                for i in indexPathsForSelectedRows {
                    if i.row < TagsManager.tags.count {
                        let tag = TagsManager.tags[i.row]
                        selectedTags.append(tag)
                    }
                }
            }
            selectedNoteForTagEditing!.tags = selectedTags
        }
    }
    
    func deleteTagTapped(tag: Tag, sender: TagTableViewCell) {
        TagsManager.delete(tag: tag)
        tagsTableView.reloadData()
        self.updateTagSelections()
    }
    
    func colorPickerView(_ colorPickerView: ColorPickerView, didSelectItemAt indexPath: IndexPath) {
    }
    
    func colorPickerView(_ colorPickerView: ColorPickerView, didDeselectItemAt indexPath: IndexPath) {
    }
    
    func colorPickerView(_ colorPickerView: ColorPickerView, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 25, height: 25)
    }
    func colorPickerView(_ colorPickerView: ColorPickerView, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat(3)
    }
    func colorPickerView(_ colorPickerView: ColorPickerView, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}
