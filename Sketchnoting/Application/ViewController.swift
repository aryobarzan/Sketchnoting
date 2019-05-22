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
    @IBOutlet var noteSharingSwitch: UISwitch!
    
    // This property holds the user's note collections.
    var noteCollections = [NoteCollection]()
    var noteCollectionViews = [NoteCollectionView]()
    // (!!!!) This property maps the identifier (TimeInterval) of a sketchnote to its array of strokes drawn on its canvas.
    // As explained in the Sketchnote.swift file, the strokes drawn on a note's canvas are saved separately, as the strokes conform to a different encoding protocol.
    // Thus, when opening a sketchnote for editing, its identifier is used to retrieve its corresponing strokes (NSMutableArray) in this dictionary.
    var pathArrayDictionary = [TimeInterval: NSMutableArray]()
    
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
    // This view is displayed to a shared note's recipient, which allows the user to accept or reject the shared note.
    var noteShareView: NoteShareView!
    
    
    // This function initializes the home page view.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        // The note-sharing related variables are instantiated
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        noteShareView = NoteShareView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        noteShareView.center = self.view.center
        noteShareView.alpha = 1
        noteShareView.transform = CGAffineTransform(scaleX: 0.8, y: 1.2)
        noteShareView.setAcceptAction {
            self.acceptSharedNote()
        }
        noteShareView.setRejectAction {
            self.hideNoteShareView()
        }
        
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
        
        // The application attempts to load saved note collections from the device's disk here.
        // If any could be loaded, these are consequently displayed on the home page.
        if let savedNoteCollections = loadNoteCollections() {
            noteCollections += savedNoteCollections
            for collection in noteCollections {
                displayNoteCollection(collection: collection)
            }
        }
        
        // This loads the strokes array for each sketchnote saved to the device's disk.
        // See Sketchnote.swift file for more information as to why a sketchnote and the strokes on its canvas are stored separately
        if let savedPathArrayDictionary = loadPathArrayDictionary() {
            self.pathArrayDictionary = savedPathArrayDictionary
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
            if let pathArray = self.pathArrayDictionary[selectedSketchnote!.creationDate.timeIntervalSince1970] {
                sketchnoteViewController.storedPathArray = pathArray
            }
            sketchnoteViewController.new = false
            sketchnoteViewController.sketchnote = selectedSketchnote
            
        default:
            print("Not creating or editing sketchnote.")
        }
    }
    
    // Function used to save note collections to the device's disk for persistence.
    func saveNoteCollections() {
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(noteCollections) {
            UserDefaults.standard.set(encoded, forKey: "NoteCollections")
            print("Note Collections saved.")
        }
        else {
            print("Encoding failed for note collections")
        }
    }
    
    // Function used to save the strokes for each sketchnote as an entire dictionary to the device's disk for peristence.
    func savePathArrayDictionary() {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("PathArrayDictionary")
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: self.pathArrayDictionary, requiringSecureCoding: false) {
            try! encoded.write(to: ArchiveURLPathArray)
            print("Path Array Dictionary saved.")
        }
        else {
            print("Failed to encode path array dictionary.")
        }
    }
    
    // Consequently, this function is used to reload the dictionary (saved in the previous function) from the device's disk.
    private func loadPathArrayDictionary() -> [TimeInterval: NSMutableArray]? {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURLPathArray = DocumentsDirectory.appendingPathComponent("PathArrayDictionary")
        guard let codedData = try? Data(contentsOf: ArchiveURLPathArray) else { return nil }
        guard let data = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(codedData) as?
            [TimeInterval: NSMutableArray]) as [TimeInterval : NSMutableArray]??) else { return nil }
        print("Path Array Dictionary loaded.")
        return data
    }
    
    // This function reloads saved note collections from the device's disk.
    private func loadNoteCollections() -> [NoteCollection]? {
        let decoder = JSONDecoder()
        
        if let data = UserDefaults.standard.data(forKey: "NoteCollections"),
            let loadedNoteCollections = try? decoder.decode([NoteCollection].self, from: data) {
            print("Note Collections loaded")
            return loadedNoteCollections
        }
        print("Failed to load note collections.")
        return nil
    }
    
    // This function sets up a SketchnoteView for a sketchnote, displays it on the home page and sets up interaction with it.
    // When the view is tapped, the note is opened for editing.
    // When the view is long pressed, a pop-up menu is displayed for other actions such as sharing, deleting, etc.
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
                collectionView.noteCollection!.removeSketchnote(note: note)
                sketchnoteView.removeFromSuperview()
                self.saveNoteCollections()
            })
            popMenu.addAction(action)
            if sketchnoteView.sketchnote != nil {
                if sketchnoteView.sketchnote!.recognizedText != nil && !sketchnoteView.sketchnote!.recognizedText!.isEmpty {
                    let copyTextAction = PopMenuDefaultAction(title: "Copy Text", color: .white, didSelect: { action in
                        UIPasteboard.general.string = sketchnoteView.sketchnote!.recognizedText!
                        self.showMessage("Text copied to clipboard.", type: .success)
                    })
                    popMenu.addAction(copyTextAction)
                }
                let sendAction = PopMenuDefaultAction(title: "Send", color: .white, didSelect: { action in
                    self.sketchnoteToShare = sketchnoteView.sketchnote!
                    if let pathArray = self.pathArrayDictionary[self.sketchnoteToShare!.creationDate.timeIntervalSince1970] {
                        self.pathArrayToShare = pathArray
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.joinSession()
                    }
                })
                popMenu.addAction(sendAction)
                if sketchnoteView.sketchnote!.image != nil {
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
        
        noteCollectionView.setDeleteAction(for: .touchUpInside) {
            let alert = UIAlertController(title: "Delete Note Collection?", message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Confirm", style: .destructive, handler: { action in
                self.deleteNoteCollection(collection: collection)
                noteCollectionView.removeFromSuperview()
                self.saveNoteCollections()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true)
        }
        noteCollectionView.setShareAction {
            if noteCollectionView.noteCollection != nil && noteCollectionView.noteCollection!.notes.count > 0 {
                self.generatePDF(noteCollectionView: noteCollectionView)
            }
            let alert = UIAlertController(title: "Delete Note Collection?", message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Confirm", style: .destructive, handler: { action in
                self.deleteNoteCollection(collection: collection)
                noteCollectionView.removeFromSuperview()
                self.saveNoteCollections()
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
            
            var alreadyExists = false
            for i in 0..<noteCollectionViews.count {
                for j in 0..<noteCollectionViews[i].sketchnoteViews.count {
                    if noteCollectionViews[i].sketchnoteViews[j].sketchnote?.creationDate == note.creationDate {
                        noteCollectionViews[i].sketchnoteViews[j].setNote(note: note)
                        saveNoteCollections()
                        alreadyExists = true
                        break
                    }
                }
                if alreadyExists {
                    break
                }
            }
            saveNoteCollections()
            self.pathArrayDictionary[note.creationDate.timeIntervalSince1970] = sourceViewController.storedPathArray
            savePathArrayDictionary()
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
        self.noteCollections.append(noteCollection)
        
        displayNoteCollection(collection: noteCollection)
        saveNoteCollections()
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
                print("Waiting for drawing")
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

    
    // Other helper actions
    
    private func deleteNoteCollection(collection: NoteCollection) {
        var index = -1
        for i in 0..<self.noteCollections.count {
            if self.noteCollections[i] == collection {
                index = i
                break
            }
        }
        if index != -1 {
            print("Deleted")
            self.noteCollections.remove(at: index)
        }
    }
    
    // Multipeer Connectivity - The following functions are related to the note-sharing feature.
    @IBAction func noteSharingTapped(_ sender: UISwitch) {
        // The user's device is made visible to nearby devices for sharing
        if sender.isOn {
            startHosting()
        }
        else {
            // The user's device is no longer visible to other nearby devices
            if mcAdvertiserAssistant != nil {
                mcAdvertiserAssistant.stop()
            }
        }
    }
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
            let alert = UIAlertController(title: "Note shared", message: "The note has been sent to the selected device(s).", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .cancel, handler: nil))
            self.present(alert, animated: true)
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
        self.receivedSketchnote = received
        guard let receivedPath = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(receivedData![1]) as?
            NSMutableArray) as NSMutableArray??) else { return }
        self.receivedPathArray = receivedPath
        if self.receivedSketchnote != nil && self.receivedPathArray != nil {
            DispatchQueue.main.async {
                self.displayNoteShareView()
            }
        }
    }
    
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
    
    private func displayNoteShareView() {
        noteShareView.sketchnoteView.setNote(note: self.receivedSketchnote!)
        self.view.addSubview(self.noteShareView)
        self.dimView.isHidden = false
        self.noteShareView.transform = .identity
    }
    
    private func hideNoteShareView() {
        self.receivedSketchnote = nil
        self.receivedPathArray = nil
        self.dimView.isHidden = true
        self.noteShareView.removeFromSuperview()
    }
    
    private func acceptSharedNote() {
        print("Accepted shared note")
        if receivedSketchnote != nil && receivedPathArray != nil {
            let noteCollection = NoteCollection(title: "Shared Note", notes: nil)!
            self.noteCollections.append(noteCollection)
            noteCollection.addSketchnote(note: receivedSketchnote!)
            self.pathArrayDictionary[receivedSketchnote!.creationDate.timeIntervalSince1970] = receivedPathArray!

            displayNoteCollection(collection: noteCollection)
            saveNoteCollections()
            savePathArrayDictionary()
        }
        hideNoteShareView()
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
                        popOver.sourceView = noteCollectionView
                    }
                }
            } catch (let error) {
                print(error)
            }
        }
    }
}
