//
//  UIViewControllerExtensions.swift
//  Sketchnoting
//
//  Created by Aryobarzan on 13/03/2019.
//  Copyright © 2019 Aryobarzan. All rights reserved.
//

import UIKit

extension UIViewController {
    func curveTopCorners() {
        let path = UIBezierPath(roundedRect: self.view.bounds,
                                byRoundingCorners: [.topLeft, .topRight],
                                cornerRadii: CGSize(width: 30, height: 0))
        let maskLayer = CAShapeLayer()
        maskLayer.frame = self.view.bounds
        maskLayer.path = path.cgPath
        self.view.layer.mask = maskLayer
    }
    func showInputDialog(title:String? = nil,
                         subtitle:String? = nil,
                         actionTitle:String? = "Add",
                         cancelTitle:String? = "Cancel",
                         inputPlaceholder:String? = nil,
                         inputKeyboardType:UIKeyboardType = UIKeyboardType.default,
                         cancelHandler: ((UIAlertAction) -> Swift.Void)? = nil,
                         actionHandler: ((_ text: String?) -> Void)? = nil) {

        let alert = UIAlertController(title: title, message: subtitle, preferredStyle: .alert)
        alert.addTextField { (textField:UITextField) in
            textField.placeholder = inputPlaceholder
            textField.keyboardType = inputKeyboardType
        }
        alert.addAction(UIAlertAction(title: actionTitle, style: .destructive, handler: { (action:UIAlertAction) in
            guard let textField =  alert.textFields?.first else {
                actionHandler?(nil)
                return
            }
            actionHandler?(textField.text)
        }))
        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: cancelHandler))

        self.present(alert, animated: true, completion: nil)
    }
    
    //
    private struct activityAlert {
        static var activityIndicatorAlert: UIAlertController?
    }
    //completion : ((Int, String) -> Void)?)
    func displayLoadingAlert(title: String, subtitle: String, _ onCancel : (()-> Void)?) {
        activityAlert.activityIndicatorAlert = UIAlertController(title: title, message: subtitle , preferredStyle: UIAlertController.Style.alert)
        activityAlert.activityIndicatorAlert!.addActivityIndicator()
        // MARK: TODO - Modify for multi-window iPad support
        var topController:UIViewController = UIApplication.shared.windows.filter {$0.isKeyWindow}.first!.rootViewController!
        while ((topController.presentedViewController) != nil) {
            topController = topController.presentedViewController!
        }
        
        activityAlert.activityIndicatorAlert!.addAction(UIAlertAction.init(title:NSLocalizedString("Cancel", comment: ""), style: .default, handler: { (UIAlertAction) in
            self.dismissLoadingAlert()
            onCancel?()
        }))
        topController.present(activityAlert.activityIndicatorAlert!, animated:true, completion:nil)
    }
    
    func dismissLoadingAlert() {
        activityAlert.activityIndicatorAlert?.dismissActivityIndicator()
        activityAlert.activityIndicatorAlert = nil
    }
    
    // MARK: Document Detail View Controller
    
    func presentDocumentDetail(document: Document, popOverView: UIView? = nil) {
        let documentDetailVC = UIStoryboard(name: "Main", bundle: Bundle.main).instantiateViewController(withIdentifier: "DocumentDetailViewController") as? DocumentDetailViewController
        if let documentDetailVC = documentDetailVC {
            if let popOverView = popOverView {
                documentDetailVC.modalPresentationStyle = .popover
                documentDetailVC.popoverPresentationController?.sourceView = popOverView
            }
            else {
                documentDetailVC.modalPresentationStyle = .formSheet
            }
            present(documentDetailVC, animated: true, completion: nil)
            documentDetailVC.setDocument(document: document, isInBookshelf: false)
        }
    }
}
