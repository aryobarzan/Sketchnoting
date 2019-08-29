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
class ViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, NoteCollectionViewCellDelegate {
    
    @IBOutlet var searchField: UITextField!
    @IBOutlet var clearSearchButton: LGButton!
    @IBOutlet var searchFiltersScrollView: UIScrollView!
    @IBOutlet var searchSeparator: UIView!
    var searchFiltersStackView = UIStackView()
    
    @IBOutlet var searchPanel: UIView!
    @IBOutlet weak var noteSortingButton: UIButton!
    
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
 
        noteCollectionView.register(UINib(nibName: "NoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "NoteCollectionViewCell")
        if let notes = NoteLoader.loadSketchnotes() {
            items = notes
            noteCollectionView.reloadData()
        }
        
        if SettingsManager.noteSortingByNewest() {
            self.noteSortingButton.titleLabel?.text = "Newest First"
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

    @IBAction func newNoteTapped(_ sender: LGButton) {
        let newNote = Sketchnote(image: nil, relatedDocuments: nil, drawings: nil)!
        newNote.save()
        self.items.append(newNote)
        
        selectedSketchnote = newNote
        performSegue(withIdentifier: "NewSketchnote", sender: self)
    }
    @IBAction func noteSortingTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
        let newestFirstAction = PopMenuDefaultAction(title: "Newest First", didSelect: { action in
            self.noteSortingButton.titleLabel?.text = "Newest First"
            UserDefaults.settings.set(true, forKey: SettingsKeys.NoteSortingByNewest.rawValue)
            self.items = self.items.sorted(by: { (note0: Sketchnote, note1: Sketchnote) -> Bool in
                return note0 > note1
            })
            self.noteCollectionView.reloadData()
            
        })
        popMenu.addAction(newestFirstAction)
        let oldestFirstAction = PopMenuDefaultAction(title: "Oldest First", didSelect: { action in
            self.noteSortingButton.titleLabel?.text = "Oldest First"
            UserDefaults.settings.set(false, forKey: SettingsKeys.NoteSortingByNewest.rawValue)
            self.items = self.items.sorted()
            self.noteCollectionView.reloadData()
        })
        popMenu.addAction(oldestFirstAction)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    // This function loops through each search term and checks each sketchnote on the homepage.
    // If a sketchnote matches EVERY search term, the sketchnote remains visible. Otherwise it is hidden and not considered a matchin result.
    private func performSearch() {
        if !searchField.text!.isEmpty {
            let searchString = searchField.text!.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
        if items.count == 0 {
            self.clearSearch()
        }
        else {
            var filteredNotes = [Sketchnote]()
            for note in items {
                if note.applySearchFilters(filters: searchFilters) {
                    filteredNotes.append(note)
                }
            }
            self.items = filteredNotes
            noteCollectionView.reloadData()
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
            self.drawingSearchView.transform = .identity
        })
    }
    @IBAction func clearSearchTapped(_ sender: LGButton) {
        clearSearch()
    }
    private func clearSearch() {
        searchFilters = [String]()
        for searchFilterButton in searchFilterButtons {
            searchFilterButton.removeFromSuperview()
        }
        searchFilterButtons = [UIButton]()
        clearSearchButton.isHidden = true
        searchField.text = ""
        searchSeparator.isHidden = true
        
        self.items = [Sketchnote]()
        if let notes = NoteLoader.loadSketchnotes() {
            self.items = notes
        }
        noteCollectionView.reloadData()
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
    
    func noteCollectionViewCellMoreTapped(sketchnote: Sketchnote, sender: NoteCollectionViewCell) {
        print("More button of note view cell tapped.")
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
        let setTitleAction = PopMenuDefaultAction(title: "Set Title", color: .white, didSelect: { action in
            let alertController = UIAlertController(title: "Title for this note", message: nil, preferredStyle: .alert)
            
            let confirmAction = UIAlertAction(title: "Set", style: .default) { (_) in
                
                let title = alertController.textFields?[0].text
                
                sketchnote.setTitle(title: title ?? "Untitled")
                sketchnote.save()
                sender.titleLabel.text = sketchnote.getTitle()
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.joinSession()
            }
        })
        popMenu.addAction(sendAction)
        if sketchnote.image != nil {
            let shareAction = PopMenuDefaultAction(title: "Share", color: .white, didSelect: { action in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.generatePDF(noteViewCell: sender)
                }
            })
            popMenu.addAction(shareAction)
        }
        let action = PopMenuDefaultAction(title: "Delete", color: .red, didSelect: { action in
            self.items.removeAll{$0 == sketchnote}
            sketchnote.delete()
            self.noteCollectionView.reloadData()
            
        })
        popMenu.addAction(action)
        self.present(popMenu, animated: true, completion: nil)
    }
}
