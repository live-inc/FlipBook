//
//  FlipBook.swift
//
//
//  Created by Brad Gayman on 1/24/20.
//

import UIKit

// MARK: - FlipBook -

/// Class that records a view
public final class FlipBook: NSObject {
    
    public static let compresion: CGFloat = 0.7
    
    // MARK: - Types -
    
    /// Enum that represents the errors that `FlipBook` can throw
    public enum FlipBookError: String, Error {
        
        /// Recording is already in progress. Stop current recording before beginning another.
        case recordingInProgress
        
        /// Recording is not availible using `ReplayKit` with `assetType == .gif`
        case recordingNotAvailible
    }
    
    /// Enum that represents type of asset to be merged
    public enum MergeType {
        case video
        case photo
    }

    // MARK: - Public Properties
    
    /// The number of frames per second targetted
    /// **Default** 60 frames per second on macOS and to the `maxFramesPerSecond` of the main screen of the device on iOS
    /// - Will be ignored if `shouldUseReplayKit` is set to true
    public var preferredFramesPerSecond: Int = Screen.maxFramesPerSecond
    
    /// The amount images in animated gifs should be scaled by. Fullsize gif images can be memory intensive. **Default** `0.5`
    public var gifImageScale: Float = 0.5
    
    /// The asset type to be created
    /// **Default** `.video`
    public var assetType: FlipBookAssetWriter.AssetType = .video
    
    // MARK: - Internal Properties -

    /// Asset writer used to convert screenshots into video
    internal let writer = FlipBookAssetWriter()
    
    /// Closure to be called when the asset writing has progressed
    internal var onProgress: ((CGFloat) -> Void)?
    
    internal var onProgress2: ((CGFloat) -> Void)?
    
    /// Closure to be called when compositing video with `CAAnimation`s
    internal var compositionAnimation: ((CALayer) -> Void)?
    
    /// URL to be merged after recording
    internal var mergeURL: (MergeType, URL)?
    
    /// Closure to be called when the video asset stops writing
    internal var onCompletion: ((Result<FlipBookAssetWriter.Asset, Error>) -> Void)?
    
    internal var onCompletion2: ((Result<FlipBookAssetWriter.Asset, Error>) -> Void)?
    
    /// View that is currently being recorded
    internal var sourceView: View?
    
    /// Display link that drives view snapshotting
    internal var displayLink: CADisplayLink?
    
    // MARK: - Public Methods -
    
    /// Starts recording a view
    /// - Parameters:
    ///   - view: view to be recorded. This value is ignored if `shouldUseReplayKit` is set to `true`
    ///   - compositionAnimation: optional closure for adding `AVVideoCompositionCoreAnimationTool` composition animations. Add `CALayer`s as sublayers to the passed in `CALayer`. Then trigger animations with a `beginTime` of `AVCoreAnimationBeginTimeAtZero`. *Reminder that `CALayer` origin for `AVVideoCompositionCoreAnimationTool` is lower left  for `UIKit` setting `isGeometryFlipped = true is suggested* **Default is `nil`**
    ///   - progress: optional closure that is called with a `CGFloat` representing the progress of video generation. `CGFloat` is in the range `(0.0 ... 1.0)`. `progress` is called from the main thread. **Default is `nil`**
    ///   - completion: closure that is called when the video has been created with the `URL` for the created video. `completion` will be called from the main thread
    public func startRecording(_ view: View,
                               compositionAnimation: ((CALayer) -> Void)? = nil,
                               mergeURL: (MergeType, URL)? = nil,
                               progress: ((CGFloat) -> Void)? = nil,
                               completion: @escaping (Result<FlipBookAssetWriter.Asset, Error>) -> Void) {
        guard displayLink == nil else {
            completion(.failure(FlipBookError.recordingInProgress))
            return
        }
        sourceView = view
        if !writing {
            onProgress = progress
            onCompletion = completion
        } else {
            onProgress2 = progress
            onCompletion2 = completion
        }
        
        self.compositionAnimation = compositionAnimation
        self.mergeURL = mergeURL
        writer.size = CGSize(width: view.bounds.size.width * view.scale, height: view.bounds.size.height * view.scale)
        writer.startDate = Date()
        writer.gifImageScale = gifImageScale
        writer.preferredFramesPerSecond = preferredFramesPerSecond
        
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        if #available(iOS 10.0, *) {
            displayLink?.preferredFramesPerSecond = preferredFramesPerSecond
        }
        displayLink?.add(to: RunLoop.main, forMode: .common)
    }
    
    /// Stops recording of view and begins writing frames to video
    public func stop() {
        guard let displayLink = self.displayLink else {
            return
        }
        displayLink.invalidate()
        self.displayLink = nil
        writer.endDate = Date()
        sourceView = nil
    }
    
    public func clear() {
        
        if !writing {
            writer.clearFrames()
            self.writer.startDate = nil
            self.writer.endDate = nil
            self.onProgress = nil
            self.onCompletion?(.failure(FlipBookError.recordingNotAvailible))
            self.onCompletion = nil
        } else {
            writer.clearStoredFrames()
            self.onProgress2 = nil
            self.onCompletion2?(.failure(FlipBookError.recordingNotAvailible))
            self.onCompletion2 = nil
        }
    
        self.compositionAnimation = nil
        self.mergeURL = nil
    }
    
    
    public var writing = false
    
    public func write() {
        writing = true
        
        writer.createVideoFromCapturedFrames(assetType: assetType,
                                             compositionAnimation: compositionAnimation,
                                             mergeURL: mergeURL,
        progress: { [weak self] (prog) in
            guard let self = self else {
                return
            }
            DispatchQueue.main.async {
                self.onProgress?(prog)
            }
        }, completion: { [weak self] result in
            guard let self = self else {
                return
            }
            DispatchQueue.main.async {
                self.onProgress = self.onProgress2
                self.onCompletion?(result)
                self.onCompletion = self.onCompletion2
                self.writer.transferStoredFrames()
                self.writing = false
                self.onProgress2 = nil
                self.onCompletion2 = nil
            }
        })
    }
        
    /// Saves a `LivePhotoResources` to photo library as a Live Photo. **You must request permission to modify photo library before attempting to save as well as add "Privacy - Photo Library Usage Description" key to your app's info.plist**
    /// - Parameters:
    ///   - resources: The resources of the Live Photo to be saved
    ///   - completion: Closure called after the resources have been saved. Called on the main thread.
    public func saveToLibrary(_ resources: LivePhotoResources, completion: @escaping (Result<Bool, Error>) -> Void) {
        writer.livePhotoWriter.saveToLibrary(resources, completion: completion)
    }
    
    /// Determines the frame rate of a gif by looking at the `delay` of the first image
    /// - Parameter gifURL: The file `URL` where the gif is located.
    /// - Returns: The frame rate as an `Int` or `nil` if data at url was invalid
    public func makeFrameRate(_ gifURL: URL) -> Int? {
        return writer.gifWriter?.makeFrameRate(gifURL)
    }
    
    /// Creates an array of `Image`s that represent the frames of a gif
    /// - Parameter gifURL: The file `URL` where the gif is located.
    /// - Returns: The frames rate as an `Int` or `nil` if data at url was invalid
    public func makeImages(_ gifURL: URL) -> [Image]? {
        return writer.gifWriter?.makeImages(gifURL)
    }
    
    // MARK: - Internal Methods -
    @objc internal func tick(_ displayLink: CADisplayLink) {
        if let frame = self.sourceView?.frame {
            DispatchQueue.global(qos: .background).sync { [weak self] in
                guard let viewImage = self?.sourceView?.fb_makeViewSnapshot(frame: frame) else {
                    return
                }
                if self?.writing == true {
                    self?.writer.storeFrame(viewImage)
                } else {
                    self?.writer.writeFrame(viewImage)
                }
            }
        }
    }
}
