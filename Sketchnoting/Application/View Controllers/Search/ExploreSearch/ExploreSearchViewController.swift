//
//  ExploreSearchViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 27/04/2021.
//  Copyright © 2021 Aryobarzan. All rights reserved.
//

import UIKit
import Graphite

class ExploreSearchViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, WeightedGraphPresenterDelegate {

    @IBOutlet weak var informationLabel: UILabel!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var graphContainerView: UIView!
    
    var exploreSearchOptions: [ExploreSearchOption] = [ExploreSearchOption]()
    var state: ExploreSearchState = .Timeframe
    
    var selectedOptions = [ExploreSearchState : [ExploreSearchOption]]()
    
    var graphPresenter: WeightedGraphPresenter!
    
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
            informationLabel.text = "Time frame:"
            resetButton.isHidden = true
            break
        case .Length:
            exploreSearchOptions = SKGraphSearch.shared.getLengthOptions()
            informationLabel.text = "Note length:"
            break
        case .Drawings:
            exploreSearchOptions = SKGraphSearch.shared.getDrawingOptions()
            informationLabel.text = "Drawing(s):"
            break
        case .Documents:
            exploreSearchOptions = SKGraphSearch.shared.getDocumentOptions(selectedDocumentOptions: selectedOptions[state]!.map{$0 as! ExploreSearchDocumentOption})
            informationLabel.text = "Related document(s):"
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
        graphContainerView.isHidden = true
        graphContainerView.subviews.forEach { subview in
            subview.removeFromSuperview()
        }
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
            if !selectedOptions[state]!.isEmpty {
                SKGraphSearch.shared.applyDrawings(options: selectedOptions[state]!.map{$0 as! ExploreSearchDrawingOption})
            }
            state = .Documents
            break
        case .Documents:
            if !selectedOptions[state]!.isEmpty {
                SKGraphSearch.shared.applyDocuments(options: selectedOptions[state]!.map{$0 as! ExploreSearchDocumentOption})
            }
            SKGraphSearch.shared.clearEdgelessVertices()
            // Perform search
            
            let nodes = SKGraphSearch.shared.getActiveGraph().vertices.enumerated().map{$0.offset}
            var edges = [Graph.Edge]()
            for (vertexIdx, _) in SKGraphSearch.shared.getActiveGraph().enumerated() {
                let edgesVertex = SKGraphSearch.shared.getActiveGraph().edgesForIndex(vertexIdx)
                for e in edgesVertex {
                    edges.append(Graph.Edge(nodes: [e.u, e.v], weight: Float(e.weight)))
                }
            }
            let forceDirectedGraph = Graph(nodes: nodes, edges: edges)
            graphPresenter = WeightedGraphPresenter(graph: Graph(nodes: [], edges: []), view: graphContainerView)
            graphPresenter.collisionDistance = 0
            graphPresenter.delegate = self
            graphPresenter.edgeColor = UIColor.gray
            graphPresenter.start()
            graphPresenter.graph = forceDirectedGraph
            graphPresenter.backgroundColor = .systemBackground
            
            graphContainerView.isHidden = false
            break
        }
        updateState()
    }
    
    // MARK: WeightedGraphPresenterDelegate
    func view(for node: Int, presenter: WeightedGraphPresenter) -> UIView {
        let view = UIImageView()
        view.tag = node
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleVertexTap(_:)))
        view.addGestureRecognizer(tapGestureRecognizer)
        view.isUserInteractionEnabled = true
        view.image = UIImage(systemName: "questionmark.circle.fill")
        let graphVertex = SKGraphSearch.shared.getActiveGraph().vertexAtIndex(node)
        if graphVertex is GraphNoteVertex {
            view.frame = CGRect(x: 0, y: 0, width: 175, height: 250)
            view.backgroundColor = UIColor.white
            view.layer.borderWidth = 2
            view.layer.borderColor = UIColor.systemGray.cgColor
            if let noteVertex = graphVertex as? GraphNoteVertex {
                noteVertex.note.getPreviewImage(completion: {image in
                    DispatchQueue.main.async {
                        view.image = image
                    }
                })
            }
        }
        else {
            view.frame = CGRect(x: 0, y: 0, width: 144, height: 144)
            view.backgroundColor = UIColor.systemBlue
            view.layer.masksToBounds = true
            view.layer.cornerRadius = 72
            view.tintColor = .black
            if let documentVertex = graphVertex as? GraphDocumentVertex {
                documentVertex.document.retrieveImage(type: .Standard, completion: {result in
                    switch result {
                    case .success(let value):
                        if let value = value {
                            DispatchQueue.main.async {
                                view.image = value
                            }
                        }
                    case .failure(let error):
                        logger.error(error)
                    }
                })
            }
        }
        return view
    }
    
    func configure(view: UIView, for node: Int, presenter: WeightedGraphPresenter) {
    }
    
    func visibleRange(for node: Int, presenter: WeightedGraphPresenter) -> ClosedRange<Float>? {
        return nil
    }
    
    @objc func handleVertexTap(_ sender: UITapGestureRecognizer) {
        if let vertexView = sender.view {
            let graphVertex = SKGraphSearch.shared.getActiveGraph().vertexAtIndex(vertexView.tag)
            if let documentVertex = graphVertex as? GraphDocumentVertex {
                self.presentDocumentDetail(document: documentVertex.document, popOverView: vertexView)
            }
        }
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
