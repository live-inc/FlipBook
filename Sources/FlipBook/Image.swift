//
//  Image.swift
//  
//
//  Created by Brad Gayman on 1/24/20.
//

import UIKit
public typealias Image = UIImage
extension Image {
    var cgI: CGImage? {
        return cgImage
    }
    
    var jpegRep: Data? {
        jpegData(compressionQuality: FlipBook.compression)
    }
    
    static func makeImage(cgImage: CGImage) -> Image {
        return UIImage(cgImage: cgImage)
    }
}
