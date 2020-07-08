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
        if NeoLibrary.receivedNotesController.mcAdvertiserAssistant != nil {
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
            NeoLibrary.receivedNotesController.startHosting()
        }
        else {
            NeoLibrary.receivedNotesController.stopHosting()
        }
        Notifications.announceDeviceVisibility()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return NeoLibrary.receivedNotesController.receivedNotes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ReceivedNoteCell", for: indexPath as IndexPath) as! ReceivedNoteCollectionViewCell
        let note = NeoLibrary.receivedNotesController.receivedNotes[indexPath.item]
        cell.setNote(note: note)
        cell.delegate = self
        return cell
    }
    
    func acceptReceivedNote(note: Note) {
        log.info("Accepted shared note")
        NeoLibrary.receivedNotesController.receivedNotes.removeAll(where: { $0 == note } )
        NeoLibrary.add(note: note)
        self.collectionView.reloadData()
        Notifications.announceDeviceVisibility()
    }
       
    func rejectReceivedNote(note: Note) {
        log.info("Rejected shared note")
        NeoLibrary.receivedNotesController.receivedNotes.removeAll(where: { $0 == note } )
        self.collectionView.reloadData()
        Notifications.announceDeviceVisibility()
    }
    
}
