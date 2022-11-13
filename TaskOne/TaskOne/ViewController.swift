//
//  ViewController.swift
//  TaskOne
//
//  Created by Softzino MBP 302 on 11/8/22.
//

import PhotosUI
import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController, AVPlayerViewControllerDelegate {
    private var selectedImages: [UIImage] = []
    private var selectedVideos: [URL] = []

    var playerController = AVPlayerViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    private func presentPicker() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = 0
        configuration.preferredAssetRepresentationMode = .automatic
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction func OpenGallery(_ sender: UIButton) {
        let actionSheet = UIAlertController(title: "Open Gallery", message: "Open Gallery to select images and videos", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Gallery", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            print("Here set photo picker controller")
            self.presentPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        self.present(actionSheet, animated: true)
    }

    @IBAction func showCreatedVideo(_ sender: Any) {
        
        if selectedImages.count > 1 {
            DispatchQueue.main.async {
                let settings = RenderSettings()
                let imageAnimator = ImageAnimator(renderSettings: settings, imageArr: self.selectedImages)
                imageAnimator.render {
                    self.displayVideo(urlString: tempUrl)
                }
            }
        } else {
            self.showAlert(title: "Warning!", message: "Please select two or more Photos first.")
        }
    }

    func displayVideo(urlString: String) {
        
        let player = AVPlayer(url: URL(fileURLWithPath: urlString))
        playerController = AVPlayerViewController()
        playerController.player = player
        playerController.allowsPictureInPicturePlayback = true
        playerController.delegate = self
//        playerController.player?.play()
        
        let asset = AVAsset(url: URL(fileURLWithPath: urlString))
        let duration = asset.duration
        let durationTime = CMTimeGetSeconds(duration)
        
        print(durationTime)
        
        self.present(playerController, animated: true)
    }
    
    // transitions
    @IBAction func VideoTransitions(_ sender: Any) {
        
        if selectedVideos.count > 1 {
            let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
            if let vc = mainStoryboard.instantiateViewController(withIdentifier: "MovieTransitionsVC") as? MovieTransitionsVC {
                vc.videoUrls = self.selectedVideos
                self.present(vc, animated: true)
            }
        } else {
            self.showAlert(title: "Warning!", message: "Please select two or more videos first.")
        }
    }
    
}

extension ViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        
//        self.selectedImages.removeAll()
//        self.selectedVideos.removeAll()

        dismiss(animated: true)
        
        let itemProviders = results.map(\.itemProvider)
        print(itemProviders)
        for item in itemProviders {
            if item.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                print("Image section")
                item.loadObject(ofClass: UIImage.self) { [weak self] image, error in

                    if let error = error {
                        print("ERROR:", error)
                        return
                    }

                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if let image = image as? UIImage {
                            // Access your image
                            self.selectedImages.append(image)
                            print("image: ", image)
                            print("\(self.selectedImages.count) image select")
                        }
                    }
                }
            }
            if item.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                
                item.loadItem(forTypeIdentifier: "public.movie", options: nil) { [weak self] url, error in
            
                    if let error = error {
                        print("ERROR:", error)
                        return
                    }

                    guard let self = self else { return }

                    if let url = url {
                        // ok but there's a problem: the file wants to be deleted
                        // so I use `main.sync` to pin it down long enough to configure the presentation
                        DispatchQueue.main.sync {
                            // this type is private but I don't see how else to know it loops
                            let loopType = "com.apple.private.auto-loop-gif"
                            if item.hasItemConformingToTypeIdentifier(loopType) {
                                print("looping movie")
                            } else {
                                print("normal movie")
                                self.selectedVideos.append(url as! URL)
                                print("selected video url: \(url)")
                                print("\(self.selectedVideos.count) video select")
                            }
                        }
                    }
                }
            }
        }
    }
}


extension UIViewController {
  func showAlert(title: String, message: String) {
    let alertController = UIAlertController(title: title, message:
      message, preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: {action in
    }))
    self.present(alertController, animated: true, completion: nil)
  }
}
