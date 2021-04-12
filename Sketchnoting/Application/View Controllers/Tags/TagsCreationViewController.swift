//
//  TagsCreationViewController.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 07/12/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

class TagsCreationViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{

    var colors = [ #colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1), #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1), #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1), #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1), #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1), #colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1), #colorLiteral(red: 0.1294117719, green: 0.2156862766, blue: 0.06666667014, alpha: 1), #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1), #colorLiteral(red: 0.721568644, green: 0.8862745166, blue: 0.5921568871, alpha: 1), #colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1), #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1), #colorLiteral(red: 0.3098039329, green: 0.2039215714, blue: 0.03921568766, alpha: 1), #colorLiteral(red: 0.3176470697, green: 0.07450980693, blue: 0.02745098062, alpha: 1), #colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1), #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1), #colorLiteral(red: 0.9568627477, green: 0.6588235497, blue: 0.5450980663, alpha: 1), #colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1), #colorLiteral(red: 0.5725490451, green: 0, blue: 0.2313725501, alpha: 1), #colorLiteral(red: 0.1921568662, green: 0.007843137719, blue: 0.09019608051, alpha: 1), #colorLiteral(red: 0.9167016745, green: 0, blue: 0.4358976483, alpha: 1)]
    
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var colorsCollectionView: UICollectionView!
    @IBOutlet weak var createButton: UIButton!
    
    let tagsManager = TagsManager()
    
    var selectedColor = #colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1)
    override func viewDidLoad() {
        super.viewDidLoad()
        colorsCollectionView.dataSource = self
        colorsCollectionView.delegate = self
    }

    @IBAction func createTapped(_ sender: UIButton) {
        if !(nameField.text?.isEmpty ?? true) {
            let newTag = Tag(title: nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Tag", color: selectedColor)
            tagsManager.add(tag: newTag)
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colors.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCell", for: indexPath as IndexPath)
        cell.backgroundColor = self.colors[indexPath.item]
        cell.layer.cornerRadius = 25
        
        if cell.backgroundColor == selectedColor {
            cell.layer.borderColor = UIColor.yellow.cgColor
            cell.layer.borderWidth = 2
        }
        else {
            cell.layer.borderWidth = 0
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                           layout collectionViewLayout: UICollectionViewLayout,
                           sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: CGFloat(50), height: CGFloat(50))
    }
       
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedColor = self.colors[indexPath.item]
        colorsCollectionView.reloadData()
    }
}
