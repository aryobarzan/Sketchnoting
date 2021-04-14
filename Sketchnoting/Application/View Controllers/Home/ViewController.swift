//
//  ViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 22/02/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

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

class ViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate, MCSessionDelegate, MCBrowserViewControllerDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIApplicationDelegate, UIPopoverPresentationControllerDelegate, UIDocumentPickerDelegate, VNDocumentCameraViewControllerDelegate, UICollectionViewDragDelegate, UICollectionViewDropDelegate, FolderButtonDelegate, RelatedNotesVCDelegate, MoveFileViewControllerDelegate {
    
    @IBOutlet weak var navigationHierarchyScrollView: UIScrollView!
    @IBOutlet weak var navigationHierarchyStackView: UIStackView!
    private var folderButtons = [FolderButton]()
    private var spacerView = UIView()
    
    private var selectedNoteForTagEditing: (URL, Note)?
    
    private var selectedFiles = [URL : File]()
    private var isMultipleSelectionActive: Bool = false {
        didSet {
            noteCollectionView.allowsMultipleSelection = isMultipleSelectionActive
            noteCollectionView.selectItem(at: nil, animated: true, scrollPosition: [])
            selectedFiles.removeAll()
            selectionControlsView.isHidden = !self.isMultipleSelectionActive
        }
    }
    
    @IBOutlet var newNoteButton: UIButton!
    @IBOutlet var noteLoadingIndicator: NVActivityIndicatorView!
    @IBOutlet weak var clipboardButton: UIButton!
    
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
    
    //
    var filesToExport = [(URL, File)]()
    
    let noteCollectionViewCellIdentifier = "NoteCollectionViewCell"
    let folderCollectionViewCellIdentifier = "FolderCollectionViewCell"
    let noteCollectionViewDetailCellIdentifier = "NoteCollectionViewDetailCell"
    
    let tagsManager = TagsManager()
    
    @IBOutlet weak var selectionModeButton: UIButton!
    @IBOutlet weak var selectAllButton: UIButton!
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
        
        noteCollectionView.register(UINib(nibName: noteCollectionViewCellIdentifier, bundle: nil), forCellWithReuseIdentifier: noteCollectionViewCellIdentifier)
        noteCollectionView.register(UINib(nibName: folderCollectionViewCellIdentifier, bundle: nil), forCellWithReuseIdentifier: folderCollectionViewCellIdentifier)
        noteCollectionView.register(UINib(nibName: noteCollectionViewDetailCellIdentifier, bundle: nil), forCellWithReuseIdentifier: noteCollectionViewDetailCellIdentifier)
        noteCollectionView.dragDelegate = self
        noteCollectionView.dropDelegate = self
        noteCollectionView.dragInteractionEnabled = true

        self.noteLoadingIndicator.isHidden = false
        self.noteLoadingIndicator.startAnimating()
        self.newNoteButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.updateDisplayedNotes(true)
            self.updateFoldersHierarchy()
            logger.info("User Library loaded.")
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
        self.updateClipboardButton()
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
        tagsManager.reload()
        self.updateDisplayedNotes(false)
        self.selectedNoteForTagEditing = nil
        activeFiltersBadge.setCount(TagsManager.filterTags.count)
    }
    
    // Respond to NotificationCenter events
    @objc func notifiedFileImport(_ noti : Notification)  {
        let importURL = (noti.userInfo as? [String : URL])!["importURL"]!
        logger.info(importURL)
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
            logger.info("New note.")
            break
        case "EditSketchnote":
            logger.info("Editing note.")
            if let destination = segue.destination as? NoteViewController {
                destination.note = noteToEdit
            }
            break
        case "NoteSharing":
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            break
        case "Export":
            if let destination = segue.destination as? UINavigationController {
                if let destinationViewController = destination.topViewController as? ExportViewController {
                    destinationViewController.files = filesToExport
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
            logger.info("Unaccounted-for segue.")
        }
    }
    
    @IBAction func unwindToHome(sender: UIStoryboardSegue) {
        if sender.source is NoteViewController {
            let vc = sender.source as! NoteViewController
            if let noteToOpen = vc.openNote {
                if let segue = sender as? UIStoryboardSegueWithCompletion {
                    segue.completion = {
                        self.open(url: noteToOpen.0, file: noteToOpen.1)
                    }
                }
            }
            self.updateDisplayedNotes(false)
            self.updateClipboardButton()
        }
        self.tabBarController?.tabBar.isHidden = false
    }
    
    private func updateClipboardButton() {
        if SKClipboard.hasItems() {
            clipboardButton.isHidden = false
        }
        else {
            clipboardButton.isHidden = true
        }
    }
    
    private func manageFileImport(urls: [URL]) {
        if urls.count > 0 {
            var cancelled = false
            self.displayLoadingAlert(title: "Loading", subtitle: "Importing \(Int(urls.count)) selected file(s)...") {
                // Cancelled by user
                logger.info("File import cancelled by user.")
                ImportHelper.cancelImports()
                cancelled = true
            }
            ImportHelper.importItems(urls: urls) { importedNotes, importedImages, importedPDFs, importedTexts in
                if !cancelled {
                    // PDFs, images and text files are first converted to Note objects
                    var createdNotes = [(URL, Note)]()
                    if importedImages.count > 0 {
                        let (url, note) = NeoLibrary.createNoteFrom(images: importedImages)
                        createdNotes.append((url, note))
                        logger.info("New note from imported images.")
                    }
                    if importedTexts.count > 0 {
                        let (url, note) = NeoLibrary.createNoteFrom(typedTexts: importedTexts)
                        createdNotes.append((url, note))
                        logger.info("New note from imported text files.")
                    }
                    for pdf in importedPDFs {
                        if pdf.pageCount > 0 {
                            let (url, note) = NeoLibrary.createNoteFrom(pdf: pdf)
                            createdNotes.append((url, note))
                            if cancelled {
                                break
                            }
                            logger.info("New note from imported pdf.")
                        }
                    }
                    DispatchQueue.main.async {
                        if !cancelled {
                            self.dismissLoadingAlert()
                            self.showImportVC(importedNotes: createdNotes + importedNotes)
                        }
                    }
                }
            }
        }
    }
    
    private func showImportVC(importedNotes: [(URL, Note)]) {
        if let importVC = self.storyboard?.instantiateViewController(withIdentifier: "ImportViewController") as? ImportViewController {
            importVC.modalPresentationStyle = .pageSheet
            importVC.items = importedNotes
            importVC.importCompletion = { didImport in
                if didImport {
                    self.view.makeToast("Imported your selected documents.")
                    self.updateDisplayedNotes(true)
                }
            }
            
            let navigationController = UINavigationController(rootViewController: importVC)
            navigationController.modalPresentationStyle = .pageSheet
            present(navigationController, animated: true, completion: nil)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.manageFileImport(urls: urls)
    }
    
    private func displayDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: ImportHelper.importUTTypes, asCopy: true)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .pageSheet
        documentPicker.allowsMultipleSelection = true
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    private func displayImagePicker() {
        ImagePickerHelper.displayImagePickerWithImageOutput(vc: self, completion: { images in
            if images.count > 0 {
                let (url, note) = NeoLibrary.createNoteFrom(images: images)
                NeoLibrary.saveSynchronously(note: note, url: url)
                logger.info("New note from imported images (camera roll).")
                self.updateDisplayedNotes(true)
            }
        })
    }
    
    @IBAction func importDocumentTapped(_ sender: UIButton) {
        let filesImportAction = UIAlertAction(title: "Import Files", style: .default) { action in
            self.displayDocumentPicker()
        }
        let scanDocumentsAction = UIAlertAction(title: "Scan Documents", style: .default) { action in
            self.showDocumentScanner()
        }
        let cameraRollAction = UIAlertAction(title: "Camera Roll", style: .default) { action in
            self.displayImagePicker()
        }
        let alert = UIAlertController(title: "Import", message: "Import files, scan physical documents using your camera or choose photos from your camera roll.", preferredStyle: .actionSheet)
        alert.addAction(filesImportAction)
        alert.addAction(scanDocumentsAction)
        alert.addAction(cameraRollAction)
        alert.popoverPresentationController?.sourceView = sender
        self.present(alert, animated: true)
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
        let (url, note) = NeoLibrary.createNoteFrom(images: images)
        NeoLibrary.saveSynchronously(note: note, url: url)
        logger.info("New note from scanned images.")
        self.updateDisplayedNotes(true)
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        logger.error(error)
        controller.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Note display management
    private func updateDisplayedNotes(_ animated: Bool) {
        self.items = Array(repeating: [], count: 2)
        var files = NeoLibrary.getFiles()
        
        if TagsManager.filterTags.count > 0 {
            var filteredItems = [(URL, File)]()
            for item in files {
                if let note = item.1 as? Note {
                    let noteTags = tagsManager.getTags(for: note)
                    for tag in TagsManager.filterTags {
                        if noteTags.contains(tag) {
                            filteredItems.append(item)
                            break
                        }
                    }
                }
                else { // Folder
                }
            }
            files = filteredItems
        }
        
        switch SettingsManager.getFileSorting() {
        case .ByNewest:
            files = files.sorted(by: { (item0: (URL, File), item1: (URL, File)) -> Bool in
                if NeoLibrary.getCreationDate(url: item0.0) > NeoLibrary.getCreationDate(url: item1.0) {
                    return true
                }
                return false
            })
        case .ByOldest:
            files = files.sorted(by: { (item0: (URL, File), item1: (URL, File)) -> Bool in
                if NeoLibrary.getCreationDate(url: item0.0) < NeoLibrary.getCreationDate(url: item1.0) {
                    return true
                }
                return false
            })
        case .ByNameAZ:
            files = files.sorted(by: { (item0: (URL, File), item1: (URL, File)) -> Bool in
                return item0.1.getName() < item1.1.getName()
            })
        case .ByNameZA:
            files = files.sorted(by: { (item0: (URL, File), item1: (URL, File)) -> Bool in
                return item0.1.getName() > item1.1.getName()
            })
        }
        let folders = files.filter{!($0.1 is Note)}
        let notes = files.filter{$0.1 is Note}
        self.items = [folders, notes]
        noteCollectionView.reloadData()
        if animated {
            let animations = [AnimationType.vector(CGVector(dx: 200, dy: 0))]
            noteCollectionView.performBatchUpdates({
                UIView.animate(views: noteCollectionView.orderedVisibleCells,
                animations: animations, completion: {
                })
            })
        }
        
        updateSelectAllButton()
    }
    
    private func updateFoldersHierarchy() {
        for button in folderButtons {
            button.removeFromSuperview()
        }
        folderButtons = [FolderButton]()
        var component = NeoLibrary.currentLocation
        var limit = 0
        while !NeoLibrary.isHomeDirectory(url: component) && component != NeoLibrary.getHomeDirectoryURL() {
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
        
        let animations = [AnimationType.vector(CGVector(dx: 200, dy: 0))]
        noteCollectionView.performBatchUpdates({
            UIView.animate(views: noteCollectionView.orderedVisibleCells,
            animations: animations, completion: {
            })
        })
    }

    @IBAction func newNoteButtonTapped(_ sender: UIButton) {
        let (newURL, newNote) = NeoLibrary.createNote(name: "Untitled")
        NeoLibrary.saveSynchronously(note: newNote, url: newURL)
        self.noteToEdit = (newURL, newNote)
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
    @IBAction func clipboardButtonTapped(_ sender: UIButton) {
        if SKClipboard.hasItems() {
            let alert = UIAlertController(title: "Clipboard", message: "Paste a copied note, page, image or typed text.", preferredStyle: .actionSheet)
            alert.popoverPresentationController?.sourceView = sender
            if let copiedNote = SKClipboard.getNote() {
                let pasteNoteAction = UIAlertAction(title: "Paste Note", style: .default) { action in
                    NeoLibrary.add(note: copiedNote)
                    self.updateDisplayedNotes(true)
                    self.view.makeToast("Pasted note: \(copiedNote.getName())", duration: 2, position: .center)
                }
                alert.addAction(pasteNoteAction)
            }
            if let copiedPage = SKClipboard.getPage() {
                let pastePageAction = UIAlertAction(title: "Paste Page", style: .default) { action in
                    let (url, note) = NeoLibrary.createNoteFrom(notePages: [copiedPage])
                    NeoLibrary.saveSynchronously(note: note, url: url)
                    self.updateDisplayedNotes(true)
                    self.view.makeToast("New note from pasted page created.", duration: 2, position: .center)
                }
                alert.addAction(pastePageAction)
            }
            if let copiedNoteLayer = SKClipboard.getNoteLayer() {
                switch copiedNoteLayer.type {
                case .Image:
                    let pasteLayerAction = UIAlertAction(title: "Paste Image", style: .default) { action in
                        if let noteImage = copiedNoteLayer as? NoteImage {
                            let (url, note) = NeoLibrary.createNoteFrom(images: [noteImage.image])
                            NeoLibrary.saveSynchronously(note: note, url: url)
                            self.view.makeToast("New note from pasted image created.", duration: 2, position: .center)
                            self.updateDisplayedNotes(true)
                        }
                    }
                    alert.addAction(pasteLayerAction)
                    break
                case .TypedText:
                    let pasteLayerAction = UIAlertAction(title: "Paste Text", style: .default) { action in
                        if let noteTypedText = copiedNoteLayer as? NoteTypedText {
                            let (url, note) = NeoLibrary.createNoteFrom(typedTexts: [noteTypedText])
                            NeoLibrary.saveSynchronously(note: note, url: url)
                            self.view.makeToast("New note from pasted typed text created.", duration: 2, position: .center)
                            self.updateDisplayedNotes(true)
                        }
                    }
                    alert.addAction(pasteLayerAction)
                    break
                }
            }
            let clearAction = UIAlertAction(title: "Clear Clipboard", style: .destructive) { action in
                SKClipboard.clear()
                self.updateClipboardButton()
                self.view.makeToast("Cleared SKClipboard.", duration: 1, position: .center)
            }
            alert.addAction(clearAction)
            self.present(alert, animated: true)
        }
    }
    
    @IBAction func noteSortingTapped(_ sender: UIButton) {
        var newestTitle = "Newest First"
        var oldestTitle = "Oldest First"
        var nameAZTitle = "Alphabetically (A-Z)"
        var nameZATitle = "Alphabetically (Z-A)"
        switch SettingsManager.getFileSorting() {
            case .ByNewest:
                newestTitle += " ✔︎"
            case .ByOldest:
                oldestTitle += " ✔︎"
            case .ByNameAZ:
                nameAZTitle += " ✔︎"
            case .ByNameZA:
                nameZATitle += " ✔︎"
        }
        let newestAction = UIAlertAction(title: newestTitle, style: .default) { action in
            SettingsManager.setFileSorting(type: .ByNewest)
            self.updateDisplayedNotes(false)
        }
        let oldestAction = UIAlertAction(title: oldestTitle, style: .default) { action in
            SettingsManager.setFileSorting(type: .ByOldest)
            self.updateDisplayedNotes(false)
        }
        let nameAZAction = UIAlertAction(title: nameAZTitle, style: .default) { action in
            SettingsManager.setFileSorting(type: .ByNameAZ)
            self.updateDisplayedNotes(false)
        }
        let nameZAAction = UIAlertAction(title: nameZATitle, style: .default) { action in
            SettingsManager.setFileSorting(type: .ByNameZA)
            self.updateDisplayedNotes(false)
        }
        let alert = UIAlertController(title: "Sorting", message: "Sort your files by date or alphabetically.", preferredStyle: .actionSheet)
        alert.addAction(newestAction)
        alert.addAction(oldestAction)
        alert.addAction(nameAZAction)
        alert.addAction(nameZAAction)
        alert.popoverPresentationController?.sourceView = sender
        self.present(alert, animated: true)
    }
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in
            return self.makeFileContextMenu(url: self.items[indexPath.section][indexPath.row].0, file: self.items[indexPath.section][indexPath.row].1, point: point, cellIndexPath: indexPath)
        })
    }
    
    private func makeFileContextMenu(url: URL, file: File, point: CGPoint, cellIndexPath: IndexPath) -> UIMenu {
        var menuElements = [UIMenuElement]()
        var firstMenuElements = [UIMenuElement]()
        var secondMenuElements = [UIMenuElement]()
        var thirdMenuElements = [UIMenuElement]()
        var fourthMenuElements = [UIMenuElement]()
        let renameAction = UIAction(title: "Rename...", image: UIImage(systemName: "text.cursor")) { action in
            self.renameFile(url: url, file: file, indexPath: cellIndexPath)
        }
        firstMenuElements.append(renameAction)
        let moveAction = UIAction(title: "Move...", image: UIImage(systemName: "folder")) { action in
            self.moveFile(url: url, file: file)
        }
        firstMenuElements.append(moveAction)
        let exportAction = UIAction(title: "Export...", image: UIImage(systemName: "square.and.arrow.up")) { action in
            self.filesToExport = [(url, file)]
            self.displayExportWindow()
        }
        firstMenuElements.append(exportAction)
        
        if let note = file as? Note {
            let sendAction = UIAction(title: "Send...", image: UIImage(systemName: "paperplane")) { action in
                self.sendNote(url: url, note: note)
            }
            firstMenuElements.append(sendAction)
            let duplicateAction = UIAction(title: "Duplicate", image: UIImage(systemName: "doc.on.doc")) { action in
                _ = NeoLibrary.createDuplicate(note: note, url: url)
                self.updateDisplayedNotes(false)
            }
            firstMenuElements.append(duplicateAction)
            
            let tagsAction = UIAction(title: "Manage Tags...", image: UIImage(systemName: "tag.fill")) { action in
                self.editNoteTags(url: url, note: note, cell: self.noteCollectionView.cellForItem(at: cellIndexPath))
            }
            secondMenuElements.append(tagsAction)
            let similarNotesAction = UIAction(title: "Related Notes...", image: UIImage(systemName: "link")) { action in
                self.showRelatedNotesFor(url: url, note: note)
                self.view.makeToast("Showing related notes.", title: note.getName())
            }
            secondMenuElements.append(similarNotesAction)
            
            let copyNoteAction = UIAction(title: "Copy Note", image: UIImage(systemName: "doc.on.clipboard")) { action in
                SKClipboard.copy(note: note)
                self.updateClipboardButton()
                self.view.makeToast("Copied note to SKClipboard.")
            }
            thirdMenuElements.append(copyNoteAction)
            let copyTextAction = UIAction(title: "Copy Text", image: UIImage(systemName: "text.quote")) { action in
                UIPasteboard.general.string = note.getText()
                self.view.makeToast("Copied text to Clipboard.")
            }
            thirdMenuElements.append(copyTextAction)
        }
        let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "xmark.circle.fill"), attributes: .destructive) { action in
            self.deleteFile(url: url, file: file)
        }
        fourthMenuElements.append(deleteAction)
        
        menuElements.append(UIMenu(title: "Basic", options: .displayInline, children: firstMenuElements))
        menuElements.append(UIMenu(title: "Knowledge", options: .displayInline, children: secondMenuElements))
        if thirdMenuElements.count > 0 {
            menuElements.append(UIMenu(title: "Copy", options: .displayInline, children: thirdMenuElements))
        }
        menuElements.append(UIMenu(title: "Delete", options: .displayInline, children: fourthMenuElements))
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
        logger.info("Joining sessions...")
    }
    
    private var noteCollectionViewState = SettingsManager.getFileDisplayLayout()
    
    @IBOutlet weak var noteCollectionView: UICollectionView!
    
    var items: [[(URL, File)]] = Array(repeating: [], count: 2)

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.items[section].count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = self.items[indexPath.section][indexPath.row]
        switch self.noteCollectionViewState {
        case .Grid:
            if item.1 is Note {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: noteCollectionViewCellIdentifier, for: indexPath as IndexPath) as! NoteCollectionViewCell
                cell.toggleSelectionMode(status: self.isMultipleSelectionActive)
                cell.setFile(url: item.0, file: item.1)
                return cell
            }
            else { // Folder
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: folderCollectionViewCellIdentifier, for: indexPath as IndexPath) as! FolderCollectionViewCell
                cell.toggleSelectionMode(status: self.isMultipleSelectionActive)
                cell.setFile(url: item.0, file: item.1)
                return cell
            }
            
        case .List:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: noteCollectionViewDetailCellIdentifier, for: indexPath as IndexPath) as! NoteCollectionViewDetailCell
            cell.toggleSelectionMode(status: self.isMultipleSelectionActive)
            cell.setFile(url: item.0, file: item.1)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let item = self.items[indexPath.section][indexPath.row]
        switch self.noteCollectionViewState {
        case .Grid:
            if item.1 is Note {
                return CGSize(width: CGFloat(200), height: CGFloat(300))
            }
            else { // Folder
                return CGSize(width: CGFloat(200), height: CGFloat(150))
            }
            
        case .List:
            return CGSize(width: collectionView.bounds.size.width - CGFloat(10), height: CGFloat(100))
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = self.items[indexPath.section][indexPath.row]
        if self.isMultipleSelectionActive {
            self.selectedFiles[item.0] = item.1
            updateSelectAllButton()
        }
        else {
            self.open(url: item.0, file: item.1)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let item = self.items[indexPath.section][indexPath.row]
        if self.isMultipleSelectionActive {
            if self.selectedFiles[item.0] != nil {
                self.selectedFiles[item.0] = nil
            }
            updateSelectAllButton()
        }
    }
    
    public func open(url: URL, file: File) {
        if let note = file as? Note {
            self.noteToEdit = (url, note)
            self.performSegue(withIdentifier: "EditSketchnote", sender: self)
            logger.info("Opening note.")
        }
        else { // Folder
            NeoLibrary.currentLocation = url
            self.updateDisplayedNotes(false)
            self.updateFoldersHierarchy()
        }
    }
    
    private func renameFile(url: URL, file: File, indexPath: IndexPath) {
        let cell = noteCollectionView.cellForItem(at: indexPath)
        let cellFrame = cell?.frame ?? CGRect.zero
        if let fileInfoVC = self.storyboard?.instantiateViewController(withIdentifier: "NoteInfoViewController") as? FileInfoViewController {
            fileInfoVC.modalPresentationStyle = .popover
            fileInfoVC.file = (url, file)
            fileInfoVC.renameCompletion = { newName, newURL in
                self.noteCollectionView.performBatchUpdates({
                    self.noteCollectionView.reloadItems(at: [indexPath])
                })
                self.updateDisplayedNotes(false)
                self.view.makeToast("File renamed.")
            }
            if let popoverPresentationController = fileInfoVC.popoverPresentationController {
                popoverPresentationController.permittedArrowDirections = .up
                popoverPresentationController.sourceView = self.view
                popoverPresentationController.sourceRect = cellFrame
                popoverPresentationController.delegate = self
                present(fileInfoVC, animated: true, completion: nil)
            }
        }
    }
    
    var noteForRelatedNotes: (URL, Note)?
    private func showRelatedNotesFor(url: URL, note: Note) {
        /*let text2 = "IT security issues: the need for end user oriented research\nConsiderable attention has been given to the technical and policy issues involved with IT security issues in recent years. The growth of e-commerce and the Internet, as well as widely publicized hacker attacks, have brought IT security into prominent focus and routine corporate attention. Yet, much more research is needed from the end user (EU) perspective. This position paper is a call for such research and outlines some possible directions of interest"
        let text3 = "Compatibility of systems of linear constraints over the set of natural numbers. Criteria of compatibility of a system of linear Diophantine equations, strict inequations, and nonstrict inequations are considered. Upper bounds for components of a minimal set of solutions and algorithms of construction of minimal generating sets of solutions for all types of systems are given. These criteria and the corresponding algorithms for constructing a minimal supporting set of solutions can be used in solving all the considered types systems and systems of mixed types."
        let text = "BC−HurricaineGilbert, 09−11 339. BC−Hurricaine Gilbert, 0348. Hurricaine Gilbert heads toward Dominican Coast. By Ruddy Gonzalez. Associated Press Writer. Santo Domingo, Dominican Republic (AP). Hurricaine Gilbert Swept toward the Dominican Republic Sunday, and the Civil Defense alerted its heavily populated south coast to prepare for high winds, heavy rains, and high seas. The storm was approaching from the southeast with sustained winds of 75 mph gusting to 92 mph.'There is no need for alarm', Civil Defense Director Eugenio Cabral said in a television alert shortly after midnight Saturday. Cabral said residents of the province of Barahona should closely follow Gilbert’s movement. An estimated 100,000 people live in the province, including 70,000 in the city of Barahona, about 125 miles west of Santo Domingo. Tropical storm Gilbert formed in the eastern Carribean and strenghtened into a hurricane Saturday night. The National Hurricane Center in Miami reported its position at 2 a.m. Sunday at latitude 16.1 north, longitude 67.5 west, about 140 miles south of Ponce, Puerto Rico, and 200 miles southeast of Santo Domingo. The National Weather Service in San Juan, Puerto Rico, said Gilbert was moving westward at 15 mph with a 'broad area of cloudiness and heavy weather' rotating around the center of the storm. The weather service issued a flash flood watch for Puerto Rico and the Virgin Islands until at least 6 p.m. Sunday. Strong winds associated with the Gilbert brought coastal flooding, strong southeast winds, and up to 12 feet to Puerto Rico’s south coast. There were no reports on casualties. San Juan, on the north coast, had heavy rains and gusts Saturday, but they subsided during the night. On Saturday, Hurricane Florence was downgraded to a tropical storm, and its remnants pushed inland from the U.S. Gulf Coast. Residents returned home, happy to find little damage from 90 mph winds and sheets of rain. Florence, the sixth named storm of the 1988 Atlantic storm season, was the second hurricane. The first, Debby, reached minimal hurricane strength briefly before hitting the Mexican coast last month."
        let keywords = SKTextRank.shared.extractKeywords(text: text, numberOfKeywords: 10)
        logger.info(keywords)
        logger.info(Reductio.shared.keywords(from: text, count: 10))
        
        let sentences = SKTextRank.shared.summarize(text: text, numberOfSentences: 4)
        logger.info(sentences)
        logger.info(Reductio.shared.summarize(text: text, count: 4))*/
        /*let keywords = SKTextRank.shared.extractKeywords(text: note.getText(option: .FullText, parse: true), numberOfKeywords: 10, usePostProcessing: false)
        logger.info(keywords)
        logger.info(Reductio.shared.keywords(from: note.getText(option: .FullText, parse: true), count: 10))*/
        // MARK: TODO - temporary fix - to replace
        NoteSimilarity.shared.setupTFIDF(noteIterator: NeoLibrary.getNoteIterator())
        
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
    func selectedFolder(url: URL, for notes: [(URL, File)]) {
        
    }
    // Related Notes VC delegate
    func openRelatedNote(url: URL, note: Note) {
        self.open(url: url, file: note)
    }
    func mergedNotes(note1: Note, note2: Note) {
    }
    
    var selectedCellForTagEditing: UICollectionViewCell?
    private func editNoteTags(url: URL, note: Note, cell: UICollectionViewCell?) {
        self.selectedNoteForTagEditing = (url, note)
        self.selectedCellForTagEditing = cell
        self.performSegue(withIdentifier: "EditNoteTags", sender: self)
       }

    private func displayExportWindow() {
        self.performSegue(withIdentifier: "Export", sender: self)
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
            self.items[0].removeAll{$0.0 == url}
            self.items[1].removeAll{$0.0 == url}
            NeoLibrary.delete(url: url)
            self.noteCollectionView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { action in
              logger.info("Not deleting file.")
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = self.items[indexPath.section][indexPath.row]
        let itemProvider = NSItemProvider(object: item.1.getName() as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
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
            let sourceFile = self.items[sourceIndexPath.section][sourceIndexPath.row]
            let destinationItem = self.items[destinationIndexPath.section][destinationIndexPath.row]
            if !(destinationItem.1 is Note) { // Folder
                logger.info("Moving file to folder.")
                _ = NeoLibrary.move(file: sourceFile.1, from: sourceFile.0, to: destinationItem.0)
                self.updateDisplayedNotes(false)
            }
          }, completion: nil)
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if let destinationIndexPath = destinationIndexPath {
            let file = self.items[destinationIndexPath.section][destinationIndexPath.row]
            if file.1 is Note {
                return UICollectionViewDropProposal(operation: .forbidden, intent: .insertIntoDestinationIndexPath)
            }
            else {
                return UICollectionViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
            }
        }
        return UICollectionViewDropProposal(operation: .forbidden, intent: .insertIntoDestinationIndexPath)
    }
    
    // MARK: Selection
    @IBAction func selectionModeButtonTapped(_ sender: UIButton) {
        if self.isMultipleSelectionActive {
            selectionModeButton.setTitle("Select", for: .normal)
            self.selectedFiles = [URL : File]()
        }
        else {
            selectionModeButton.setTitle("Done", for: .normal)
        }
        self.isMultipleSelectionActive = !self.isMultipleSelectionActive
        self.noteCollectionView.visibleCells.forEach {cell in
            if let cell = cell as? ItemSelectionProtocol {
                cell.toggleSelectionMode(status: self.isMultipleSelectionActive)
            }
        }
        updateSelectAllButton()
    }
    
    @IBAction func selectAllButtonTapped(_ sender: UIButton) {
        // Select all
        if selectedFiles.isEmpty {
            self.items.forEach { item in
                item.forEach { file in
                    self.selectedFiles[file.0] = file.1
                }
            }
            noteCollectionView.visibleCells.forEach { cell in
                noteCollectionView.selectItem(at: noteCollectionView.indexPath(for: cell), animated: true, scrollPosition: .top)
            }
        }
        // Deselect all
        else {
            self.selectedFiles.removeAll()
            noteCollectionView.visibleCells.forEach { cell in
                noteCollectionView.selectItem(at: nil, animated: true, scrollPosition: .top)
            }
        }
        updateSelectAllButton()
    }
    
    private func updateSelectAllButton() {
        if selectedFiles.isEmpty {
            selectAllButton.setTitle("Select All", for: .normal)
        }
        else {
            selectAllButton.setTitle("Deselect All", for: .normal)
        }
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
                  logger.info("Not deleting selected files.")
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    @IBAction func exportSelectedButtonTapped(_ sender: UIButton) {
        if !self.selectedFiles.isEmpty {
            self.filesToExport = [(URL, File)]()
            for (url, file) in selectedFiles {
                self.filesToExport.append((url, file))
            }
            self.displayExportWindow()
        }
    }
    
    // MARK: SKClipboardDelegate (to update)
    func pasteNoteTapped() {
        logger.info("Pasting note: \(SKClipboard.getNote()?.getName() ?? "Note name could not be retrieved.")")
        if let n = SKClipboard.getNote() {
            NeoLibrary.add(note: n)
            self.updateDisplayedNotes(true)
            self.view.makeToast("Pasted note: \(n.getName())")
        }
    }
    func pastePageTapped() {
        logger.info("Pasting note page.")
        if let p = SKClipboard.getPage() {
            let newNote = Note(name: "Note Page Copy", documents: nil)
            newNote.pages = [p]
            NeoLibrary.add(note: newNote)
            self.updateDisplayedNotes(true)
            self.view.makeToast("Created new note \"Note Page Copy\" from pasted page.")
        }
        
    }
    func pasteNoteLayerTapped() {
        logger.info("Pasting note layer.")
        if let layer = SKClipboard.getNoteLayer() {
            if let noteImage = layer as? NoteImage {
                let (url, note) = NeoLibrary.createNoteFrom(images: [noteImage.image])
                NeoLibrary.saveSynchronously(note: note, url: url)
                self.updateDisplayedNotes(true)
                self.view.makeToast("Created new note \"Note Image Copy\" from pasted note image.")
            }
            if let noteTypedText = layer as? NoteTypedText {
                let (url, note) = NeoLibrary.createNoteFrom(typedTexts: [noteTypedText])
                NeoLibrary.saveSynchronously(note: note, url: url)
                self.updateDisplayedNotes(true)
                self.view.makeToast("Created new note \"Note Typed Text Copy\" from pasted note typed text.")
            }
        }
    }
    func clearClipboardTapped() {
        self.view.makeToast("Cleared SKClipboard.")
    }
}
