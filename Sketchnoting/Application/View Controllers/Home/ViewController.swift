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
    
    @IBOutlet var searchField: UITextField!
    @IBOutlet var searchFiltersScrollView: UIScrollView!
    @IBOutlet var searchFiltersStackView: UIStackView!
    @IBOutlet var searchTypeButton: UIButton!
    private var searchType = SearchType.All
    @IBOutlet var searchPanelButton: UIButton!
    @IBOutlet var clearSearchButton: UIButton!
    @IBOutlet var noteListViewButton: UIButton!
    @IBOutlet weak var filtersButton: UIButton!
    @IBOutlet weak var receivedNotesButton: UIButton!
    var receivedNotesBadge: BadgeHub!
    
    @IBOutlet var searchPanel: UIView!
    @IBOutlet var noteSortingButton: UIButton!
    @IBOutlet var searchPanelHeightConstraint: NSLayoutConstraint!
    var searchPanelIsOpen = false
    @IBOutlet weak var searchFiltersPanel: UIView!
    
    @IBOutlet var drawingSearchPanel: UIView!
    @IBOutlet var clearDrawingSearchButton: UIButton!
    @IBOutlet var drawingSearchButton: UIButton!
    @IBOutlet var drawingSearchCanvas: PKCanvasView!
    @IBOutlet var blurView: UIVisualEffectView!
    
    
    @IBOutlet weak var clearSimilarNotesButton: UIButton!
    @IBOutlet weak var similarNotesTitleLabel: UILabel!
    
    var activeFiltersBadge: BadgeHub!
    var activeSearchFiltersBadge: BadgeHub!
    
    // Each search term entered is stored.
    var searchFilters = [SearchFilter]()
    // Each search term is displayed as a button, which when tapped, removes the search term.
    var searchFilterViews = [SearchFilterView]()
        
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
        self.navigationController?.navigationBar.barStyle = .black
        // Badge Hubs
        
        activeFiltersBadge = BadgeHub(view: filtersButton)
        activeSearchFiltersBadge = BadgeHub(view: searchPanelButton)
        activeFiltersBadge.scaleCircleSize(by: 0.45)
        activeSearchFiltersBadge.scaleCircleSize(by: 0.45)
        
        receivedNotesBadge = BadgeHub(view: receivedNotesButton)
        receivedNotesBadge.scaleCircleSize(by: 0.45)
        
        // The note-sharing related variables are instantiated
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        
        noteListViewButton.layer.masksToBounds = true
        noteListViewButton.layer.cornerRadius = 5
        
        searchPanelHeightConstraint.constant = 0
        
        drawingSearchPanel.layer.masksToBounds = true
        drawingSearchPanel.layer.cornerRadius = 5
        drawingSearchCanvas.tool = PKInkingTool(.pen, color: .black, width: 75)
        self.drawingSearchPanel.alpha = 0.0
        
        self.blurView.alpha = 0.0
        
        // The search views are setup, including the search field and the pop-up view for searching by drawing
        self.searchField.delegate = self
        
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
        
        
        //Drawing Recognition - This loads the labels for the drawing recognition's CoreML model.
        if let path = Bundle.main.path(forResource: "labels", ofType: "txt") {
            do {
                let data = try String(contentsOfFile: path, encoding: .utf8)
                let labelNames = data.components(separatedBy: .newlines).filter { $0.count > 0 }
                self.labelNames.append(contentsOf: labelNames)
            } catch {
                log.error("Failed to load labels for drawing recognition model: \(error)")
            }
        }
        let notificationCentre = NotificationCenter.default
        notificationCentre.addObserver(self, selector: #selector(self.notifiedImportSketchnote(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_IMPORT_NOTE), object: nil)
        notificationCentre.addObserver(self, selector: #selector(self.notifiedReceiveSketchnote(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_RECEIVE_NOTE), object: nil)
        notificationCentre.addObserver(self, selector: #selector(self.notifiedDeviceVisibility(_:)), name: NSNotification.Name(rawValue: Notifications.NOTIFICATION_DEVICE_VISIBILITY), object: nil)
        
        //Knowledge.refreshSimilarNotesGraph()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        self.setNeedsStatusBarAppearanceUpdate()
        
        self.updateReceivedNotesButton()
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        self.updateDisplayedNotes(false)
        self.selectedNoteForTagEditing = nil
        activeFiltersBadge.setCount(TagsManager.filterTags.count)        
    }
 
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
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
            receivedNotesButton.tintColor = UIColor.white
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
            self.items.append(contentsOf: Array(similarNotes.keys))
        }
        
        /*var filteredNotesToRemove = [NoteX]()
        if TagsManager.filterTags.count > 0 {
            for note in self.items {
                for tag in TagsManager.filterTags {
                    if !note.tags.contains(tag) {
                        filteredNotesToRemove.append(note)
                        break
                    }
                }
            }
            self.items = self.items.filter { !filteredNotesToRemove.contains($0) }
        }*/
        
        if searchFilters.count > 0 {
            var searchedNotesToRemove = [File]()
            for file in self.items {
                if let n = file as? NoteX {
                    if !n.applySearchFilters(filters: searchFilters) {
                        searchedNotesToRemove.append(file)
                    }
                }
            }
            self.items = self.items.filter { !searchedNotesToRemove.contains($0) }
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
    
    
    // When the user taps Return on the on-screen keyboard when the search field is in focus, the entered text is used as a search term and the application runs the search.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        if textField.tag == 100 {
            searchField.resignFirstResponder()
            performSearch()
        }
        return true
    }

    @IBAction func newNoteButtonTapped(_ sender: UIButton) {
        clearSearch()
        let newNote = NoteX(name: "Untitled", parent: SKFileManager.currentFolder?.id, documents: nil)
        _ = SKFileManager.add(note: newNote)
        SKFileManager.activeNote = newNote
        performSegue(withIdentifier: "NewSketchnote", sender: self)
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

            // "puppers" is the array backing the collection view
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
            self.searchPanel.isHidden = false
            self.searchPanelHeightConstraint.constant = 48
            self.view.layoutIfNeeded()
        }, completion: { (ended) in
            self.expandSearchFiltersPanel()
        })
        searchPanelIsOpen = true
    }
    private func collapseSearchPanel() {
        if self.searchPanelHeightConstraint.constant == 113 {
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: 0.25, delay: 0, animations: {
                self.searchPanelHeightConstraint.constant = 48
                self.view.layoutIfNeeded()
            }, completion: { (ended) in
                self.searchFiltersPanel.isHidden = true
                self.view.layoutIfNeeded()
                UIView.animate(withDuration: 0.25, delay: 0, animations: {
                    self.searchPanelHeightConstraint.constant = 0
                    self.view.layoutIfNeeded()
                }, completion: { (ended) in
                    self.searchPanel.isHidden = true
                })
            })
        }
        else {
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: 0.25, delay: 0, animations: {
                self.searchPanelHeightConstraint.constant = 0
                self.view.layoutIfNeeded()
            }, completion: { (ended) in
                self.searchPanel.isHidden = true
            })
        }
        searchPanelIsOpen = false
    }
    
    private func expandSearchFiltersPanel() {
        if self.searchFilters.count > 0 {
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: 0.25, delay: 0, animations: {
                self.searchFiltersPanel.isHidden = false
                self.searchPanelHeightConstraint.constant = 113
                self.view.layoutIfNeeded()
            }, completion: { (ended) in
            })
        }
    }
    private func collapseSearchFiltersPanel() {
        if self.searchPanelHeightConstraint.constant == 113 {
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: 0.25, delay: 0, animations: {
                self.searchPanelHeightConstraint.constant = 48
                self.view.layoutIfNeeded()
            }, completion: { (ended) in
                self.searchFiltersPanel.isHidden = true
            })
        }
    }
    
    private func performSearch() {
        if !searchField.text!.isEmpty {
            let searchString = searchField.text!.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            createSearchFilter(term: searchString, type: self.searchType)
            clearSearchButton.isHidden = false
            searchField.text = ""
        }
        if SKFileManager.notes.count == 0 || searchFilters.count == 0 {
            self.clearSearch()
        }
        else {
            clearSearchButton.isHidden = false
            self.expandSearchFiltersPanel()
            self.updateDisplayedNotes(false)
        }
        
        activeSearchFiltersBadge.setCount(self.searchFilters.count)
    }
    
    private func createSearchFilter(term: String, type: SearchType) {
        let termTrimmed = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filter = SearchFilter(term: termTrimmed, type: type)
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
        
        activeSearchFiltersBadge.setCount(0)
        
        self.updateDisplayedNotes(false)
        self.collapseSearchFiltersPanel()
    }
    @IBAction func searchTypeButtonTapped(_ sender: UIButton) {
        let popMenu = PopMenuViewController(sourceView: sender, actions: [PopMenuAction](), appearance: nil)
        popMenu.appearance.popMenuBackgroundStyle = .blurred(.dark)
        let allAction = PopMenuDefaultAction(title: "All", image: UIImage(systemName: "magnifyingglass.circle.fill"), didSelect: { action in
            self.searchTypeButton.setImage(UIImage(systemName: "magnifyingglass.circle.fill"), for: .normal)
            self.searchType = .All
            
        })
        popMenu.addAction(allAction)
        let textAction = PopMenuDefaultAction(title: "Text", image: UIImage(systemName: "text.alignleft"), didSelect: { action in
            self.searchTypeButton.setImage(UIImage(systemName: "text.alignleft"), for: .normal)
            self.searchType = .Text
            
        })
        popMenu.addAction(textAction)
        let drawingAction = PopMenuDefaultAction(title: "Drawing", image: UIImage(systemName: "scribble"), didSelect: { action in
            self.searchTypeButton.setImage(UIImage(systemName: "scribble"), for: .normal)
            self.searchType = .Drawing
            
        })
        popMenu.addAction(drawingAction)
        let documentAction = PopMenuDefaultAction(title: "Document", image: UIImage(systemName: "doc"), didSelect: { action in
            self.searchTypeButton.setImage(UIImage(systemName: "doc"), for: .normal)
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

    @IBAction func blurViewTapped(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            if !drawingSearchPanel.isHidden {
                 self.closeDrawingSearchPanel()
            }
        }
    }
    @IBAction func clearDrawingSearchTapped(_ sender: UIButton) {
        drawingSearchCanvas.drawing = PKDrawing()
    }
    @IBAction func drawingSearchTapped(_ sender: UIButton) {
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            let image = drawingSearchCanvas.drawing.image(from: drawingSearchCanvas.drawing.bounds, scale: 2)
            let resized = image.resize(newSize: CGSize(width: 28, height: 28))
            
            guard let pixelBuffer = resized.grayScalePixelBuffer() else {
                log.error("Failed to create pixel buffer.")
                return
            }
            do {
                currentPrediction = try drawnImageClassifier.prediction(image: pixelBuffer)
            }
            catch {
                log.error("Prediction failed: \(error)")
            }
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
            /*if noteForSimilarityFilter != nil && similarNotes != nil && similarityMax != nil {
                if self.items[indexPath.item] != noteForSimilarityFilter! {
                    cell.showSimilarityRing(weight: similarNotes![self.items[indexPath.item]]!, max: similarityMax!)
                }
            }*/
            return cell
        case .Detail:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierDetailCell, for: indexPath as IndexPath) as! NoteCollectionViewDetailCell
            cell.setFile(file: self.items[indexPath.item])
            cell.delegate = self
            /*if noteForSimilarityFilter != nil && similarNotes != nil && similarityMax != nil {
                if self.items[indexPath.item] != noteForSimilarityFilter! {
                    cell.showSimilarityRing(weight: similarNotes![self.items[indexPath.item]]!, max: similarityMax!)
                }
            }*/
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
            // TODO
        }
    }
    
    private func open(note: NoteX) {
        SKFileManager.activeNote = note
        self.performSegue(withIdentifier: "EditSketchnote", sender: self)
        log.info("Opening note.")
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
    var similarNotes: [NoteX : Double]?
    var similarityMax: Double?
    private func filterSimilarNotesFor(_ note: NoteX) {
        /*similarNotes = Knowledge.getNotesSimilarTo(note)
        if similarNotes != nil {
            noteForSimilarityFilter = note
            similarityMax = Array(similarNotes!.values).max()!
            self.updateDisplayedNotes(false)
            
            
            clearSimilarNotesButton.isHidden = false
            similarNotesTitleLabel.text = "Showing similar notes for: " + note.getTitle()
            similarNotesTitleLabel.isHidden = false
        }
        else {
            let banner = FloatingNotificationBanner(title: note.getTitle(), subtitle: "No similar notes could be found.", style: .info)
            banner.show()
        }*/
    }
    @IBAction func clearSimilarNotesTapped(_ sender: UIButton) {
        clearSimilarNotes()
    }
    
    private func clearSimilarNotes() {
        noteForSimilarityFilter = nil
        similarNotes = nil
        similarityMax = nil
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
