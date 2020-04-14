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
import BSImagePicker

import MultipeerConnectivity
import Vision
import PencilKit
import MobileCoreServices
import VisionKit
import Photos

class ViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIApplicationDelegate, UIPopoverPresentationControllerDelegate, UIDocumentPickerDelegate, VNDocumentCameraViewControllerDelegate, UICollectionViewDragDelegate, UICollectionViewDropDelegate, FolderButtonDelegate {
    
    @IBOutlet weak var navigationHierarchyScrollView: UIScrollView!
    @IBOutlet weak var navigationHierarchyStackView: UIStackView!
    private var folderButtons = [FolderButton]()
    private var spacerView = UIView()
    
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
        noteCollectionView.dragDelegate = self
        noteCollectionView.dropDelegate = self
        noteCollectionView.dragInteractionEnabled = true
        
        self.noteLoadingIndicator.isHidden = false
        self.noteLoadingIndicator.startAnimating()
        self.newNoteButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.updateDisplayedNotes(true)
            self.updateFoldersHierarchy()
            log.info("Files loaded.")
            self.noteLoadingIndicator.stopAnimating()
            self.noteLoadingIndicator.isHidden = true
            self.newNoteButton.isEnabled = true
        }
        
        let notificationCentre = NotificationCenter.default
        notificationCentre.addObserver(self, selector: #selector(self.notifiedFileImport(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_IMPORT_NOTE), object: nil)
        notificationCentre.addObserver(self, selector: #selector(self.notifiedReceiveSketchnote(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_RECEIVE_NOTE), object: nil)
        notificationCentre.addObserver(self, selector: #selector(self.notifiedDeviceVisibility(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_DEVICE_VISIBILITY), object: nil)
        
        if noteCollectionViewState == .List {
            noteListViewButton.backgroundColor = self.view.tintColor
            noteListViewButton.tintColor = .black
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updateReceivedNotesButton()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.noteCollectionView.reloadData()
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        self.updateDisplayedNotes(false)
        self.selectedNoteForTagEditing = nil
        activeFiltersBadge.setCount(TagsManager.filterTags.count)        
    }
    
    // Respond to NotificationCenter events
    @objc func notifiedFileImport(_ noti : Notification)  {
        let importURL = (noti.userInfo as? [String : URL])!["importURL"]!
        log.info(importURL)
        self.manageFileImport(urls: [importURL])
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
        case "Settings":
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
    
    private func manageFileImport(urls: [URL]) {
        if urls.count > 0 {
            let (importedNotes, importedImages, importedPDFs, importedTexts) = ImportHelper.importItems(urls: urls, n: nil)
            for note in importedNotes {
                if SKFileManager.notes.contains(note) {
                    log.info("Note is already in your library, updating its data.")
                    SKFileManager.save(file: note)
                }
                else {
                    log.info("Importing new note.")
                    _ = SKFileManager.add(note: note)
                }
            }
            if importedImages.count > 0 {
                let newNote = createNoteFromImages(images: importedImages)
                log.info("New note from imported images.")
                _ = SKFileManager.add(note: newNote)
            }
            for pdf in importedPDFs {
                if pdf.pageCount > 0 {
                    var pdfTitle = "Imported PDF"
                    if let attributes = pdf.documentAttributes {
                        if let title = attributes["Title"] as? String {
                            if !title.isEmpty {
                                pdfTitle = title
                            }
                        }
                    }
                    let newNote = NoteX(name: pdfTitle, parent: SKFileManager.currentFolder?.id, documents: nil)
                    var setPDFForCurrentPage = false
                    for i in 0..<pdf.pageCount {
                        if let pdfPage = pdf.page(at: i) {
                            if !setPDFForCurrentPage {
                                setPDFForCurrentPage = true
                                newNote.getCurrentPage().backdropPDFData = pdfPage.dataRepresentation
                            }
                            else {
                                let newPage = NoteXPage()
                                newPage.backdropPDFData = pdfPage.dataRepresentation
                                newNote.pages.append(newPage)
                            }
                        }
                    }
                    log.info("New note from imported pdf.")
                    _ = SKFileManager.add(note: newNote)
                }
            }
            self.updateDisplayedNotes(true)
            let banner = FloatingNotificationBanner(title: "Documents", subtitle: "Imported your selected items.", style: .info)
            banner.show()
            self.updateDisplayedNotes(true)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.manageFileImport(urls: urls)
    }
    
    private func displayDocumentPicker() {
        let types: [String] = ["com.sketchnote", String(kUTTypeImage), String(kUTTypePDF)]
        let documentPicker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        documentPicker.allowsMultipleSelection = true
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    private func displayImagePicker() {
        ImagePickerHelper.displayImagePickerWithImageOutput(vc: self, completion: { images in
            if images.count > 0 {
                let newNote = self.createNoteFromImages(images: images)
                log.info("New note from imported images (camera roll).")
                _ = SKFileManager.add(note: newNote)
                self.updateDisplayedNotes(true)
            }
        })
    }
    
    private func createNoteFromImages(images: [UIImage]) -> NoteX {
        let newNote = NoteX(name: "Imported Images", parent: SKFileManager.currentFolder?.id, documents: nil)
        for image in images {
            let noteImage = NoteImage(image: image)
            newNote.getCurrentPage().images.append(noteImage)
        }
        return newNote
    }
    
    @IBAction func importDocumentTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
        let noteImportAction = PopMenuDefaultAction(title: "Import Note(s)/Image(s)...", image: UIImage(systemName: "doc"),  didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            self.displayDocumentPicker()
        })
        popMenu.addAction(noteImportAction)
        let scanAction = PopMenuDefaultAction(title: "Scan Document(s)...", image: UIImage(systemName: "camera.viewfinder"),  didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            self.showDocumentScanner()
        })
        popMenu.addAction(scanAction)
        let imageImportAction = PopMenuDefaultAction(title: "Camera Roll...", image: UIImage(systemName: "photo"),  didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            self.displayImagePicker()
        })
        popMenu.addAction(imageImportAction)
        self.present(popMenu, animated: true, completion: nil)
    }
    
    private func showDocumentScanner() {
        let scannerVC = VNDocumentCameraViewController()
        scannerVC.delegate = self
        present(scannerVC, animated: true)
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true, completion: nil)
        
        var images = [UIImage]()
        for i in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: i)
            images.append(image)
        }
        let newNote = self.createNoteFromImages(images: images)
        _ = SKFileManager.add(note: newNote)
        log.info("New note from scanned images.")
        self.updateDisplayedNotes(true)
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        log.error(error)
        controller.dismiss(animated: true, completion: nil)
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
        
        switch SettingsManager.getFileSorting() {
            
        case .ByNewest:
            self.items = self.items.sorted(by: { (file0: File, file1: File) -> Bool in
                return file0 > file1
            })
        case .ByOldest:
            self.items = self.items.sorted()
        case .ByNameAZ:
            self.items = self.items.sorted(by: { (file0: File, file1: File) -> Bool in
                return file0.getName() < file1.getName()
            })
        case .ByNameZA:
            self.items = self.items.sorted(by: { (file0: File, file1: File) -> Bool in
                return file0.getName() > file1.getName()
            })
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
    
    private func updateFoldersHierarchy() {
        for button in folderButtons {
            button.removeFromSuperview()
        }
        folderButtons = [FolderButton]()
        let homeButton = FolderButton()
        homeButton.frame = CGRect(x: 0, y: 0, width: 100, height: 35)
        homeButton.setFolder(folder: nil)
        homeButton.delegate = self
        navigationHierarchyStackView.addArrangedSubview(homeButton)
        folderButtons.append(homeButton)
        for f in SKFileManager.currentFoldersHierarchy {
            let folderButton = FolderButton()
            folderButton.frame = CGRect(x: 0, y: 0, width: 100, height: 35)
            folderButton.setFolder(folder: f)
            folderButton.delegate = self
            navigationHierarchyStackView.addArrangedSubview(folderButton)
            folderButtons.append(folderButton)
        }
        spacerView.removeFromSuperview()
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        navigationHierarchyStackView.addArrangedSubview(spacerView)
    }
    
    func onTap(folder: Folder?) {
        if SKFileManager.currentFolder != folder {
            SKFileManager.setCurrentFolder(folder: folder)
            self.updateDisplayedNotes(false)
            self.updateFoldersHierarchy()
        }
    }
    
    @IBAction func noteListViewButtonTapped(_ sender: UIButton) {
        switch self.noteCollectionViewState {
        case .Grid:
            self.noteCollectionViewState = .List
            SettingsManager.setFileDisplayLayout(type: .List)
            sender.backgroundColor = self.view.tintColor
            sender.tintColor = .black
        case .List:
            self.noteCollectionViewState = .Grid
            SettingsManager.setFileDisplayLayout(type: .Grid)
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
        var nameAZFirstImage: UIImage? = nil
        var nameZAFirstImage: UIImage? = nil
        switch SettingsManager.getFileSorting() {
        case .ByNewest:
            newestFirstImage = UIImage(systemName: "checkmark.circle.fill")
        case .ByOldest:
            oldestFirstImage = UIImage(systemName: "checkmark.circle.fill")
        case .ByNameAZ:
            nameAZFirstImage = UIImage(systemName: "checkmark.circle.fill")
        case .ByNameZA:
            nameZAFirstImage = UIImage(systemName: "checkmark.circle.fill")
        }
        let newestFirstAction = PopMenuDefaultAction(title: "Newest First", image: newestFirstImage,  didSelect: { action in
            SettingsManager.setFileSorting(type: .ByNewest)
            self.updateDisplayedNotes(false)
            
        })
        popMenu.addAction(newestFirstAction)
        let oldestFirstAction = PopMenuDefaultAction(title: "Oldest First", image: oldestFirstImage, didSelect: { action in
            SettingsManager.setFileSorting(type: .ByOldest)
            self.updateDisplayedNotes(false)
        })
        popMenu.addAction(oldestFirstAction)
        let nameAZAction = PopMenuDefaultAction(title: "Alphabetically (A-Z)", image: nameAZFirstImage, didSelect: { action in
            SettingsManager.setFileSorting(type: .ByNameAZ)
            self.updateDisplayedNotes(false)
        })
        popMenu.addAction(nameAZAction)
        let nameZAAction = PopMenuDefaultAction(title: "Alphabetically (Z-A)", image: nameZAFirstImage, didSelect: { action in
            SettingsManager.setFileSorting(type: .ByNameZA)
            self.updateDisplayedNotes(false)
        })
        popMenu.addAction(nameZAAction)
        
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
        let renameAction = UIAction(title: "Rename...", image: UIImage(systemName: "text.cursor")) { action in
            self.renameFile(file: file)
        }
        menuElements.append(renameAction)
        if let note = file as? NoteX {
            let tagsAction = UIAction(title: "Manage Tags...", image: UIImage(systemName: "tag.fill")) { action in
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
            let sendAction = UIAction(title: "Send...", image: UIImage(systemName: "paperplane")) { action in
                self.sendNote(note: note)
            }
            menuElements.append(sendAction)
        }
        let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "xmark.circle.fill"), attributes: .destructive) { action in
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
    
    private var noteCollectionViewState = SettingsManager.getFileDisplayLayout()
    
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
        case .List:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierDetailCell, for: indexPath as IndexPath) as! NoteCollectionViewDetailCell
            cell.setFile(file: self.items[indexPath.item])
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        switch self.noteCollectionViewState {
        case .Grid:
            return CGSize(width: CGFloat(200), height: CGFloat(300))
        case .List:
            return CGSize(width: collectionView.bounds.size.width - CGFloat(10), height: CGFloat(60))
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
        SKFileManager.setCurrentFolder(folder: folder)
        self.updateDisplayedNotes(false)
        self.updateFoldersHierarchy()
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
    func importNote(url: URL) {
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
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = self.items[indexPath.row]
        let itemProvider = NSItemProvider(object: item.getName() as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        canHandle session: UIDropSession) -> Bool {
      return true
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath else {
          return
        }
        coordinator.items.forEach { dropItem in
          guard let sourceIndexPath = dropItem.sourceIndexPath else {
            return
          }
          collectionView.performBatchUpdates({
            let sourceFile = self.items[sourceIndexPath.item]
            
            if let folderDestination = self.items[destinationIndexPath.item] as? Folder {
                log.info("Moving file to folder.")
                SKFileManager.move(file: sourceFile, toFolder: folderDestination)
                self.updateDisplayedNotes(false)
            }
          }, completion: nil)
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
    }
}
