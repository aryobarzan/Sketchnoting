//
//  MoleculeEditorViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import DropDown

class MoleculeEditorViewController: UIViewController, DirectionalAtomDelegate {
    
    @IBOutlet weak var atomDropDownButton: UIButton!
    @IBOutlet weak var directionDropDownButton: UIButton!
    @IBOutlet weak var bondSegmentedControl: UISegmentedControl!
    @IBOutlet weak var addAtomButton: UIButton!
    @IBOutlet weak var boardViewContainer: UIView!
    
    var atomDropDown: DropDown!
    var directionDropDown: DropDown!
    var heisenberg: HeisenbergDirectionalStructure<String>!
    var atoms = [String : DirectionalAtom<String>]()
    var firstAtom: DirectionalAtom<String>?
    
    var currentAtom: DirectionalAtom<String>!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        atomDropDown = DropDown()
        atomDropDown.anchorView = atomDropDownButton
        atomDropDown.dataSource = ["C", "H"]
        atomDropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            self.atomDropDownButton.setTitle("Atom: " + item, for: .normal)
        }
        atomDropDown.selectRow(0)
        directionDropDown = DropDown()
        directionDropDown.anchorView = directionDropDownButton
        directionDropDown.dataSource = ["Next", "Downward"]
        directionDropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            self.directionDropDownButton.setTitle("Direction: " + item, for: .normal)
        }
        directionDropDown.selectRow(0)
        
        // Do any additional setup after loading the view.
    }
    
    @IBAction func addAtomButtonTapped(_ sender: UIButton) {
        if firstAtom == nil {
            firstAtom = DirectionalAtom(with: atomDropDown.selectedItem!, color: .black, textColor: .white)
            firstAtom!.delegate = self
            self.view.makeToast("First atom registered. Add a second atom to initialize the structure!", duration: 5.0, position: .center)
        }
        else {
            if atoms.count == 0 {
                let secondAtom = DirectionalAtom(with: atomDropDown.selectedItem!, color: .black, textColor: .white)
                secondAtom.delegate = self
                heisenberg = HeisenbergDirectionalStructure(with: firstAtom!, itemSize: 40)
                heisenberg.linkWith(from: firstAtom!, to: secondAtom, way: getLinkWay(), bond: getBondSelection())
                atoms[firstAtom!.id] = firstAtom!
                atoms[secondAtom.id] = secondAtom
                let board = HeisenbergBoard<String>.init(with: heisenberg, with: .lightGray)
                let boardView = board.drawBoard()
                boardViewContainer.subviews.forEach { $0.removeFromSuperview() }
                boardViewContainer.addSubview(boardView)
                boardView.center = boardViewContainer.center
                
                currentAtom = secondAtom
                self.view.makeToast("Strucuture initialized.", duration: 1.0, position: .center)
            }
            else {
                let atom = DirectionalAtom(with: atomDropDown.selectedItem!, color: .black, textColor: .white)
                atom.delegate = self
                heisenberg.linkWith(from: currentAtom, to: atom, way: getLinkWay(), bond: getBondSelection())
                atoms[atom.id] = atom
                let board = HeisenbergBoard<String>.init(with: heisenberg, with: .lightGray)
                let boardView = board.drawBoard()
                boardViewContainer.subviews.forEach { $0.removeFromSuperview() }
                boardViewContainer.addSubview(boardView)
                boardView.center = boardViewContainer.center
                
                currentAtom = atom
            }
        }
    }
    
    func tappedAtom(id: String) {
        if let atom = atoms[id] {
            currentAtom = atom
            self.view.makeToast("Atom selected.", duration: 1.0, position: .center)
        }
    }
    
    @IBAction func bondSegmentedControlChanged(_ sender: UISegmentedControl) {
    }
    
    private func getBondSelection() -> HeisenbergDirectionalStructure<String>.BondType {
        switch bondSegmentedControl.selectedSegmentIndex {
        case 0:
            return HeisenbergDirectionalStructure<String>.BondType.singleBond
        case 1:
            return HeisenbergDirectionalStructure<String>.BondType.doubleBond
        case 2:
            return HeisenbergDirectionalStructure<String>.BondType.tripleBond
        default:
            return HeisenbergDirectionalStructure<String>.BondType.singleBond
        }
    }
    
    private func getLinkWay() -> StructuralWay {
        switch directionDropDown.selectedItem! {
        case "Next":
            return StructuralWay.next
        case "Downward":
            return StructuralWay.downward
        default:
            return StructuralWay.next
        }
    }
    @IBAction func atomDropDownButtonTapped(_ sender: UIButton) {
        atomDropDown.show()
    }
    @IBAction func directionDropDownButtonTapped(_ sender: UIButton) {
        directionDropDown.show()
    }
    @IBAction func cancelTapped(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    @IBAction func saveTapped(_ sender: UIBarButtonItem) {
        // Not implemented
        self.dismiss(animated: true, completion: nil)
    }
}
