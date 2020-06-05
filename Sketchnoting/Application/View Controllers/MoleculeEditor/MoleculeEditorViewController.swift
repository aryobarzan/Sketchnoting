//
//  MoleculeEditorViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 04/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import DropDown
import SwiftyJSON

class MoleculeEditorViewController: UIViewController, DirectionalAtomDelegate {
    
    static let PERIODIC_TABLE_ELEMENTS: [String] = setupPeriodicTableElements()
    
    static private func setupPeriodicTableElements() -> [String] {
        var elements = [String]()
        if let filePath = Bundle.main.url(forResource: "Periodic_Table", withExtension: "json") {
            if let data = try? Data(contentsOf: filePath, options: .mappedIfSafe) {
                let json = JSON(data)
                for element in json["elements"].array! {
                    if let symbol = element["symbol"].string {
                        elements.append(symbol)
                    }
                }
            }
        }
        return elements
    }
    
    @IBOutlet weak var atomDropDownButton: UIButton!
    @IBOutlet weak var directionDropDownButton: UIButton!
    @IBOutlet weak var bondSegmentedControl: UISegmentedControl!
    @IBOutlet weak var addAtomButton: UIButton!
    @IBOutlet weak var boardViewContainer: UIView!
    @IBOutlet weak var firstElementLabel: UILabel!
    @IBOutlet weak var atomSelectionIndicator: UIView!
    
    var atomDropDown: DropDown!
    var directionDropDown: DropDown!
    var heisenberg: HeisenbergDirectionalStructure<String>!
    var atoms = [String : DirectionalAtom<String>]()
    var firstAtom: DirectionalAtom<String>?
    var boardView: UIView?
    
    var currentAtom: DirectionalAtom<String>!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        atomDropDown = DropDown()
        atomDropDown.anchorView = atomDropDownButton
        atomDropDown.dataSource = MoleculeEditorViewController.PERIODIC_TABLE_ELEMENTS
        atomDropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            self.atomDropDownButton.setTitle(" Atom: " + item, for: .normal)
        }
        atomDropDown.selectRow(0)
        self.atomDropDownButton.setTitle(" Atom: " + atomDropDown.selectedItem!, for: .normal)
        directionDropDown = DropDown()
        directionDropDown.anchorView = directionDropDownButton
        directionDropDown.dataSource = ["Next", "Downward", "Upward", "Cross-Down-Forward", "Cross-Up-Forward", "Cross-Down-Backward", "Cross-Up-Backward"]
        directionDropDown.selectionAction = { [unowned self] (index: Int, item: String) in
            self.directionDropDownButton.setTitle(" Direction: " + item, for: .normal)
        }
        directionDropDown.selectRow(0)
        
        atomSelectionIndicator.layer.borderColor = UIColor.systemYellow.cgColor
        atomSelectionIndicator.layer.borderWidth = 2
        atomSelectionIndicator.layer.cornerRadius = 25
    }
    
    @IBAction func addAtomButtonTapped(_ sender: UIButton) {
        if firstAtom == nil {
            firstAtom = DirectionalAtom(with: atomDropDown.selectedItem!, color: .black, textColor: .white)
            firstAtom!.delegate = self
            atoms[firstAtom!.id] = firstAtom!
            firstElementLabel.text = "First atom is '" + atomDropDown.selectedItem! + "'. Add a second atom to initialize the structure."
            firstElementLabel.isHidden = false
            bondSegmentedControl.isHidden = false
            currentAtom = firstAtom
        }
        else {
            firstElementLabel.isHidden = true
            if atoms.count == 1 {
                heisenberg = HeisenbergDirectionalStructure(with: firstAtom!, itemSize: 40)
            }
            let atom = DirectionalAtom(with: atomDropDown.selectedItem!, color: .black, textColor: .white)
            atom.delegate = self
            heisenberg.linkWith(from: currentAtom, to: atom, way: getLinkWay(), bond: getBondSelection())
            atoms[atom.id] = atom
            let board = HeisenbergBoard<String>.init(with: heisenberg, with: .clear)
            if let boardView = boardView {
                boardView.removeFromSuperview()
            }
            boardView = board.drawBoard()
            boardViewContainer.addSubview(boardView!)
            boardView!.center = boardViewContainer.center
            atomSelectionIndicator.removeFromSuperview()
            boardView!.addSubview(atomSelectionIndicator)
        }
    }
    
    func tappedAtom(id: String, view: CGPoint?) {
        if let atom = atoms[id] {
            currentAtom = atom
            if let v = view {
                atomSelectionIndicator.center = v
                atomSelectionIndicator.isHidden = false
            }
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
        case "Upward":
            return StructuralWay.upward
        case "Cross-Down-Forward":
            return StructuralWay.crossDownForward
        case "Cross-Up-Forward":
            return StructuralWay.crossUpForward
        case "Cross-Down-Backward":
            return StructuralWay.crossDownBackward
        case "Cross-Up-Backward":
            return StructuralWay.crossUpBackward
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
