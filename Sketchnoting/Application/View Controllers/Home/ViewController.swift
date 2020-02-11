//
//  ViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 22/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

import PopMenu
import NVActivityIndicatorView
import NotificationBannerSwift
import DataCompression
import ViewAnimator
import SwiftGraph

import MultipeerConnectivity
import Vision
import PencilKit
import MobileCoreServices


// This is the controller for the app's home page view.
// It contains the search bar and all the buttons related to it.
// It also contains note collection views, which in turn contain sketchnote views.

//This controller handles all interactions of the user on the home page, including creating new note collections and new notes, searching, sharing notes, and generating pdfs from notes.
class ViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, NoteCollectionViewDetailCellDelegate, UIApplicationDelegate, UIPopoverPresentationControllerDelegate, UIDocumentPickerDelegate {
    
    private var selectedNoteForTagEditing: NoteX?
    
    @IBOutlet var newNoteButton: UIButton!
    @IBOutlet var noteLoadingIndicator: NVActivityIndicatorView!
    
    @IBOutlet var noteListViewButton: UIButton!
    @IBOutlet weak var filtersButton: UIButton!
    @IBOutlet weak var receivedNotesButton: UIButton!
    var receivedNotesBadge: BadgeHub!
    
    @IBOutlet var noteSortingButton: UIButton!
    
    @IBOutlet weak var clearSimilarNotesButton: UIButton!
    @IBOutlet weak var similarNotesTitleLabel: UILabel!
    
    var activeFiltersBadge: BadgeHub!
    var activeSearchFiltersBadge: BadgeHub!
        
    // This properties are related to note-sharing.
    // Each device is given an ID (peerID).
    // If the user has enabled sharing for its own device, i.e. made their device visible to others, mcSession is instantiated and activated
    // mcAdvertiserAssistant is used internally by the Multipeer Connectivity module.
    var peerID: MCPeerID!
    var mcSession: MCSession!
    var mcAdvertiserAssistant: MCAdvertiserAssistant!
    
    // The note the user has selected to send to other devices is stored here.
    var sketchnoteToShare: NoteX?
    // The two above variables are added to this following array and this array is sent to the receiving device(s)
    var dataToShare = [Data]()
    
    // Similarly, a received note from some other device is stored here.
    var receivedSketchnote: NoteX?
    // The strokes linked to that received note are stored here.
    var receivedPathArray: NSMutableArray?
    
    // This function initializes the home page view.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.tabBarController?.tabBar.isHidden = false
        
        activeFiltersBadge = BadgeHub(view: filtersButton)
        activeFiltersBadge.scaleCircleSize(by: 0.45)
        
        receivedNotesBadge = BadgeHub(view: receivedNotesButton)
        receivedNotesBadge.scaleCircleSize(by: 0.45)
        
        // The note-sharing related variables are instantiated
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        
        noteListViewButton.layer.masksToBounds = true
        noteListViewButton.layer.cornerRadius = 5
        
        noteCollectionView.register(UINib(nibName: "NoteCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: reuseIdentifier)
        noteCollectionView.register(UINib(nibName: "NoteCollectionViewDetailCell", bundle: nil), forCellWithReuseIdentifier: reuseIdentifierDetailCell)
        self.noteLoadingIndicator.isHidden = false
        self.noteLoadingIndicator.startAnimating()
        self.newNoteButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.items = SKFileManager.getCurrentFiles()
            self.noteCollectionView.reloadData()
            let animations = [AnimationType.from(direction: .bottom, offset: 200.0)]
            self.noteCollectionView.performBatchUpdates({
                UIView.animate(views: self.noteCollectionView.orderedVisibleCells,
                animations: animations, completion: {
                })
            })
            log.info("Files loaded.")
            self.noteLoadingIndicator.stopAnimating()
            self.noteLoadingIndicator.isHidden = true
            self.newNoteButton.isEnabled = true
        }
        
        let notificationCentre = NotificationCenter.default
        notificationCentre.addObserver(self, selector: #selector(self.notifiedImportSketchnote(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_IMPORT_NOTE), object: nil)
        notificationCentre.addObserver(self, selector: #selector(self.notifiedReceiveSketchnote(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_RECEIVE_NOTE), object: nil)
        notificationCentre.addObserver(self, selector: #selector(self.notifiedDeviceVisibility(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_DEVICE_VISIBILITY), object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        
        self.updateReceivedNotesButton()
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        self.updateDisplayedNotes(false)
        self.selectedNoteForTagEditing = nil
        activeFiltersBadge.setCount(TagsManager.filterTags.count)        
    }
    
    // Respond to NotificationCenter events
    @objc func notifiedImportSketchnote(_ noti : Notification)  {
        let importURL = (noti.userInfo as? [String : URL])!["importURL"]!
        print(importURL)
        self.imoortNote(url: importURL)
    }
    @objc func notifiedReceiveSketchnote(_ noti : Notification)  {
        updateReceivedNotesButton()
    }
    @objc func notifiedDeviceVisibility(_ noti : Notification)  {
        updateReceivedNotesButton()
    }
    
    private func updateReceivedNotesButton() {
        if SKFileManager.receivedNotesController.mcAdvertiserAssistant != nil {
            receivedNotesButton.tintColor = UIColor.systemBlue
        }
        else {
            receivedNotesButton.tintColor = UIColor.systemGray
        }
        receivedNotesBadge.setCount(SKFileManager.receivedNotesController.receivedNotes.count)
    }
    
    private func loadData() {
        self.updateDisplayedNotes(false)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch(segue.identifier ?? "") {
        case "NewSketchnote":
            log.info("New note.")
            break
        case "EditSketchnote":
            log.info("Editing note.")
            break
        case "NoteSharing":
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            break
        case "ShareNote":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? ShareNoteViewController {
                    destinationViewController.note = shareNoteObject
                }
            }
            break
        case "ManageTags":
            let destinationNC = segue.destination as! UINavigationController
            destinationNC.popoverPresentationController?.delegate = self
            destinationNC.popoverPresentationController?.sourceView = filtersButton
            if let destination = destinationNC.topViewController as? TagsViewController {
                destination.isFiltering = true
            }
            break
        case "EditNoteTags":
            let destinationNC = segue.destination as! UINavigationController
            destinationNC.popoverPresentationController?.delegate = self
            if let cell = self.selectedCellForTagEditing {
                destinationNC.popoverPresentationController?.sourceView = cell
            }
            if let destination = destinationNC.topViewController as? TagsViewController {
                destination.note = selectedNoteForTagEditing
            }
            break
        default:
            log.info("Unaccounted-for segue.")
        }
    }
    
    @IBAction func unwindToHome(sender: UIStoryboardSegue) {
        if sender.source is NoteViewController {
            let vc = sender.source as! NoteViewController
            if vc.openNote != nil {
                let note = vc.openNote!
                if let segue = sender as? UIStoryboardSegueWithCompletion {
                    segue.completion = {
                        self.open(note: note)
                    }
                }
            }
            self.updateDisplayedNotes(false)
        }
        self.tabBarController?.tabBar.isHidden = false
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if urls.count > 0 {
            imoortNote(url: urls[0])
        }
    }
    
    private func displayDocumentPicker() {
        let types: [String] = ["com.sketchnote"]
        let documentPicker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    @IBAction func importDocumentTapped(_ sender: UIButton) {
        displayDocumentPicker()
    }
    
    // MARK: Note display management
    private func updateDisplayedNotes(_ animated: Bool) {
        self.items = SKFileManager.getCurrentFiles()
        if let noteForSimilarityFilter = noteForSimilarityFilter, let similarNotes = similarNotes {
            self.items = [File]()
            self.items.append(noteForSimilarityFilter)
            self.items.append(contentsOf: similarNotes.map { $0.0 })
        }
        
        var filteredNotesToRemove = [File]()
        if TagsManager.filterTags.count > 0 {
            for file in self.items {
                if file is Folder {
                    filteredNotesToRemove.append(file)
                }
                else if let note = file as? NoteX {
                    for tag in TagsManager.filterTags {
                        if !note.tags.contains(tag) {
                            filteredNotesToRemove.append(note)
                            break
                        }
                    }
                }
            }
            self.items = self.items.filter { !filteredNotesToRemove.contains($0) }
        }
        
        if SettingsManager.noteSortingByNewest() {
            self.items = self.items.sorted(by: { (file0: File, file1: File) -> Bool in
                return file0 > file1
            })
        }
        else {
            self.items = self.items.sorted()
        }
       
        noteCollectionView.reloadData()
        if animated {
            let animations = [AnimationType.from(direction: .bottom, offset: 200.0)]
            noteCollectionView.performBatchUpdates({
                UIView.animate(views: noteCollectionView.orderedVisibleCells,
                animations: animations, completion: {
                })
            })
        }
    }
    
    @IBAction func noteListViewButtonTapped(_ sender: UIButton) {
        switch self.noteCollectionViewState {
        case .Grid:
            self.noteCollectionViewState = .Detail
            sender.backgroundColor = self.view.tintColor
            sender.tintColor = .white
        case .Detail:
            self.noteCollectionViewState = .Grid
            sender.backgroundColor = .clear
            sender.tintColor = self.view.tintColor
        }
        self.noteCollectionView.reloadData()
        self.noteCollectionView.collectionViewLayout.invalidateLayout()
        let animations = [AnimationType.from(direction: .left, offset: 200.0)]
        noteCollectionView.performBatchUpdates({
            UIView.animate(views: noteCollectionView.orderedVisibleCells,
            animations: animations, completion: {
            })
        })
    }

    @IBAction func newNoteButtonTapped(_ sender: UIButton) {
        let newNote = NoteX(name: "Untitled", parent: SKFileManager.currentFolder?.id, documents: nil)
        _ = SKFileManager.add(note: newNote)
        SKFileManager.activeNote = newNote
        performSegue(withIdentifier: "NewSketchnote", sender: self)
    }
    @IBAction func newFolderButtonTapped(_ sender: UIButton) {
        let newFolder = Folder(name: "Untitled", parent: SKFileManager.currentFolder?.id)
        _ = SKFileManager.add(folder: newFolder)
        self.updateDisplayedNotes(false)
    }
    
    @IBAction func noteSortingTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
        
        var newestFirstImage: UIImage? = nil
        var oldestFirstImage: UIImage? = nil
        if SettingsManager.noteSortingByNewest() {
            newestFirstImage = UIImage(systemName: "checkmark.circle.fill")
        }
        else {
            oldestFirstImage = UIImage(systemName: "checkmark.circle.fill")
        }
        let newestFirstAction = PopMenuDefaultAction(title: "Newest First", image: newestFirstImage,  didSelect: { action in
            UserDefaults.settings.set(true, forKey: SettingsKeys.NoteSortingByNewest.rawValue)
            self.updateDisplayedNotes(false)
            
        })
        popMenu.addAction(newestFirstAction)
        let oldestFirstAction = PopMenuDefaultAction(title: "Oldest First", image: oldestFirstImage, didSelect: { action in
            UserDefaults.settings.set(false, forKey: SettingsKeys.NoteSortingByNewest.rawValue)
            self.updateDisplayedNotes(false)
        })
        popMenu.addAction(oldestFirstAction)
        
        self.present(popMenu, animated: true, completion: nil)
    }
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in

            return self.makeNoteContextMenu(file: self.items[indexPath.row], point: point, cellIndexPath: indexPath)
        })
    }
    
    var shareNoteObject: NoteX?
    private func makeNoteContextMenu(file: File, point: CGPoint, cellIndexPath: IndexPath) -> UIMenu {
        var menuElements = [UIMenuElement]()
        let renameAction = UIAction(title: "Rename", image: UIImage(systemName: "text.cursor")) { action in
            self.renameFile(file: file)
        }
        menuElements.append(renameAction)
        if let note = file as? NoteX {
            let tagsAction = UIAction(title: "Manage Tags", image: UIImage(systemName: "tag.fill")) { action in
                self.editNoteTags(note: note, cell: self.noteCollectionView.cellForItem(at: cellIndexPath))
            }
            menuElements.append(tagsAction)
            let similarNotesAction = UIAction(title: "Similar Notes", image: UIImage(systemName: "link")) { action in
                self.filterSimilarNotesFor(note)
            }
            menuElements.append(similarNotesAction)
            let duplicateAction = UIAction(title: "Duplicate", image: UIImage(systemName: "doc.on.doc")) { action in
                _ = SKFileManager.add(note: note.duplicate())
                self.updateDisplayedNotes(false)
            }
            menuElements.append(duplicateAction)
            let copyTextAction = UIAction(title: "Copy Text", image: UIImage(systemName: "text.quote")) { action in
                UIPasteboard.general.string = note.getText()
                let banner = FloatingNotificationBanner(title: note.getName(), subtitle: "Copied text to clipboard.", style: .info)
                banner.show()
            }
            menuElements.append(copyTextAction)
            let shareAction = UIAction(title: "Share...", image: UIImage(systemName: "square.and.arrow.up")) { action in
                self.shareNoteObject = note
                self.shareNote(note: note, sender: UIView(frame: CGRect(x: point.x, y: point.y, width: point.x, height: point.y)))
            }
            menuElements.append(shareAction)
            let sendAction = UIAction(title: "Send", image: UIImage(systemName: "paperplane")) { action in
                self.sendNote(note: note)
            }
            menuElements.append(sendAction)
        }
        let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "xmark.circle.fill")) { action in
            self.deleteFile(file: file)
        }
        menuElements.append(deleteAction)
        return UIMenu(title: file.getName(), children: menuElements)
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
        if sketchnoteToShare != nil {
            self.sendNoteInternal(note: sketchnoteToShare!)
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
    
    private func sendNoteInternal(note: NoteX) {
        if mcSession.connectedPeers.count > 0 {
            if let noteData = note.encodeFileAsData() {
                do {
                    try mcSession.send(noteData, toPeers: mcSession.connectedPeers, with: .reliable)
                } catch let error as NSError {
                    let ac = UIAlertController(title: "Could not send the note", message: error.localizedDescription, preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "Close", style: .default))
                    present(ac, animated: true)
                }
                let banner = FloatingNotificationBanner(title: note.getName(), subtitle: "Note shared with the selected device(s).", style: .success)
                banner.show()
            }
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
    
    // MARK: Note Collection View
    private enum NoteCollectionViewState : String {
        case Grid
        case Detail
    }
    private var noteCollectionViewState = NoteCollectionViewState.Grid
    
    @IBOutlet weak var noteCollectionView: UICollectionView!
    let reuseIdentifier = "NoteCollectionViewCell" // also enter this string as the cell identifier in the storyboard
    let reuseIdentifierDetailCell = "NoteCollectionViewDetailCell"
    var items = [File]()
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch self.noteCollectionViewState {
        case .Grid:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath as IndexPath) as! NoteCollectionViewCell
            cell.setFile(file: self.items[indexPath.item])
            return cell
        case .Detail:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierDetailCell, for: indexPath as IndexPath) as! NoteCollectionViewDetailCell
            cell.setFile(file: self.items[indexPath.item])
            cell.delegate = self
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        switch self.noteCollectionViewState {
        case .Grid:
            return CGSize(width: CGFloat(200), height: CGFloat(300))
        case .Detail:
            return CGSize(width: collectionView.bounds.size.width - CGFloat(10), height: CGFloat(105))
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let file = self.items[indexPath.item]
        if let note = file as? NoteX {
            self.open(note: note)
        }
        else if let folder = file as? Folder {
            self.open(folder: folder)
        }
    }
    
    public func open(note: NoteX) {
        SKFileManager.activeNote = note
        self.performSegue(withIdentifier: "EditSketchnote", sender: self)
        log.info("Opening note.")
    }
    
    private func open(folder: Folder) {
        SKFileManager.currentFolder = folder
        self.updateDisplayedNotes(false)
        log.info("Opening folder.")
    }
    
    private func renameFile(file: File) {
        let alertController = UIAlertController(title: "Rename file", message: nil, preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: "Set", style: .default) { (_) in
            
            let name = alertController.textFields?[0].text
            
            file.setName(name: name ?? "Untitled")
            SKFileManager.save(file: file)
            self.updateDisplayedNotes(false)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Enter Note Title"
            if !file.getName().isEmpty && file.getName() != "Untitled" {
                textField.text = file.getName()
            }
        }
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    var noteForSimilarityFilter: NoteX?
    var similarNotes: [(NoteX, Float)]?
    private func filterSimilarNotesFor(_ note: NoteX) {
        Knowledge.setupSimilarityMatrix()
        similarNotes = Knowledge.similarNotesFor(note: note)
        if let similarNotes = similarNotes {
            if similarNotes.count > 1 {
                self.noteForSimilarityFilter = note
                self.updateDisplayedNotes(true)
                clearSimilarNotesButton.isHidden = false
                similarNotesTitleLabel.text = "Showing similar notes for: " + note.getName()
                similarNotesTitleLabel.isHidden = false
            }
            else {
                let banner = FloatingNotificationBanner(title: note.getName(), subtitle: "No similar notes could be found.", style: .info)
                banner.show()
            }
        }
    }
    @IBAction func clearSimilarNotesTapped(_ sender: UIButton) {
        clearSimilarNotes()
    }
    
    private func clearSimilarNotes() {
        noteForSimilarityFilter = nil
        similarNotes = nil
        self.updateDisplayedNotes(false)
        clearSimilarNotesButton.isHidden = true
        similarNotesTitleLabel.isHidden = true
    }
    
    var selectedCellForTagEditing: UICollectionViewCell?
    private func editNoteTags(note: NoteX, cell: UICollectionViewCell?) {
        var looseTagsToRemove = [Tag]()
        for tag in note.tags {
            if !TagsManager.tags.contains(tag) {
                looseTagsToRemove.append(tag)
            }
        }
        if looseTagsToRemove.count > 0 {
            for t in looseTagsToRemove {
                note.tags.removeAll{$0 == t}
            }
            SKFileManager.save(file: note)
        }
        self.selectedNoteForTagEditing = note
        self.selectedCellForTagEditing = cell
        self.performSegue(withIdentifier: "EditNoteTags", sender: self)
       }

    private func shareNote(note: NoteX, sender: UIView) {
        self.performSegue(withIdentifier: "ShareNote", sender: sender)
    }
    
    // TO UPDATE
    func imoortNote(url: URL) {
        if let imported = SKFileManager.importNoteFile(url: url) {
            if SKFileManager.notes.contains(imported) {
                log.info("Sketchnote already in your library, updating its data.")
                let banner = FloatingNotificationBanner(title: imported.getName(), subtitle: "This imported note is already in your library. It has been updated.", style: .info)
                banner.show()
                SKFileManager.save(file: imported)
            }
            else {
                log.info("Importing new sketchnote.")
                _ = SKFileManager.add(note: imported)
                let banner = FloatingNotificationBanner(title: imported.getName(), subtitle: "Note imported and added to your library.", style: .info)
                banner.show()
            }
            self.updateDisplayedNotes(false)
        }
        else {
            log.error("Note could not be imported.")
            let banner = FloatingNotificationBanner(title: "Error", subtitle: "The note could not be imported. It may be corrupted.", style: .warning)
            banner.show()
        }
    }
    
    private func sendNote(note: NoteX) {
        self.sketchnoteToShare = note
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.joinSession()
        }
    }
    
    private func deleteFile(file: File) {
        let alert = UIAlertController(title: "Delete File", message: "Are you sure you want to delete this file?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
              self.items.removeAll{$0 == file}
              SKFileManager.delete(file: file)
              self.noteCollectionView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
              log.info("Not deleting note.")
        }))
        self.present(alert, animated: true, completion: nil)
    }

    
    // MARK: Note Collection View DETAIL cell delegate
    func noteCollectionViewDetailCellRenameTapped(file: File, sender: UIButton, cell: NoteCollectionViewDetailCell) {
        self.renameFile(file: file)
    }
    
    func noteCollectionViewDetailCellTagTapped(note: NoteX, sender: UIButton, cell: NoteCollectionViewDetailCell) {
        self.editNoteTags(note: note, cell: cell)
    }
    
    func noteCollectionViewDetailCellShareTapped(note: NoteX, sender: UIButton, cell: NoteCollectionViewDetailCell) {
        self.shareNote(note: note, sender: cell)
    }
    
    func noteCollectionViewDetailCellSendTapped(note: NoteX, sender: UIButton, cell: NoteCollectionViewDetailCell) {
        self.sendNote(note: note)
    }
    
    func noteCollectionViewDetailCellCopyTextTapped(note: NoteX, sender: UIButton, cell: NoteCollectionViewDetailCell) {
        UIPasteboard.general.string = note.getText()
    }
    
    func noteCollectionViewDetailCellDeleteTapped(file: File, sender: UIButton, cell: NoteCollectionViewDetailCell) {
        self.deleteFile(file: file)
    }

}
