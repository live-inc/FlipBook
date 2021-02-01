//
//  Image.swift
//  
//
//  Created by Brad Gayman on 1/24/20.
//

#if os(OSX)
import AppKit
public typealias Image = NSImage

extension Image {
    var cgI: CGImage? {
        return cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    
    var jpegRep: Data? {
        guard let cgImage = self.cgI else {
            return nil
        }
        let bits = NSBitmapImageRep(cgImage: cgImage)
        return bits.representation(using: .jpeg, properties: [:])
    }
    
    static func makeImage(cgImage: CGImage) -> Image {
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

#else
import UIKit
public typealias Image = UIImage
extension Image {
    var cgI: CGImage? {
        return cgImage
    }
    
    var jpegRep: Data? {
        jpegData(compressionQuality: 0.8)
    }
    
    static func makeImage(cgImage: CGImage) -> Image {
        return UIImage(cgImage: cgImage)
    }
}

#endif
