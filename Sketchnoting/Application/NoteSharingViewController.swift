//
//  NoteSharingViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import PencilKit

import NotificationBannerSwift

class NoteSharingViewController: UIViewController, MCSessionDelegate {

    @IBOutlet weak var acceptNoteButton: UIButton!
    @IBOutlet weak var declineNoteButton: UIButton!
    @IBOutlet weak var noteImageView: UIImageView!
    @IBOutlet weak var sharedNoteLabel: UILabel!
    @IBOutlet weak var notePageControl: UIPageControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        
        noteImageView.layer.borderColor = UIColor.black.cgColor
        noteImageView.layer.borderWidth = 2
        
        noteImageView.isUserInteractionEnabled = true
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(self.noteImageViewSwiped(_:)))
        swipeGesture.direction = .left
        noteImageView.addGestureRecognizer(swipeGesture)
        let swipeRightGesture = UISwipeGestureRecognizer(target: self, action: #selector(self.noteImageViewSwiped(_:)))
        swipeRightGesture.direction = .right
        noteImageView.addGestureRecognizer(swipeRightGesture)
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    @IBAction func closeTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    // Mark: events
    @IBAction func noteSharingSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            startHosting()
        }
        else {
            if mcAdvertiserAssistant != nil {
                mcAdvertiserAssistant!.stop()
            }
        }
    }
    @IBAction func acceptTapped(_ sender: UIButton) {
        log.info("Accepted shared note")
        if selectedSketchnote != nil {
            selectedSketchnote!.clearTextData()
            if pendingSharedNotes.count > 0 {
                pendingSharedNotes.remove(at: currentIndex)
            }
            selectedSketchnote!.save()
        }
        let banner = FloatingNotificationBanner(title: selectedSketchnote?.getTitle() ?? "Untitled", subtitle: "The shared note has been accepted and stored to your device.", style: .success)
        banner.show()
        
        DispatchQueue.main.async {
            if self.currentIndex > 0 {
                self.currentIndex -= 1
            }
            self.updateViews()
        }
    }
    
    @IBAction func declineTapped(_ sender: UIButton) {
        log.info("Rejected shared note")
        if selectedSketchnote != nil{
            if pendingSharedNotes.count > 0 {
                pendingSharedNotes.remove(at: currentIndex)
            }
        }
        let banner = FloatingNotificationBanner(title: "Note declined.", subtitle: "The shared note has been deleted.", style: .info)
        banner.show()
        
        DispatchQueue.main.async {
            if self.currentIndex > 0 {
                self.currentIndex -= 1
            }
            self.updateViews()
        }
    }
   
    @IBAction func notePageControlChanged(_ sender: UIPageControl) {
    }
    
    @objc func noteImageViewSwiped(_ sender: UISwipeGestureRecognizer) {
        if sender.state == .ended {
            if sender.direction == UISwipeGestureRecognizer.Direction.right {
                if currentIndex > 0 {
                    currentIndex = currentIndex - 1
                }
            } else if sender.direction == UISwipeGestureRecognizer.Direction.left {
                if currentIndex < pendingSharedNotes.count - 1 {
                    currentIndex = currentIndex + 1
                }
            }
            notePageControl.currentPage = currentIndex
            updateViews()
        }
    }
    // MARK: multipeer
    //var peerID: MCPeerID!
    //var mcSession: MCSession!
    var peerID: MCPeerID!
    var mcSession: MCSession!
    var mcAdvertiserAssistant: MCAdvertiserAssistant?
    
    var selectedSketchnote: Sketchnote?
    var pendingSharedNotes = [Sketchnote]()
    
    var currentIndex : Int = 0
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let decodedNote = NoteLoader.decodeNoteFromData(data: data) {
            decodedNote.sharedByDevice = peerID.displayName
            DispatchQueue.main.async {
                self.pendingSharedNotes.append(decodedNote)
                let banner = FloatingNotificationBanner(title: "New Note", subtitle: "Device \(peerID.displayName) shared a note with you!", style: .info)
                banner.show()
                self.updateViews()
                log.info("Decoded shared note.")
            }
        }
        else {
            log.error("Failed to decode note shared with you.")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    private func startHosting() {
        mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "hws-kb", discoveryInfo: nil, session: mcSession)
        mcAdvertiserAssistant!.start()
        print("Started hosting session")
    }
    
    // MARK: View Updates
    
    private func updateViews() {
        if pendingSharedNotes.count > 0 && currentIndex < pendingSharedNotes.count {
            let note = pendingSharedNotes[currentIndex]
            
            noteImageView.image = note.image
            sharedNoteLabel.text = "\(note.sharedByDevice ?? "Unknown") has shared a note with you."
            
            acceptNoteButton.isEnabled = true
            declineNoteButton.isEnabled = true
            
            notePageControl.numberOfPages = pendingSharedNotes.count
            notePageControl.currentPage = currentIndex
            
            selectedSketchnote = note
        }
        else {
            sharedNoteLabel.text = "There are no pending shared notes to view."
            acceptNoteButton.isEnabled = false
            declineNoteButton.isEnabled = false
            selectedSketchnote = nil
            noteImageView.image = nil
        }
    }
}
