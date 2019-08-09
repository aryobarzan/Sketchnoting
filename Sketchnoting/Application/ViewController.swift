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

// This is the controller for the app's home page view.
// It contains the search bar and all the buttons related to it.
// It also contains note collection views, which in turn contain sketchnote views.

//This controller handles all interactions of the user on the home page, including creating new note collections and new notes, searching, sharing notes, and generating pdfs from notes.
class ViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate {

    @IBOutlet var searchField: UITextField!
    @IBOutlet var searchButton: LGButton!
    @IBOutlet var scrollView: UIScrollView!
    var notesStackView = UIStackView()
    @IBOutlet var dimView: UIView!
    @IBOutlet var clearSearchButton: LGButton!
    @IBOutlet var searchFiltersScrollView: UIScrollView!
    @IBOutlet var searchSeparator: UIView!
    var searchFiltersStackView = UIStackView()
    
    @IBOutlet var searchPanel: UIView!
    @IBOutlet var searchPanelHeightConstraint: NSLayoutConstraint!
    @IBOutlet var searchPanelButton: LGButton!
    var searchPanelOpen = false
    
    // This property holds the user's note collection views displayed on this home page.
    var noteCollectionViews = [NoteCollectionView]()
    
    // When the user taps a sketchnote to open it for editing, the app stores it in this property to remember which note is currently being edited.
    var selectedSketchnote: Sketchnote?
    // The view that is displayed as a pop-up for the user to draw a shape which is used for searching.
    var drawingSearchView: DrawingSearchView!
    
    // Each search term entered is stored.
    var searchFilters = [String]()
    // Each search term is displayed as a button, which when tapped, removes the search term.
    var searchFilterButtons = [UIButton]()
    
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
        
        // The note-sharing related variables are instantiated
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        setSharedNotesPanelStatus(notesAreShared: false)
        noteSharingPanel.layer.borderWidth = 1
        noteSharingPanel.layer.borderColor = UIColor.black.cgColor
        sharedNoteImageView.layer.borderWidth = 1
        sharedNoteImageView.layer.borderColor = UIColor.black.cgColor
        
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
        
        drawingSearchView = DrawingSearchView(frame: CGRect(x: 0, y: 0, width: 490, height: 600))
        drawingSearchView.center = self.view.center
        drawingSearchView.alpha = 1
        drawingSearchView.transform = CGAffineTransform(scaleX: 0.8, y: 1.2)
        drawingSearchView.setCloseAction(for: .touchUpInside) {
            self.hideDrawingSearchView()
        }
        drawingSearchView.setSearchAction(for: .touchUpInside) {
            self.searchByDrawing()
        }
 
        notesStackView.axis = .vertical
        notesStackView.distribution = .equalSpacing
        notesStackView.alignment = .fill
        notesStackView.spacing = 15
        scrollView.addSubview(notesStackView)
        notesStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            notesStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            notesStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            notesStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            notesStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            notesStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            ])

        for collection in NotesManager.shared.noteCollections {
            displayNoteCollection(collection: collection)
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
        searchPanelHeightConstraint.constant = 0
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
        case "EditSketchnote":
            guard let sketchnoteViewController = segue.destination as? SketchNoteViewController else {
                fatalError("Unexpected destination")
            }
            sketchnoteViewController.new = false
            sketchnoteViewController.sketchnote = selectedSketchnote
            
        default:
            print("Not creating or editing sketchnote.")
        }
    }
    
    //MARK: Search panel
    @IBAction func searchPanelButtonTapped(_ sender: LGButton) {
        if searchPanelOpen {
            searchPanelButton.bgColor = UIColor(red: 155.0/255.0, green: 83.0/255.0, blue: 229.0/255.0, alpha: 1)
            self.searchPanelHeightConstraint.constant = 0
            self.view.setNeedsUpdateConstraints()
            self.searchPanel.isHidden = true
        }
        else {
            searchPanelButton.bgColor = .lightGray
            self.searchPanelHeightConstraint.constant = 125
            self.view.setNeedsUpdateConstraints()
            UIView.animate(withDuration: 0.5, delay: 0, options: UIView.AnimationOptions.curveEaseIn, animations: {
                self.view.layoutIfNeeded()
            }, completion: { (finished: Bool) in
                self.searchPanel.isHidden = false
            })
        }
        
        searchPanelOpen = !searchPanelOpen
    }
    
    
    //MARK: Display notes
    
    func displaySketchnote(note: Sketchnote, collectionView: NoteCollectionView) {
        let sketchnoteView = SketchnoteView(frame: collectionView.stackView.frame)
        sketchnoteView.setNote(note: note)
        collectionView.sketchnoteViews.append(sketchnoteView)
        collectionView.stackView.insertArrangedSubview(sketchnoteView, at: 0)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleSketchnoteTap(_:)))
        sketchnoteView.isUserInteractionEnabled = true
        sketchnoteView.addGestureRecognizer(tap)
        sketchnoteView.setDeleteAction {
            let popMenu = PopMenuViewController(sourceView: sketchnoteView, actions: [PopMenuAction](), appearance: nil)
            popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
            let closeAction = PopMenuDefaultAction(title: "Cancel")
            let action = PopMenuDefaultAction(title: "Delete", color: .red, didSelect: { action in
                if collectionView.noteCollection != nil {
                    NotesManager.shared.delete(noteCollection: collectionView.noteCollection!, note: note)
                    sketchnoteView.removeFromSuperview()
                }
                
            })
            popMenu.addAction(action)
            if let sketchnote = sketchnoteView.sketchnote {
                if !sketchnote.getText().isEmpty {
                    let copyTextAction = PopMenuDefaultAction(title: "Copy Text", color: .white, didSelect: { action in
                        UIPasteboard.general.string = sketchnote.getText()
                        self.showMessage("Text copied to clipboard.", type: .success)
                    })
                    popMenu.addAction(copyTextAction)
                }
                let sendAction = PopMenuDefaultAction(title: "Send", color: .white, didSelect: { action in
                    self.sketchnoteToShare = sketchnote
                    self.pathArrayToShare = sketchnote.paths
                    //self.sketchnoteToShare = sketchnoteView.sketchnote!
                    
                    /*if let pathArray = NotesManager.shared.pathArrayDictionary[self.sketchnoteToShare!.creationDate.timeIntervalSince1970] {
                        self.pathArrayToShare = pathArray
                    }*/
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.joinSession()
                    }
                })
                popMenu.addAction(sendAction)
                if sketchnote.image != nil {
                    let shareAction = PopMenuDefaultAction(title: "Share", color: .white, didSelect: { action in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.generatePDF(sketchnoteView: sketchnoteView)
                        }
                    })
                    popMenu.addAction(shareAction)
                }
            }
            popMenu.addAction(closeAction)
            self.present(popMenu, animated: true, completion: nil)
        }
    }
    
    // This function sets up a NoteCollectionView for a given note collection and displays it on the homepage.
    // Interactions with the view's buttons are also set up, such as creating a new sketchnote in that note collection.
    private func displayNoteCollection(collection: NoteCollection) {
        let noteCollectionView = NoteCollectionView(frame: notesStackView.frame)
        noteCollectionView.parentViewController = self
        noteCollectionView.setNoteCollection(collection: collection)
        self.noteCollectionViews.append(noteCollectionView)
        self.notesStackView.insertArrangedSubview(noteCollectionView, at: 0)
        
        noteCollectionView.setShareAction {
            let alert = UIAlertController(title: "Note Collection", message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Share", style: .default, handler: { action in
                if noteCollectionView.noteCollection != nil && noteCollectionView.noteCollection!.notes.count > 0 {
                    self.generatePDF(noteCollectionView: noteCollectionView)
                }
            }))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                NotesManager.shared.delete(noteCollection: collection)
                noteCollectionView.removeFromSuperview()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true)
        }
        
        for n in collection.notes {
            displaySketchnote(note: n, collectionView: noteCollectionView)
        }
    }
    
    // This function is called when the user closes a note they were editing and the user returns to the homepage.
    // Upon return, the edited note is saved to disk.
    @IBAction func unwindToHome(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? SketchNoteViewController, let note = sourceViewController.sketchnote {
            
            NotesManager.shared.update(note: note, pathArray: sourceViewController.storedPathArray)
            var alreadyExists = false
            for i in 0..<noteCollectionViews.count {
                for j in 0..<noteCollectionViews[i].sketchnoteViews.count {
                    if noteCollectionViews[i].sketchnoteViews[j].sketchnote == note {
                        noteCollectionViews[i].sketchnoteViews[j].setNote(note: note)
                        alreadyExists = true
                        break
                    }
                }
                if alreadyExists {
                    break
                }
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
    
    // This function is called when the user taps a sketchnote's preview image to open it for editing.
    @objc func handleSketchnoteTap(_ sender: UITapGestureRecognizer) {
        let noteView = sender.view as! SketchnoteView
        self.selectedSketchnote = noteView.sketchnote
        self.performSegue(withIdentifier: "EditSketchnote", sender: self)
    }
    

    // This function is called when the user presses the "New Sketchnote" button in a NoteCollectionView.
    @IBAction func newNoteCollectionTapped(_ sender: LGButton) {
        let noteCollection = NoteCollection(title: "Untitled", notes: nil)!
        NotesManager.shared.add(noteCollection: noteCollection)
        displayNoteCollection(collection: noteCollection)
    }
    
    @IBAction func searchButtonTapped(_ sender: LGButton) {
        self.performSearch()
    }
    
    // This function loops through each search term and checks each sketchnote on the homepage.
    // If a sketchnote matches EVERY search term, the sketchnote remains visible. Otherwise it is hidden and not considered a matchin result.
    private func performSearch() {
        if !searchField.text!.isEmpty {
            let searchString = searchField.text!.lowercased()
            if !searchFilters.contains(searchString) {
                let filterButton = UIButton(frame: CGRect(x: 0, y: 0, width: 75, height: 30))
                filterButton.backgroundColor = .gray
                filterButton.setTitle(searchString, for: .normal)
                searchFiltersStackView.insertArrangedSubview(filterButton, at: 0)
                searchFilterButtons.append(filterButton)
                filterButton.isUserInteractionEnabled = true
                let filterTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleFilterTap(_:)))
                filterTapGesture.cancelsTouchesInView = false
                filterButton.addGestureRecognizer(filterTapGesture)
                
                searchFilters.append(searchString)
            }
            clearSearchButton.isHidden = false
            searchSeparator.isHidden = false
            searchField.text = ""
        }
        for noteCollectionView in noteCollectionViews {
            noteCollectionView.applySearchFilters(filters: self.searchFilters)
        }
        if noteCollectionViews.count == 0 {
            self.clearSearch()
        }
    }
    
    // By pressing a search term, the search term is removed and the application re-runs the search with the remaining search terms.
    @objc func handleFilterTap(_ sender: UITapGestureRecognizer) {
        let filterButton = sender.view as! UIButton
        if searchFilters.contains(filterButton.title(for: .normal) ?? "") {
            for i in 0..<searchFilters.count {
                if searchFilters[i] == filterButton.title(for: .normal) {
                    searchFilters.remove(at: i)
                    break
                }
            }
        }
        filterButton.removeFromSuperview()
        self.performSearch()
    }
    
    @IBAction func searchByDrawingTapped(_ sender: LGButton) {
        self.view.addSubview(self.drawingSearchView)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0, options: [],  animations: {
            self.dimView.isHidden = false
            self.dimView.alpha = 0.8
            self.drawingSearchView.transform = .identity
        })
    }
    @IBAction func clearSearchTapped(_ sender: LGButton) {
        clearSearch()
    }
    private func clearSearch() {
        for noteCollectionView in noteCollectionViews {
            noteCollectionView.showSketchnotes()
        }
        searchFilters = [String]()
        for searchFilterButton in searchFilterButtons {
            searchFilterButton.removeFromSuperview()
        }
        searchFilterButtons = [UIButton]()
        clearSearchButton.isHidden = true
        searchField.text = ""
        searchSeparator.isHidden = true
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
                        self.hideDrawingSearchView()
                        self.searchField.text = label
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
    private func searchByDrawing() {
        let croppedCGImage:CGImage = (drawingSearchView.sketchView.asImage().cgImage)!
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
    private func hideDrawingSearchView() {
        UIView.animate(withDuration: 0.0, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0, options: [], animations: {
            self.dimView.alpha = 0
            self.dimView.isHidden = true
            self.drawingSearchView.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
            
        }) { (success) in
            self.drawingSearchView.removeFromSuperview()
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
        guard let receivedData = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as?
            [Data]) as [Data]??) else { return }
        let decoder = JSONDecoder()
        guard let received = try? decoder.decode(Sketchnote.self, from: receivedData![0]) else {
            print("wrong data")
            return
        }
        received.sharedByDevice = peerID.displayName
        self.receivedSketchnote = received
        guard let receivedPath = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(receivedData![1]) as?
            NSMutableArray) as NSMutableArray??) else { return }
        self.receivedPathArray = receivedPath
        if self.receivedSketchnote != nil && self.receivedPathArray != nil {
            DispatchQueue.main.async {
                self.pendingSharedNotes.append((received, receivedPath!))
                self.setSharedNotesPanelStatus(notesAreShared: true)
                self.view.showMessage("Device \(peerID.displayName) shared a note with you!", type: .info)
            }
        }
    }
    var pendingSharedNotes = [(Sketchnote, NSMutableArray)]()
    
    func startHosting() {
        mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "hws-kb", discoveryInfo: nil, session: mcSession)
        mcAdvertiserAssistant.start()
        print("Started hosting session")
    }
    
    func joinSession() {
        let mcBrowser = MCBrowserViewController(serviceType: "hws-kb", session: mcSession)
        mcBrowser.delegate = self
        present(mcBrowser, animated: true)
        print("Joining sessions...")
    }
    
    // PDF Generation - The following functions are used for generating a pdf from either a single sketchnote or a note collection.
    // This generated pdf can then be saved to the device's disk.
    
    func generatePDF(sketchnoteView: SketchnoteView) {
        if sketchnoteView.sketchnote != nil && sketchnoteView.sketchnote!.image != nil {
            do {
                let data = try PDFGenerator.generated(by: [sketchnoteView.sketchnote!.image!])
                let activityController = UIActivityViewController(activityItems: [data], applicationActivities: nil)
                self.present(activityController, animated: true, completion: nil)
                if let popOver = activityController.popoverPresentationController {
                    popOver.sourceView = sketchnoteView
                }
            } catch (let error) {
                print(error)
            }
        }
    }
    func generatePDF(noteCollectionView: NoteCollectionView) {
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
    }
    
    //MARK: Sharing Panel
    @IBOutlet var noteSharingPanelButton: LGButton!
    @IBOutlet var noteSharingPanel: UIView!
    @IBOutlet var sharedNotesIndexLabel: UILabel!
    @IBOutlet var sharedByLabel: UILabel!
    @IBOutlet var sharedNoteImageView: UIImageView!
    
    @IBAction func noteSharingPanelButtonTapped(_ sender: LGButton) {
        showNoteSharingPanel()
    }
    private func showNoteSharingPanel() {
        UIView.animate(withDuration: 0.0, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0, options: [], animations: {
            self.dimView.alpha = 0.8
            self.dimView.isHidden = false
            self.noteSharingPanel.isHidden = false
        }) { (success) in
        }
    }
    private func hideNoteSharingPanel() {
        UIView.animate(withDuration: 0.0, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0, options: [], animations: {
            self.dimView.alpha = 0
            self.dimView.isHidden = true
            self.noteSharingPanel.isHidden = true
        }) { (success) in
        }
    }
    
    private var currentSharedNoteIndex = 0
    @IBAction func noteSharingPanelCloseTapped(_ sender: UIButton) {
        hideNoteSharingPanel()
    }
    @IBAction func noteSharingSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            startHosting()
            noteSharingPanelButton.bgColor = UIColor(red: 85.0/255.0, green: 117.0/255.0, blue: 193.0/255.0, alpha: 1)
        }
        else {
            // The user's device is no longer visible to other nearby devices
            if mcAdvertiserAssistant != nil {
                mcAdvertiserAssistant.stop()
            }
            noteSharingPanelButton.bgColor = UIColor(red: 201.0/255.0, green: 181.0/255.0, blue: 171.0/255.0, alpha: 1)
        }
    }
    @IBOutlet var previousSharedNoteButton: LGButton!
    @IBOutlet var nextSharedNoteButton: LGButton!
    @IBAction func previousSharedNoteTapped(_ sender: LGButton) {
        if pendingSharedNotes.count > 0 && currentSharedNoteIndex > 0 {
            currentSharedNoteIndex -= 1
            updateCurrentSharedNote()
        }
        updatePreviousSharedNoteButtonStatus()
        updateNextSharedNoteButtonStatus()
    }
    @IBAction func nextSharedNoteTapped(_ sender: LGButton) {
        if pendingSharedNotes.count > 0 && currentSharedNoteIndex < pendingSharedNotes.count - 1 {
            currentSharedNoteIndex += 1
            updateCurrentSharedNote()
        }
        updateNextSharedNoteButtonStatus()
        updatePreviousSharedNoteButtonStatus()
    }
    @IBOutlet var declineSharedNoteButton: LGButton!
    @IBOutlet var acceptSharedNoteButton: LGButton!
    @IBAction func declineSharedNoteTapped(_ sender: LGButton) {
        print("Rejected shared note")
        if receivedSketchnote != nil && receivedPathArray != nil {
            if pendingSharedNotes.count > 0 {
                pendingSharedNotes.remove(at: currentSharedNoteIndex)
            }
        }
        self.view.showMessage("Shared note rejected.", type: .error)
        
        DispatchQueue.main.async {
            if self.currentSharedNoteIndex > 0 {
                self.currentSharedNoteIndex -= 1
            }
            self.updatePreviousSharedNoteButtonStatus()
            self.updateNextSharedNoteButtonStatus()
            self.updateCurrentSharedNote()
            if self.pendingSharedNotes.count == 0 {
                self.setSharedNotesPanelStatus(notesAreShared: false)
            }
        }
    }
    @IBAction func acceptSharedNoteTapped(_ sender: LGButton) {
        print("Accepted shared note")
        if receivedSketchnote != nil && receivedPathArray != nil {
            if pendingSharedNotes.count > 0 {
                pendingSharedNotes.remove(at: currentSharedNoteIndex)
            }
            receivedSketchnote!.paths = receivedPathArray
            let noteCollection = NoteCollection(title: "Shared Note", notes: nil)!
            noteCollection.addSketchnote(note: receivedSketchnote!)
            NotesManager.shared.add(noteCollection: noteCollection)
            receivedSketchnote?.save()
            noteCollection.save()
            displayNoteCollection(collection: noteCollection)
        }
        self.view.showMessage("Shared note accepted and stored to your device.", type: .success)
        
        DispatchQueue.main.async {
            if self.currentSharedNoteIndex > 0 {
                self.currentSharedNoteIndex -= 1
            }
            self.updatePreviousSharedNoteButtonStatus()
            self.updateNextSharedNoteButtonStatus()
            self.updateCurrentSharedNote()
            if self.pendingSharedNotes.count == 0 {
                self.setSharedNotesPanelStatus(notesAreShared: false)
            }
        }
    }
    
    private func setSharedNotesPanelStatus(notesAreShared: Bool) {
        if !notesAreShared {
            sharedNoteImageView.isHidden = true
            sharedNotesIndexLabel.text = "No shared notes to view."
            sharedByLabel.text = "..."
            previousSharedNoteButton.isUserInteractionEnabled = false
            previousSharedNoteButton.bgColor = .lightGray
            nextSharedNoteButton.isUserInteractionEnabled = false
            nextSharedNoteButton.bgColor = .lightGray
            declineSharedNoteButton.isUserInteractionEnabled = false
            declineSharedNoteButton.bgColor = .lightGray
            acceptSharedNoteButton.isUserInteractionEnabled = false
            acceptSharedNoteButton.bgColor = .lightGray
            
            receivedSketchnote = nil
            receivedPathArray = nil
        }
        else {
            sharedNoteImageView.isHidden = false
            sharedNotesIndexLabel.text = "\(currentSharedNoteIndex + 1)/\(pendingSharedNotes.count)"
            updatePreviousSharedNoteButtonStatus()
            updateNextSharedNoteButtonStatus()
            updateCurrentSharedNote()
            declineSharedNoteButton.isUserInteractionEnabled = true
            declineSharedNoteButton.bgColor = UIColor(red: 187.0/255.0, green: 34.0/255.0, blue: 40.0/255.0, alpha: 1)
            acceptSharedNoteButton.isUserInteractionEnabled = true
            acceptSharedNoteButton.bgColor = UIColor(red: 85.0/255.0, green: 117.0/255.0, blue: 193.0/255.0, alpha: 1)
        }
    }
    private func updatePreviousSharedNoteButtonStatus() {
        var enabled = false
        if pendingSharedNotes.count > 0 {
            if currentSharedNoteIndex > 0 {
                enabled = true
                previousSharedNoteButton.isUserInteractionEnabled = true
                previousSharedNoteButton.bgColor = UIColor(red: 85.0/255.0, green: 117.0/255.0, blue: 193.0/255.0, alpha: 1)
            }
        }
        if !enabled {
            previousSharedNoteButton.isUserInteractionEnabled = false
            previousSharedNoteButton.bgColor = .lightGray
        }
    }
    private func updateNextSharedNoteButtonStatus() {
        var enabled = false
        if pendingSharedNotes.count > 0 {
            if currentSharedNoteIndex < pendingSharedNotes.count - 1 {
                enabled = true
                nextSharedNoteButton.isUserInteractionEnabled = true
                nextSharedNoteButton.bgColor = UIColor(red: 85.0/255.0, green: 117.0/255.0, blue: 193.0/255.0, alpha: 1)
            }
        }
        if !enabled {
            nextSharedNoteButton.isUserInteractionEnabled = true
            nextSharedNoteButton.bgColor = .lightGray
        }
    }
    private func updateCurrentSharedNote() {
        if pendingSharedNotes.count > 0 && currentSharedNoteIndex < pendingSharedNotes.count {
            DispatchQueue.main.async {
                let note = Array(self.pendingSharedNotes)[self.currentSharedNoteIndex].0
                let pathArray = Array(self.pendingSharedNotes)[self.currentSharedNoteIndex].1
                self.sharedNotesIndexLabel.text = "\(self.currentSharedNoteIndex + 1)/\(self.pendingSharedNotes.count)"
                self.sharedNoteImageView.image = note.image
                self.sharedByLabel.text = "Shared by: \(note.sharedByDevice ?? "Unknown")"
                self.receivedSketchnote = note
                self.receivedPathArray = pathArray
            }
        }
    }
    
}
