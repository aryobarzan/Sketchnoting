//
//  ReceivedNotesViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 05/02/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

class ReceivedNotesViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ReceivedNoteCellDelegate {
    
    @IBOutlet weak var visibilitySwitch: UISwitch!
    @IBOutlet weak var collectionView: UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self
        collectionView.dataSource = self
        if SKFileManager.receivedNotesController.mcAdvertiserAssistant != nil {
            visibilitySwitch.setOn(true, animated: true)
        }
        
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.itemSize = CGSize(width: 238, height: 327)
        layout.scrollDirection = .horizontal
        collectionView.collectionViewLayout = layout
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView.reloadData()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    @IBAction func visibilitySwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            SKFileManager.receivedNotesController.startHosting()
        }
        else {
            SKFileManager.receivedNotesController.stopHosting()
        }
        Notifications.announceDeviceVisibility()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return SKFileManager.receivedNotesController.receivedNotes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ReceivedNoteCell", for: indexPath as IndexPath) as! ReceivedNoteCollectionViewCell
        let note = SKFileManager.receivedNotesController.receivedNotes[indexPath.item]
        cell.setNote(note: note)
        cell.delegate = self
        return cell
    }
    
    /*func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(150), height: CGFloat(200))
    }*/
    
    func acceptReceivedNote(note: NoteX) {
        log.info("Accepted shared note")
        SKFileManager.receivedNotesController.receivedNotes.removeAll(where: { $0 == note } )
        _ = SKFileManager.add(note: note)
        self.collectionView.reloadData()
        Notifications.announceDeviceVisibility()
    }
       
    func rejectReceivedNote(note: NoteX) {
        log.info("Rejected shared note")
        SKFileManager.receivedNotesController.receivedNotes.removeAll(where: { $0 == note } )
        self.collectionView.reloadData()
        Notifications.announceDeviceVisibility()
    }
    
}
