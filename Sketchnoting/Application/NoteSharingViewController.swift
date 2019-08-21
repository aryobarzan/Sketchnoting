//
//  NoteSharingViewController.swift
//  Sketchnoting
//
//  Created by Kael on 20/08/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit
import LGButton
import MultipeerConnectivity

class NoteSharingViewController: UIViewController, MCSessionDelegate {

    @IBOutlet weak var acceptNoteButton: LGButton!
    @IBOutlet weak var declineNoteButton: LGButton!
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
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
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
    @IBAction func acceptNoteTapped(_ sender: LGButton) {
        print("Accepted shared note")
        if selectedSketchnote != nil && selectedPathArray != nil {
            if pendingSharedNotes.count > 0 {
                pendingSharedNotes.remove(at: currentIndex)
            }
            selectedSketchnote!.paths = selectedPathArray
            selectedSketchnote!.save()
        }
        self.view.showMessage("Shared note accepted and stored to your device.", type: .success)
        
        DispatchQueue.main.async {
            if self.currentIndex > 0 {
                self.currentIndex -= 1
            }
            self.updateViews()
        }
    }
    @IBAction func declineNoteTapped(_ sender: LGButton) {
        print("Rejected shared note")
        if selectedSketchnote != nil && selectedPathArray != nil {
            if pendingSharedNotes.count > 0 {
                pendingSharedNotes.remove(at: currentIndex)
            }
        }
        self.view.showMessage("Shared note declined.", type: .error)
        
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
    var selectedPathArray: NSMutableArray?
    var pendingSharedNotes = [(Sketchnote, NSMutableArray)]()
    
    var currentIndex : Int = 0
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let receivedData = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as?
            [Data]) as [Data]??) else { return }
        let decoder = JSONDecoder()
        guard let received = try? decoder.decode(Sketchnote.self, from: receivedData![0]) else {
            print("wrong data")
            return
        }
        received.sharedByDevice = peerID.displayName
        guard let receivedPath = ((try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(receivedData![1]) as?
            NSMutableArray) as NSMutableArray??) else { return }
        if receivedPath != nil {
            DispatchQueue.main.async {
                self.pendingSharedNotes.append((received, receivedPath!))
                self.view.showMessage("Device \(peerID.displayName) shared a note with you!", type: .info)
                self.updateViews()
            }
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
            let note = Array(pendingSharedNotes)[currentIndex].0
            let pathArray = Array(pendingSharedNotes)[currentIndex].1
            
            noteImageView.image = note.image
            sharedNoteLabel.text = "\(note.sharedByDevice ?? "Unknown") has shared a note with you."
            
            acceptNoteButton.isHidden = false
            declineNoteButton.isHidden = false
            
            notePageControl.numberOfPages = pendingSharedNotes.count
            notePageControl.currentPage = currentIndex
            
            selectedSketchnote = note
            selectedPathArray = pathArray
        }
        else {
            sharedNoteLabel.text = "There are no pending shared notes to view."
            acceptNoteButton.isHidden = true
            declineNoteButton.isHidden = true
            selectedSketchnote = nil
            selectedPathArray = nil
            noteImageView.image = nil
        }
    }
}
