//
//  MovieTransitionVC.swift
//  TaskOne
//
//  Created by Softzino MBP 302 on 11/10/22.
//

import AVFoundation
import AVKit
import CoreImage
import PhotosUI
import UIKit

class MovieTransitionsVC: UIViewController {
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    // Set the transition duration time to 2 seconds.
    private let TRANSITION_DURATION = CMTimeMake(value: 2, timescale: 1)

    var videoUrls: [URL] = []
    
    private var mergedVideoUrl: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mergedVideo()
    }

    private func mergedVideo() {
        var avAssets: [AVAsset] = []
        for videoUrl in videoUrls {
            avAssets.append(AVAsset(url: videoUrl))
            print(videoUrl, "type: \(type(of: videoUrl))")
        }
        
        let movieAssets: [AVAsset] = avAssets
        
        // Create the mutable composition that we are going to build up.
        let composition = AVMutableComposition()
        
        buildCompositionTracks(composition: composition, videos: movieAssets)
        
        // Create the instructions for which movie to show and create the video composition.
        let videoComposition = buildVideoCompositionAndInstructions(composition: composition, assets: movieAssets)

        let exporter = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        )
        
        exporter?.outputURL = outputURL(ext: "mp4")
        exporter?.videoComposition = videoComposition
        exporter?.outputFileType = AVFileType.mp4
        exporter?.shouldOptimizeForNetworkUse = true
        
        activityIndicator.startAnimating()
        exporter?.exportAsynchronously {
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                
                self.mergedVideoUrl = exporter?.outputURL
            }
        }
    }

    @IBAction func showMergedVideo(_ sender: Any) {
        showVideo(url: mergedVideoUrl)
    }

    @IBAction func downloadMergedVideo(_ sender: Any) {
        downloadVideo(url: mergedVideoUrl)
    }

    @IBAction func applyFilterAndShowVideo(_ sender: Any) {
        applyingFilter(url: mergedVideoUrl)
    }
    
    private func applyingFilter(url: URL?) {
        guard let url = url else { return }
        let videoAsset = AVAsset(url: url)

        let filter = CIFilter(name: "CIColorInvert")! // CIFilter(name: "CIGaussianBlur")!
        let composition = AVVideoComposition(asset: videoAsset, applyingCIFiltersWithHandler: { request in

            let source = request.sourceImage.clampedToExtent()
            filter.setValue(source, forKey: kCIInputImageKey)

////            // Vary filter parameters based on video timing
//            let seconds = CMTimeGetSeconds(request.compositionTime)
//            filter.setValue(seconds * 10.0, forKey: kCIInputRadiusKey)
            
            // Crop the invert output to the bounds of the original image
            let output = filter.outputImage!.cropped(to: request.sourceImage.extent)

            // Provide the filter output to the composition
            request.finish(with: output, context: nil)
        })
        // play video with AVPlayer
        let playerItem = AVPlayerItem(asset: videoAsset)
        playerItem.videoComposition = composition
        let player = AVPlayer(playerItem: playerItem)
        let vcPlayer = AVPlayerViewController()
        vcPlayer.player = player
        present(vcPlayer, animated: true, completion: nil)
    }
    
    func downloadVideo(url: URL?) {
//       let sampleURL = "http://commondatastorage.googleapis.com/gtv-videosbucket/sample/ElephantsDream.mp4"
        DispatchQueue.global(qos: .background).async {
            if let url = url, let urlData = NSData(contentsOf: url) {
//          if let url = URL(string: sampleURL), let urlData = NSData(contentsOf: url) {
                let galleryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                let filePath = "\(galleryPath)/merged.mp4"
                DispatchQueue.main.async {
                    urlData.write(toFile: filePath, atomically: true)
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL:
                            URL(fileURLWithPath: filePath))
                    }) {
                        success, error in
                        if success {
                            print("Succesfully Saved")
                        } else {
                            print(error?.localizedDescription as Any)
                        }
                    }
                }
            }
        }
    }
    
    private func showVideo(url: URL?) {
        if let url = url {
            print("url: \(url), type: \(type(of: url))")
            let player = AVPlayer(url: url)
            let vcPlayer = AVPlayerViewController()
            vcPlayer.player = player
            present(vcPlayer, animated: true, completion: nil)
        }
    }
    
    private func outputURL(ext: String) -> URL? {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory,
                                                               in: .userDomainMask).first
        else {
            return nil
        }
        return documentDirectory.appendingPathComponent("mergeVideo-\(Date.timeIntervalSinceReferenceDate).\(ext)")
    }

    // Function to build the composition tracks.
    private func buildCompositionTracks(composition: AVMutableComposition,
                                        videos: [AVAsset])
    {
        let videoTrackA = composition.addMutableTrack(
            withMediaType: AVMediaType.video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        let videoTrackB = composition.addMutableTrack(
            withMediaType: AVMediaType.video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        let videoTracks = [videoTrackA, videoTrackB]
        
        var audioTrackA: AVMutableCompositionTrack?
        var audioTrackB: AVMutableCompositionTrack?
        
        var cursorTime = CMTime.zero
        
        var index = 0
        videos.forEach { asset in
            do {
                let trackIndex = index % 2
                let currentVideoTrack = videoTracks[trackIndex]
                
                if TRANSITION_DURATION <= asset.duration {
                    let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
                    try currentVideoTrack?.insertTimeRange(
                        timeRange,
                        of: asset.tracks(withMediaType: AVMediaType.video)[0],
                        at: cursorTime
                    )
                    if let audioAssetTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
                        var currentAudioTrack: AVMutableCompositionTrack?
                        switch trackIndex {
                        case 0:
                            if audioTrackA == nil {
                                audioTrackA = composition.addMutableTrack(
                                    withMediaType: AVMediaType.audio,
                                    preferredTrackID: kCMPersistentTrackID_Invalid
                                )
                            }
                            currentAudioTrack = audioTrackA
                        case 1:
                            if audioTrackB == nil {
                                audioTrackB = composition.addMutableTrack(
                                    withMediaType: AVMediaType.audio,
                                    preferredTrackID: kCMPersistentTrackID_Invalid
                                )
                            }
                            currentAudioTrack = audioTrackB
                        default:
                            print("MovieTransitionsVC " + #function + ": Only two audio tracks were expected")
                        }
                        try currentAudioTrack?.insertTimeRange(
                            CMTimeRangeMake(start: CMTime.zero, duration: asset.duration),
                            of: audioAssetTrack,
                            at: cursorTime
                        )
                    }
                    // Overlap clips by tranition duration
                    cursorTime = CMTimeAdd(cursorTime, asset.duration)
                    cursorTime = CMTimeSubtract(cursorTime, TRANSITION_DURATION)
                }
            } catch {
                // Could not add track
                print("MovieTransitionsVC " + #function + ": " + error.localizedDescription)
            }
            index += 1
        }
    }

    // Function to calculate both the pass through time and the transition time ranges
    private func calculateTimeRanges(assets: [AVAsset])
        -> (passThroughTimeRanges: [NSValue], transitionTimeRanges: [NSValue])
    {
        var passThroughTimeRanges = [NSValue]()
        var transitionTimeRanges = [NSValue]()
        var cursorTime = CMTime.zero
            
        for i in 0...(assets.count - 1) {
            let asset = assets[i]
            if TRANSITION_DURATION <= asset.duration {
                var timeRange = CMTimeRangeMake(start: cursorTime, duration: asset.duration)
                    
                if i > 0 {
                    timeRange.start = CMTimeAdd(timeRange.start, TRANSITION_DURATION)
                    timeRange.duration = CMTimeSubtract(timeRange.duration, TRANSITION_DURATION)
                }
                    
                if i + 1 < assets.count {
                    timeRange.duration = CMTimeSubtract(timeRange.duration, TRANSITION_DURATION)
                }
                    
                passThroughTimeRanges.append(NSValue(timeRange: timeRange))
                    
                cursorTime = CMTimeAdd(cursorTime, asset.duration)
                cursorTime = CMTimeSubtract(cursorTime, TRANSITION_DURATION)
                    
                if i + 1 < assets.count {
                    timeRange = CMTimeRangeMake(start: cursorTime, duration: TRANSITION_DURATION)
                    transitionTimeRanges.append(NSValue(timeRange: timeRange))
                }
            }
        }
        return (passThroughTimeRanges, transitionTimeRanges)
    }
    
    // Build the video composition and instructions.
    private func buildVideoCompositionAndInstructions(
        composition: AVMutableComposition, assets: [AVAsset]
    ) -> AVMutableVideoComposition {
        // Create the passthrough and transition time ranges.
        let timeRanges = calculateTimeRanges(assets: assets)
        
        // Create a mutable composition instructions object
        var compositionInstructions = [AVMutableVideoCompositionInstruction]()
        
        // Get the list of asset tracks and tell compiler they are a list of asset tracks.
        let tracks = composition.tracks(withMediaType: AVMediaType.video) as [AVAssetTrack]
        
        // Create a video composition object
        let videoComposition = AVMutableVideoComposition(propertiesOf: composition)
        
        for i in 0...(timeRanges.passThroughTimeRanges.count - 1) {
            let trackIndex = i % 2
            let currentTrack = tracks[trackIndex]
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = timeRanges.passThroughTimeRanges[i].timeRangeValue
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                assetTrack: currentTrack)
            instruction.layerInstructions = [layerInstruction]
            
            compositionInstructions.append(instruction)
            
            if i < timeRanges.transitionTimeRanges.count {
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRanges.transitionTimeRanges[i].timeRangeValue
                
                // Determine the foreground and background tracks.
                let fgTrack = tracks[trackIndex]
                let bgTrack = tracks[1 - trackIndex]
                
                // Create the "from layer" instruction.
                let fLInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: fgTrack)
                
                // Make the opacity ramp and apply it to the from layer instruction.
                fLInstruction.setOpacityRamp(fromStartOpacity: 1.0, toEndOpacity: 0.0,
                                             timeRange: instruction.timeRange)
                
                let tLInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: bgTrack)
                
                instruction.layerInstructions = [fLInstruction, tLInstruction]
                compositionInstructions.append(instruction)
            }
        }
        videoComposition.instructions = compositionInstructions
        return videoComposition
    }
}
