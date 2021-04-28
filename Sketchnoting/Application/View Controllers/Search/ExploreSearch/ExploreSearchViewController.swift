//
//  ExploreSearchViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 27/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit

class ExploreSearchViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {

    @IBOutlet weak var informationLabel: UILabel!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var exploreSearchOptions: [ExploreSearchOption] = [ExploreSearchOption]()
    var state: ExploreSearchState = .Timeframe
    
    var exploreSearchTimeframeOptions: [ExploreSearchTimeframeOption] = [ExploreSearchTimeframeOption(timeframe: .Recent), ExploreSearchTimeframeOption(timeframe: .Older)]
    var exploreSearchLengthOptions: [ExploreSearchLengthOption] = [ExploreSearchLengthOption(length: .Short), ExploreSearchLengthOption(length: .Long)]
    var exploreSearchDrawingOptions: [ExploreSearchDrawingOption] = [ExploreSearchDrawingOption]()
    var exploreSearchDocumentOptions: [ExploreSearchDocumentOption] = [ExploreSearchDocumentOption]()
    
    var selectedOptions = [ExploreSearchState : [ExploreSearchOption]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dataSource = self
        collectionView.delegate = self
        
        SKGraphSearch.shared.setup()
        
        for possibleState in ExploreSearchState.allCases {
            selectedOptions[possibleState] = [ExploreSearchOption]()
        }
        
        updateState()
    }
    
    func updateState() {
        resetButton.isHidden = false
        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(.systemBlue, for: .normal)
        switch state {
        case .Timeframe:
            exploreSearchOptions = SKGraphSearch.shared.getTimeframeOptions()
            informationLabel.text = "Timeframe:"
            resetButton.isHidden = true
            break
        case .Length:
            exploreSearchOptions = SKGraphSearch.shared.getLengthOptions()
            informationLabel.text = "Document length:"
            break
        case .Drawings:
            exploreSearchOptions = exploreSearchDrawingOptions
            informationLabel.text = "Drawing(s):"
            break
        case .Documents:
            exploreSearchOptions = SKGraphSearch.shared.getDocumentOptions(selectedDocumentOptions: selectedOptions[state]!.map{$0 as! ExploreSearchDocumentOption})
            informationLabel.text = "Document(s):"
            continueButton.setTitle("Search", for: .normal)
            continueButton.setTitleColor(.systemGreen, for: .normal)
            break
        }
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return exploreSearchOptions.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ExploreSearchViewCell", for: indexPath) as! ExploreSearchViewCell
        let option = exploreSearchOptions[indexPath.item]
        cell.label.text = option.toString()
        cell.label.textColor = .white
        cell.backgroundColor = .systemBlue
        if selectedOptions[state]!.contains(option) {
            cell.layer.borderColor = UIColor.systemGreen.cgColor
            cell.layer.borderWidth = 2.0
        }
        else {
            cell.layer.borderColor = UIColor.clear.cgColor
            cell.layer.borderWidth = 0.0
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let option = exploreSearchOptions[indexPath.item]
        if selectedOptions[state]!.contains(option) {
            selectedOptions[state]!.remove(object: option)
            collectionView.reloadItems(at: [indexPath])
        }
        else {
            if state == .Timeframe || state == .Length {
                selectedOptions[state]!.removeAll()
            }
            selectedOptions[state]!.append(option)
            collectionView.reloadItems(at: [indexPath])
        }
        if state == .Drawings || state == .Documents {
            updateState()
        }
    }

    @IBAction func resetButtonTapped(_ sender: UIButton) {
        for possibleState in ExploreSearchState.allCases {
            selectedOptions[possibleState]!.removeAll()
        }
        state = .Timeframe
        SKGraphSearch.shared.resetActiveGraph()
        updateState()
    }
    
    @IBAction func continueButtonTapped(_ sender: UIButton) {
        forwardState()
    }
    
    private func forwardState() {
        switch state {
        case .Timeframe:
            if !selectedOptions[state]!.isEmpty {
                SKGraphSearch.shared.applyTimeframe(option: selectedOptions[state]![0] as! ExploreSearchTimeframeOption)
            }
            state = .Length
            break
        case .Length:
            if !selectedOptions[state]!.isEmpty {
                SKGraphSearch.shared.applyLength(option: selectedOptions[state]![0] as! ExploreSearchLengthOption)
            }
            state = .Drawings
            break
        case .Drawings:
            state = .Documents
            break
        case .Documents:
            // Perform search
            break
        }
        updateState()
    }
}

enum ExploreSearchState: CaseIterable {
    case Timeframe
    case Length
    case Drawings
    case Documents
}

class ExploreSearchOption: ExploreSearchActions, Equatable {
    enum ExploreSearchOptionType: String, Equatable {
        case Timeframe = "Timeframe"
        case Length = "Length"
        case Drawing = "Drawing"
        case Document = "Document"
    }
    let type: ExploreSearchOptionType
    
    fileprivate init(type: ExploreSearchOptionType) {
        self.type = type
    }
    
    static func == (lhs: ExploreSearchOption, rhs: ExploreSearchOption) -> Bool {
        return lhs.getHashValue() == rhs.getHashValue()
    }
    
    func toString() -> String {
        return ""
    }
    
    func getHashValue() -> Int {
        return type.hashValue
    }
}

protocol ExploreSearchActions {
    func toString() -> String
    func getHashValue() -> Int
}

class ExploreSearchTimeframeOption: ExploreSearchOption {
    enum TimeframeOption: String, Equatable {
        case Recent = "Recent"
        case Older = "Older"
    }
    let timeframe: TimeframeOption
    init(timeframe: TimeframeOption) {
        self.timeframe = timeframe
        super.init(type: .Timeframe)
    }
    
    override func toString() -> String {
        return timeframe.rawValue
    }
    override func getHashValue() -> Int {
        return timeframe.hashValue
    }
}
class ExploreSearchLengthOption: ExploreSearchOption {
    enum LengthOption: String {
        case Short = "Short"
        case Long = "Long"
    }
    let length: LengthOption
    init(length: LengthOption) {
        self.length = length
        super.init(type: .Length)
    }
    
    override func toString() -> String {
        return length.rawValue
    }
    override func getHashValue() -> Int {
        return length.hashValue
    }
}
class ExploreSearchDrawingOption: ExploreSearchOption {
    let drawing: String
    init(drawing: String) {
        self.drawing = drawing
        super.init(type: .Drawing)
    }
    
    override func toString() -> String {
        return drawing
    }
    override func getHashValue() -> Int {
        return drawing.hashValue
    }
}
class ExploreSearchDocumentOption: ExploreSearchOption {
    let document: Document
    init(document: Document) {
        self.document = document
        super.init(type: .Document)
    }
    
    override func toString() -> String {
        return document.title
    }
    override func getHashValue() -> Int {
        return document.hashValue
    }
}
