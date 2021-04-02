//
//  View.swift
//  
//
//  Created by Brad Gayman on 1/24/20.
//

import UIKit
public typealias View = UIView

extension View {
    
    var scale: CGFloat {
        Screen.main.scale
    }
    
    func fb_makeViewSnapshot(frame: CGRect) -> Data? {
        UIGraphicsBeginImageContextWithOptions(frame.size, true, 0)
        self.drawHierarchy(in: frame, afterScreenUpdates: false)
        guard let rasterizedView = UIGraphicsGetImageFromCurrentImageContext() else { return nil }
        let imageData = rasterizedView.jpegData(compressionQuality: FlipBook.compression)
        UIGraphicsEndImageContext()
        
        return imageData
    }
}
