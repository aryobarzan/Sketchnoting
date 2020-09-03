//
//  NoteLayersViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 19/08/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

enum NoteLayerItemType: String {
    case Canvas
    case Layer
    case PDF
}

class NoteLayerItem {
    var type: NoteLayerItemType
    var layer: NoteLayer?
    var zoom: Float?
    
    init(type: NoteLayerItemType, layer: NoteLayer? = nil, zoom: Float? = nil) {
        self.type = type
        self.layer = layer
        self.zoom = zoom
    }
}

struct LayerSection {
    let title: String
    var data : [NoteLayerItem]

    var numberOfItems: Int {
        return data.count
    }

    subscript(index: Int) -> NoteLayerItem {
        return data[index]
    }
}

class NoteLayersViewController: UITableViewController, NoteLayersViewCellDelegate, UITableViewDragDelegate, UITableViewDropDelegate {
    
    var delegate: NoteLayersDelegate?
    
    var note: (URL, Note)!
    
    var sections = [LayerSection]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dragDelegate = self
        tableView.dropDelegate = self
        tableView.dragInteractionEnabled = true
        
        self.loadData()
    }
    
    private func loadData() {
        self.sections = [LayerSection]()
        sections.append(LayerSection(title: "Canvas", data: [NoteLayerItem(type: .Canvas)]))
        
        var layersData = [NoteLayerItem]()
        for layer in note.1.getCurrentPage().getLayers() {
            layersData.append(NoteLayerItem(type: .Layer, layer: layer))
        }
        if layersData.count > 0 {
            let layersSection = LayerSection(title: "Layers", data: layersData)
            self.sections.append(layersSection)
        }
        
        if note.1.getCurrentPage().getPDFDocument() != nil {
            sections.append(LayerSection(title: "PDF", data: [NoteLayerItem(type: .PDF, zoom: note.1.getCurrentPage().pdfScale)]))
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return sections[section].data.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100.0;
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteLayersViewCell", for: indexPath) as! NoteLayersViewCell
        let item = self.sections[indexPath.section].data[indexPath.row]
        cell.set(item: item)
        cell.delegate = self
        return cell
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let item = self.sections[indexPath.section].data[indexPath.row]
        var menuElements = [UIMenuElement]()
        var menuTitle = "Canvas"
        switch item.type {
        case .Canvas:
            menuTitle = "Canvas"
            break
        case .Layer:
            menuTitle = "Layer"
            break
        case .PDF:
            menuTitle = "PDF"
            break
        }
        let deleteAction = UIAction(title: (item.type == .Canvas) ? "Clear" : "Delete", image: UIImage(systemName: "xmark.circle.fill"), attributes: .destructive) { action in
            switch item.type {
            case .Canvas:
                self.delegate?.clearCanvas()
                self.note.1.getCurrentPage().clearCanvas()
                break
            case .Layer:
                if let layer = item.layer {
                    self.delegate?.deleteLayer(layer: layer)
                    self.note.1.getCurrentPage().deleteLayer(layer: layer)
                    self.sections[1].data.remove(at: indexPath.row)
                    self.tableView.reloadData()
                }
                break
            case .PDF:
                self.delegate?.deletePDF()
                self.note.1.getCurrentPage().backdropPDFData = nil
                self.sections.remove(at: 2)
                self.tableView.reloadData()
                break
            }
        }
        menuElements.append(deleteAction)
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { suggestedActions in
            return UIMenu(title: menuTitle, children: menuElements)
        })
    }
    
    // Drag and drop delegates for re-ordering
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        if indexPath.section != 1 {
            return [UIDragItem]()
        }
        let item = self.sections[indexPath.section].data[indexPath.row]
        let itemProvider = NSItemProvider(object: item.type.rawValue as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath else {
          return
        }
        
        coordinator.items.forEach { dropItem in
          guard let sourceIndexPath = dropItem.sourceIndexPath else {
            return
          }
          tableView.performBatchUpdates({
            let layer = note.1.getCurrentPage().getLayers()[sourceIndexPath.item]
            note.1.getCurrentPage().deleteLayer(at: sourceIndexPath)
            note.1.getCurrentPage().insertLayer(layer, at: destinationIndexPath)
            let layerItem = self.sections[sourceIndexPath.section].data[sourceIndexPath.row]
            sections[1].data.remove(at: sourceIndexPath.row)
            sections[1].data.insert(layerItem, at: destinationIndexPath.row)
            tableView.deleteRows(at: [sourceIndexPath], with: .automatic)
            tableView.insertRows(at: [destinationIndexPath], with: .automatic)
            delegate?.noteLayerReordered(layer: layer, index: destinationIndexPath)
          }, completion: { _ in
            coordinator.drop(dropItem.dragItem,
                             toRowAt: destinationIndexPath)
           DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          }
          })
        }
    }
    
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        if let destination = destinationIndexPath {
            if (destination.section != 1) {
                return UITableViewDropProposal(operation: .forbidden, intent: .insertAtDestinationIndexPath)
            }
            return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UITableViewDropProposal(operation: .forbidden, intent: .insertAtDestinationIndexPath)
    }

    // Cell Delegate
    func zoomValueChanged(value: Double) {
        note.1.getCurrentPage().pdfScale = Float(value)
        delegate?.pdfScaleChanged(value: Float(value))
    }
}

protocol NoteLayersDelegate {
    func pdfScaleChanged(value: Float)
    func deleteLayer(layer: NoteLayer)
    func deletePDF()
    func clearCanvas()
    func noteLayerReordered(layer: NoteLayer, index: IndexPath)
}
