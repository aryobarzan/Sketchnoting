//
//  SKClipboard.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 20/06/2020.
//  Copyright © 2020 Aryobarzan. All rights reserved.
//

import UIKit
import Hover

class SKClipboard {
    private static var note: Note?
    private static var page: NotePage?
    private static var image: NoteImage?
    private static var typedText: NoteTypedText?
    
    private static var hoverView: HoverView?
    
    public static var delegate: SKClipboardDelegate?
    
    public static func clear() {
        self.note = nil
        self.page = nil
        self.image = nil
        self.typedText = nil
    }
    
    public static func hasItems() -> Bool {
        if self.note != nil || self.page != nil || self.image != nil || self.typedText != nil {
            return true
        }
        return false
    }
    
    public static func copy(note: Note) {
        self.note = note.duplicate()
    }
    
    public static func copy(page: NotePage) {
        self.page = page
    }
    
    public static func copy(image: NoteImage) {
        self.image = image
    }
    
    public static func copy(typedText: NoteTypedText) {
        self.typedText = typedText
    }
    
    public static func getNote() -> Note? {
        return note
    }
    
    public static func getPage() -> NotePage? {
        return page
    }
    
    public static func getImage() -> NoteImage? {
        return image
    }
    
    public static func getTypedText() -> NoteTypedText? {
        return typedText
    }
    
    public static func addClipboardButton(view: UIView) {
        let configuration = HoverConfiguration(image: UIImage(systemName: "doc.on.clipboard"), color: .gradient(top: .blue, bottom: .cyan))

        var items = [HoverItem]()
        if self.note != nil {
            items.append(HoverItem(title: "Paste Note", image: UIImage(systemName: "doc.circle")!) { self.delegate?.pasteNoteTapped() })
        }
        if self.page != nil {
            items.append(HoverItem(title: "Paste Page", image: UIImage(systemName: "doc.text")!) { self.delegate?.pastePageTapped() })
        }
        if self.image != nil {
            items.append(HoverItem(title: "Paste Image", image: UIImage(systemName: "photo")!) { self.delegate?.pasteImageTapped() })
        }
        if self.typedText != nil {
            items.append(HoverItem(title: "Paste Text", image: UIImage(systemName: "text.alignleft")!) { self.delegate?.pasteTypedTextTapped() })
        }
        if items.count > 0 {
            items.append(HoverItem(title: "Clear", image: UIImage(systemName: "clear")!) {
                self.delegate?.clearClipboardTapped()
                self.clear()
                self.hoverView!.removeFromSuperview()
                self.hoverView = nil
            })
            if let h = self.hoverView {
                h.removeFromSuperview()
            }
            self.hoverView = HoverView(with: configuration, items: items)
            view.addSubview(self.hoverView!)
            self.hoverView!.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate(
                [
                    self.hoverView!.topAnchor.constraint(equalTo: view.topAnchor),
                    self.hoverView!.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    self.hoverView!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    self.hoverView!.trailingAnchor.constraint(equalTo: view.trailingAnchor)
                ]
            )
        }
    }
}

public protocol SKClipboardDelegate {
    func pasteNoteTapped()
    func pastePageTapped()
    func pasteImageTapped()
    func pasteTypedTextTapped()
    func clearClipboardTapped()
}
