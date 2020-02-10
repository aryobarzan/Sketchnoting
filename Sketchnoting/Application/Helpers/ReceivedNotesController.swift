//
//  ReceivedNotesController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 05/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ReceivedNotesController: NSObject, MCSessionDelegate {
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let decodedNote = SKFileManager.decodeNoteFromData(data: data) {
            decodedNote.sharedByDevice = peerID.displayName
            DispatchQueue.main.async {
                self.receivedNotes.append(decodedNote)
                log.info("Decoded shared note.")
                Notifications.announce(receivedNote: decodedNote)
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
    
    var receivedNotes: [NoteX]!
    var peerID: MCPeerID!
    var mcSession: MCSession!
    var mcAdvertiserAssistant: MCAdvertiserAssistant?
    
    override init() {
        super.init()
        receivedNotes = [NoteX]()
        peerID = MCPeerID(displayName: UIDevice.current.name)
        mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
    }
    
    func startHosting() {
        mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: "hws-kb", discoveryInfo: nil, session: mcSession)
        mcAdvertiserAssistant!.start()
        log.info("Started hosting session")
    }
    
    func stopHosting() {
        if mcAdvertiserAssistant != nil {
            mcAdvertiserAssistant!.stop()
        }
    }
}
