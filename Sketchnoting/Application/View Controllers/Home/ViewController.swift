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
import DataCompression
import ViewAnimator
import BSImagePicker
import Toast

import MultipeerConnectivity
import Vision
import PencilKit
import MobileCoreServices
import VisionKit
import Photos

class ViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIApplicationDelegate, UIPopoverPresentationControllerDelegate, UIDocumentPickerDelegate, VNDocumentCameraViewControllerDelegate, UICollectionViewDragDelegate, UICollectionViewDropDelegate, FolderButtonDelegate, RelatedNotesVCDelegate, MoveFileViewControllerDelegate, SKClipboardDelegate {
    
    @IBOutlet weak var navigationHierarchyScrollView: UIScrollView!
    @IBOutlet weak var navigationHierarchyStackView: UIStackView!
    private var folderButtons = [FolderButton]()
    private var spacerView = UIView()
    
    private var selectedNoteForTagEditing: (URL, Note)?
    
    @IBOutlet var newNoteButton: UIButton!
    @IBOutlet var noteLoadingIndicator: NVActivityIndicatorView!
    
    @IBOutlet var noteListViewButton: UIButton!
    @IBOutlet weak var filtersButton: UIButton!
    @IBOutlet weak var receivedNotesButton: UIButton!
    var receivedNotesBadge: BadgeHub!
    
    @IBOutlet var noteSortingButton: UIButton!
    
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
    var sketchnoteToShare: (URL, Note)?
    // The two above variables are added to this following array and this array is sent to the receiving device(s)
    var dataToShare = [Data]()
    
    //
    var noteToEdit: (URL, Note)?
    
    @IBOutlet weak var selectionModeButton: UIButton!
    @IBOutlet weak var selectAllButton: UIButton!
    @IBOutlet weak var deselectAllButton: UIButton!
    @IBOutlet weak var moveSelectedButton: UIButton!
    @IBOutlet weak var deleteSelectedButton: UIButton!
    @IBOutlet weak var selectionControlsView: UIView!
    // This function initializes the home page view.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.tabBarController?.tabBar.isHidden = false
        
        ToastManager.shared.isTapToDismissEnabled = true
        
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
        
        SKClipboard.delegate = self
        SKClipboard.addClipboardButton(view: self.view)
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
        if NeoLibrary.receivedNotesController.mcAdvertiserAssistant != nil {
            receivedNotesButton.tintColor = UIColor.systemBlue
        }
        else {
            receivedNotesButton.tintColor = UIColor.systemGray
        }
        receivedNotesBadge.setCount(NeoLibrary.receivedNotesController.receivedNotes.count)
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
            if let destination = segue.destination as? NoteViewController {
                destination.note = noteToEdit
            }
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
        case "showRelatedHomePage":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? RelatedNotesViewController {
                    if let n = noteForRelatedNotes {
                        destinationViewController.delegate = self
                        destinationViewController.note = n
                        destinationViewController.context = .HomePage
                    }
                }
            }
            break
        case "MoveFileHome":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? MoveFileViewController {
                    destinationViewController.delegate = self
                    destinationViewController.filesToMove = self.filesToMove
                }
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
            if let noteToOpen = vc.openNote {
                if let segue = sender as? UIStoryboardSegueWithCompletion {
                    segue.completion = {
                        self.open(url: noteToOpen.0, note: noteToOpen.1)
                    }
                }
            }
            self.updateDisplayedNotes(false)
            SKClipboard.delegate = self
            SKClipboard.addClipboardButton(view: self.view)
        }
        self.tabBarController?.tabBar.isHidden = false
    }
    
    private func manageFileImport(urls: [URL]) {
        if urls.count > 0 {
            let (importedNotes, importedImages, importedPDFs, importedTexts) = ImportHelper.importItems(urls: urls)
            for note in importedNotes {
                NeoLibrary.add(note: note.1)
                log.info("Imported note \(note.1.getName()).")
            }
            if importedImages.count > 0 {
                _ = NeoLibrary.createNoteFromImages(images: importedImages)
                log.info("New note from imported images.")
            }
            if importedTexts.count > 0 {
                _ = NeoLibrary.createNoteFromTypedTexts(texts: importedTexts)
                log.info("New note from imported text files.")
            }
            for pdf in importedPDFs {
                if pdf.pageCount > 0 {
                    _ = NeoLibrary.createNoteFromPDF(pdf: pdf)
                    log.info("New note from imported pdf.")
                }
            }
            self.view.makeToast("Imported your selected documents.")
            self.updateDisplayedNotes(true)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.manageFileImport(urls: urls)
    }
    
    private func displayDocumentPicker() {
        let types: [String] = ImportHelper.importUTTypes
        let documentPicker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .pageSheet
        documentPicker.allowsMultipleSelection = true
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    private func displayImagePicker() {
        ImagePickerHelper.displayImagePickerWithImageOutput(vc: self, completion: { images in
            if images.count > 0 {
                _ = NeoLibrary.createNoteFromImages(images: images)
                log.info("New note from imported images (camera roll).")
                self.updateDisplayedNotes(true)
            }
        })
    }
    
    @IBAction func importDocumentTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .none()
        let noteImportAction = PopMenuDefaultAction(title: "Import Files", image: UIImage(systemName: "doc"),  didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            self.displayDocumentPicker()
        })
        popMenu.addAction(noteImportAction)
        let scanAction = PopMenuDefaultAction(title: "Scan Documents", image: UIImage(systemName: "camera.viewfinder"),  didSelect: { action in
            popMenu.dismiss(animated: true, completion: nil)
            self.showDocumentScanner()
        })
        popMenu.addAction(scanAction)
        let imageImportAction = PopMenuDefaultAction(title: "Camera Roll", image: UIImage(systemName: "photo"),  didSelect: { action in
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
        _ = NeoLibrary.createNoteFromImages(images: images)
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
        self.items = NeoLibrary.getFiles()
        
        if TagsManager.filterTags.count > 0 {
            var filteredItems = [(URL, File)]()
            for item in self.items {
                if let note = item.1 as? Note {
                    for tag in TagsManager.filterTags {
                        if note.tags.contains(tag) {
                            filteredItems.append(item)
                            break
                        }
                    }
                }
                else { // Folder
                }
            }
            self.items = filteredItems
        }
        
        switch SettingsManager.getFileSorting() {
            
        case .ByNewest:
            self.items = self.items.sorted(by: { (item0: (URL, File), item1: (URL, File)) -> Bool in
                if NeoLibrary.getCreationDate(url: item0.0) > NeoLibrary.getCreationDate(url: item1.0) {
                    return true
                }
                return false
            })
        case .ByOldest:
            self.items = self.items.sorted(by: { (item0: (URL, File), item1: (URL, File)) -> Bool in
                if NeoLibrary.getCreationDate(url: item0.0) < NeoLibrary.getCreationDate(url: item1.0) {
                    return true
                }
                return false
            })
        case .ByNameAZ:
            self.items = self.items.sorted(by: { (item0: (URL, File), item1: (URL, File)) -> Bool in
                return item0.1.getName() < item1.1.getName()
            })
        case .ByNameZA:
            self.items = self.items.sorted(by: { (item0: (URL, File), item1: (URL, File)) -> Bool in
                return item0.1.getName() > item1.1.getName()
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
        log.info("Updating folder navigation hierarchy.")
        for button in folderButtons {
            button.removeFromSuperview()
        }
        folderButtons = [FolderButton]()
        var component = NeoLibrary.currentLocation
        var limit = 0
        while !NeoLibrary.isHomeDirectory(url: component) && component != NeoLibrary.getHomeDirectoryURL() {
            log.info(component)
            let folderButton = FolderButton()
            folderButton.frame = CGRect(x: 0, y: 0, width: 100, height: 35)
            folderButton.set(directoryURL: component)
            folderButton.delegate = self
            limit += 1
            if limit >= 20 {
                break
            }
            folderButtons.append(folderButton)
            component = component.deletingLastPathComponent()
        }
        let folderButton = FolderButton()
        folderButton.frame = CGRect(x: 0, y: 0, width: 100, height: 35)
        folderButton.set(directoryURL: component)
        folderButton.delegate = self
        folderButtons.append(folderButton)
        for button in folderButtons.reversed() {
            navigationHierarchyStackView.addArrangedSubview(button)
        }
        spacerView.removeFromSuperview()
        spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        navigationHierarchyStackView.addArrangedSubview(spacerView)
    }
    
    func onTap(directoryURL: URL) {
        if NeoLibrary.currentLocation != directoryURL {
            NeoLibrary.currentLocation = directoryURL
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
        self.noteToEdit = NeoLibrary.createNote(name: "Untitled")
        performSegue(withIdentifier: "EditSketchnote", sender: self)
    }
    @IBAction func newFolderButtonTapped(_ sender: UIButton) {
        self.showInputDialog(title: "New Folder", subtitle: nil, actionTitle: "Create", cancelTitle: "Cancel", inputPlaceholder: "Folder Name...", inputKeyboardType: .default, cancelHandler: nil)
        { (input:String?) in
            var name = "Untitled"
            if let input = input {
                if !input.isEmpty {
                    name = input
                }
            }
            _ = NeoLibrary.createFolder(name: name)
            self.updateDisplayedNotes(false)
        }
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

            return self.makeFileContextMenu(url: self.items[indexPath.row].0, file: self.items[indexPath.row].1, point: point, cellIndexPath: indexPath)
        })
    }
    
    var shareNoteObject: (URL, Note)?
    private func makeFileContextMenu(url: URL, file: File, point: CGPoint, cellIndexPath: IndexPath) -> UIMenu {
        // To rework
        var menuElements = [UIMenuElement]()
        let renameAction = UIAction(title: "Rename...", image: UIImage(systemName: "text.cursor")) { action in
            self.renameFile(url: url, file: file, indexPath: cellIndexPath)
        }
        menuElements.append(renameAction)
        let moveAction = UIAction(title: "Move...", image: UIImage(systemName: "folder")) { action in
            self.moveFile(url: url, file: file)
        }
        menuElements.append(moveAction)
        if let note = file as? Note {
            let tagsAction = UIAction(title: "Manage Tags...", image: UIImage(systemName: "tag.fill")) { action in
                self.editNoteTags(url: url, note: note, cell: self.noteCollectionView.cellForItem(at: cellIndexPath))
            }
            menuElements.append(tagsAction)
            let similarNotesAction = UIAction(title: "Related Notes...", image: UIImage(systemName: "link")) { action in
                self.showRelatedNotesFor(url: url, note: note)
                self.view.makeToast("Showing related notes.", title: note.getName())
            }
            menuElements.append(similarNotesAction)
            let duplicateAction = UIAction(title: "Duplicate", image: UIImage(systemName: "doc.on.doc")) { action in
                _ = NeoLibrary.createDuplicate(note: note, url: url)
                self.updateDisplayedNotes(false)
            }
            menuElements.append(duplicateAction)
            let copyNoteAction = UIAction(title: "Copy Note", image: UIImage(systemName: "doc.on.clipboard")) { action in
                SKClipboard.copy(note: note)
                SKClipboard.addClipboardButton(view: self.view)
                self.view.makeToast("Copied note to SKClipboard.")
            }
            menuElements.append(copyNoteAction)
            let copyTextAction = UIAction(title: "Copy Text", image: UIImage(systemName: "text.quote")) { action in
                UIPasteboard.general.string = note.getText()
                self.view.makeToast("Copied text to Clipboard.")
            }
            menuElements.append(copyTextAction)
            let shareAction = UIAction(title: "Share...", image: UIImage(systemName: "square.and.arrow.up")) { action in
                self.shareNoteObject = (url, note)
                self.shareNote(url: url, note: note, sender: UIView(frame: CGRect(x: point.x, y: point.y, width: point.x, height: point.y)))
            }
            menuElements.append(shareAction)
            let sendAction = UIAction(title: "Send...", image: UIImage(systemName: "paperplane")) { action in
                self.sendNote(url: url, note: note)
            }
            menuElements.append(sendAction)
        }
        let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "xmark.circle.fill"), attributes: .destructive) { action in
            self.deleteFile(url: url, file: file)
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
            self.sendNoteInternal(url: sketchnoteToShare!.0, note: sketchnoteToShare!.1)
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
    
    private func sendNoteInternal(url: URL, note: Note) {
        if mcSession.connectedPeers.count > 0 {
            if let noteData = note.encodeFileAsData() {
                do {
                    try mcSession.send(noteData, toPeers: mcSession.connectedPeers, with: .reliable)
                } catch let error as NSError {
                    let ac = UIAlertController(title: "Could not send the note", message: error.localizedDescription, preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "Close", style: .default))
                    present(ac, animated: true)
                }
                self.view.makeToast("Note shared with the selected device(s).", title: note.getName())
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
        self.present(mcBrowser, animated: true)
        log.info("Joining sessions...")
    }
    
    private var noteCollectionViewState = SettingsManager.getFileDisplayLayout()
    
    @IBOutlet weak var noteCollectionView: UICollectionView!
    let reuseIdentifier = "NoteCollectionViewCell" // also enter this string as the cell identifier in the storyboard
    let reuseIdentifierDetailCell = "NoteCollectionViewDetailCell"
    var items = [(URL, File)]()
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch self.noteCollectionViewState {
        case .Grid:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath as IndexPath) as! NoteCollectionViewCell
            cell.setFile(url: self.items[indexPath.item].0, file: self.items[indexPath.item].1, isInSelectionMode: self.isSelectionModeActive, isFileSelected: self.selectedFiles[self.items[indexPath.item].0] != nil)
            return cell
        case .List:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierDetailCell, for: indexPath as IndexPath) as! NoteCollectionViewDetailCell
            cell.setFile(url: self.items[indexPath.item].0, file: self.items[indexPath.item].1, isInSelectionMode: self.isSelectionModeActive, isFileSelected: self.selectedFiles[self.items[indexPath.item].0] != nil)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        switch self.noteCollectionViewState {
        case .Grid:
            return CGSize(width: CGFloat(175), height: CGFloat(275))
        case .List:
            return CGSize(width: collectionView.bounds.size.width - CGFloat(10), height: CGFloat(100))
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = self.items[indexPath.item]
        if self.isSelectionModeActive {
            if self.selectedFiles[item.0] != nil {
                self.selectedFiles[item.0] = nil
            }
            else {
                self.selectedFiles[item.0] = item.1
            }
            collectionView.performBatchUpdates({
                collectionView.reloadItems(at: [indexPath])
            })
        }
        else {
            if let note = item.1 as? Note {
                self.open(url: item.0, note: note)
            }
            else {
                self.open(url: item.0, folder: item.1)
            }
        }
    }
    
    public func open(url: URL, note: Note) {
        self.noteToEdit = (url, note)
        self.performSegue(withIdentifier: "EditSketchnote", sender: self)
        log.info("Opening note.")
    }
    
    private func open(url: URL, folder: File) {
        NeoLibrary.currentLocation = url
        self.updateDisplayedNotes(false)
        self.updateFoldersHierarchy()
        log.info("Opening folder.")
    }
    
    private func renameFile(url: URL, file: File, indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Rename file", message: nil, preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: "Set", style: .default) { (_) in
            
            let name = alertController.textFields?[0].text
            file.setName(name: name ?? "Untitled")
            let newURL = NeoLibrary.rename(url: url, file: file, name: name ?? "Untitled")
            if newURL == nil {
                self.view.makeToast("File could not be renamed.")
            }
            self.noteCollectionView.performBatchUpdates({
                self.noteCollectionView.reloadItems(at: [indexPath])
            })
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
    
    var noteForRelatedNotes: (URL, Note)?
    private func showRelatedNotesFor(url: URL, note: Note) {
        self.noteForRelatedNotes = (url, note)
        self.performSegue(withIdentifier: "showRelatedHomePage", sender: self)
    }
    
    var filesToMove = [(URL, File)]()
    private func moveFile(url: URL, file: File) {
        self.filesToMove = [(URL, File)]()
        self.filesToMove.append((url, file))
        self.performSegue(withIdentifier: "MoveFileHome", sender: self)
        
    }
    // MoveFileViewControllerDelegate
    func movedFiles(items: [(URL, File)]) {
        self.updateDisplayedNotes(true)
    }
    // Related Notes VC delegate
    func openRelatedNote(url: URL, note: Note) {
        self.open(url: url, note: note)
    }
    func mergedNotes(note1: Note, note2: Note) {
    }
    
    var selectedCellForTagEditing: UICollectionViewCell?
    private func editNoteTags(url: URL, note: Note, cell: UICollectionViewCell?) {
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
            NeoLibrary.save(note: note, url: url)
        }
        self.selectedNoteForTagEditing = (url, note)
        self.selectedCellForTagEditing = cell
        self.performSegue(withIdentifier: "EditNoteTags", sender: self)
       }

    private func shareNote(url: URL, note: Note, sender: UIView) {
        self.performSegue(withIdentifier: "ShareNote", sender: sender)
    }
    
    func importNote(url: URL) {
        NeoLibrary.importNote(url: url)
        self.view.makeToast("Note imported.")
    }
    
    private func sendNote(url: URL, note: Note) {
        self.sketchnoteToShare = (url, note)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.joinSession()
        }
    }
    
    private func deleteFile(url: URL, file: File) {
        let alert = UIAlertController(title: "Delete File", message: "Are you sure you want to delete this file?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
            self.items.removeAll{$0.0 == url}
            NeoLibrary.delete(url: url)
            self.noteCollectionView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
              log.info("Not deleting file.")
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = self.items[indexPath.row]
        let itemProvider = NSItemProvider(object: item.1.getName() as NSString)
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
            let destinationItem = self.items[destinationIndexPath.item]
            if !(destinationItem.1 is Note) { // Folder
                log.info("Moving file to folder.")
                _ = NeoLibrary.move(file: sourceFile.1, from: sourceFile.0, to: destinationItem.0)
                self.updateDisplayedNotes(false)
            }
          }, completion: nil)
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        return UICollectionViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
    }
    
    // Selection
    private var isSelectionModeActive = false
    private var selectedFiles = [URL : File]()
    @IBAction func selectionModeButtonTapped(_ sender: UIButton) {
        if self.isSelectionModeActive {
            selectionModeButton.setImage(UIImage(systemName: "checkmark.square"), for: .normal)
            self.selectedFiles = [URL : File]()
        }
        else {
            selectionModeButton.setImage(UIImage(systemName: "checkmark.square.fill"), for: .normal)
        }
        self.isSelectionModeActive = !self.isSelectionModeActive
        selectionControlsView.isHidden = !self.isSelectionModeActive
        self.updateDisplayedNotes(false)
    }
    @IBAction func selectAllButtonTapped(_ sender: UIButton) {
        for item in self.items {
            self.selectedFiles[item.0] = item.1
        }
        self.updateDisplayedNotes(false)
    }
    @IBAction func deselectAllButtonTapped(_ sender: UIButton) {
        self.selectedFiles = [URL : File]()
        self.updateDisplayedNotes(false)
    }
    @IBAction func moveSelectedButtonTapped(_ sender: UIButton) {
        if !self.selectedFiles.isEmpty {
            self.filesToMove = selectedFiles.map {($0, $1)} // Convert dictionary to array of tuples
            self.performSegue(withIdentifier: "MoveFileHome", sender: self)
        }
    }
    @IBAction func deleteSelectedButtonTapped(_ sender: UIButton) {
        if !self.selectedFiles.isEmpty {
            let alert = UIAlertController(title: "Delete \(self.selectedFiles.count) File(s)", message: "Are you sure you want to delete the selected files?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                for (url, _) in self.selectedFiles {
                    NeoLibrary.delete(url: url)
                    self.updateDisplayedNotes(false)
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
                  log.info("Not deleting selected files.")
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: SKClipboardDelegate (to update)
    func pasteNoteTapped() {
        log.info("Pasting note: \(SKClipboard.getNote()?.getName() ?? "Note name could not be retrieved.")")
        if let n = SKClipboard.getNote() {
            NeoLibrary.add(note: n)
            self.updateDisplayedNotes(true)
            self.view.makeToast("Pasted note: \(n.getName())")
        }
    }
    func pastePageTapped() {
        log.info("Pasting note page.")
        if let p = SKClipboard.getPage() {
            let newNote = Note(name: "Note Page Copy", documents: nil)
            newNote.pages = [p]
            NeoLibrary.add(note: newNote)
            self.updateDisplayedNotes(true)
            self.view.makeToast("Created new note \"Note Page Copy\" from pasted page.")
        }
        
    }
    func pasteImageTapped() {
        log.info("Pasting note image.")
        if let i = SKClipboard.getImage() {
            _ = NeoLibrary.createNoteFromImages(images: [i.image])
            self.updateDisplayedNotes(true)
            self.view.makeToast("Created new note \"Note Image Copy\" from pasted note image.")
        }
    }
    func pasteTypedTextTapped() {
        log.info("Pasting note typed text.")
        if let t = SKClipboard.getTypedText() {
            _ = NeoLibrary.createNoteFromTypedTexts(texts: [t])
            self.updateDisplayedNotes(true)
            self.view.makeToast("Created new note \"Note Typed Text Copy\" from pasted note typed text.")
        }
    }
    func clearClipboardTapped() {
        self.view.makeToast("Cleared SKClipboard.")
    }
    
}
