//
//  NoteLayersViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 19/08/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit

enum NoteLayerItemType {
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

class NoteLayersViewController: UITableViewController, NoteLayersViewCellDelegate {
    
    var delegate: NoteLayersDelegate?
    
    var note: (URL, Note)!
    
    var sections = [LayerSection]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "xmark.circle.fill"), attributes: .destructive) { action in
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
            return UIMenu(title: "Layer", children: menuElements)
        })
    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

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
}
