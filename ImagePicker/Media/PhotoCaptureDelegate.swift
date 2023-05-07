// Copyright © 2018 INLOOPX. All rights reserved.

import AVFoundation
import Photos
import CoreMotion

final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
	
    deinit {
        log("deinit: \(String(describing: self))")
    }
    
    // MARK: Public Methods
    
    /// set this to false if you dont wish to save taken picture to photo library
    var savesPhotoToLibrary = true
    
    /// this contains photo data when taken
    private(set) var photoData: Data? = nil
    
    /// this contains live photo url
    private(set) var livePhotoCompanionMovieURL: URL? = nil
    
    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    /// not nil if error occured during capturing
    private(set) var processError: Error?
    
    // MARK: Private Methods
    
	private let willCapturePhotoAnimation: () -> ()
	private let capturingLivePhoto: (Bool) -> ()
	private let completed: (PhotoCaptureDelegate) -> ()
  private let motionManager = CMMotionManager()

	init(with requestedPhotoSettings: AVCapturePhotoSettings, willCapturePhotoAnimation: @escaping () -> (), capturingLivePhoto: @escaping (Bool) -> (), completed: @escaping (PhotoCaptureDelegate) -> ()) {
		self.requestedPhotoSettings = requestedPhotoSettings
		self.willCapturePhotoAnimation = willCapturePhotoAnimation
		self.capturingLivePhoto = capturingLivePhoto
		self.completed = completed
    self.motionManager.startAccelerometerUpdates()
	}
	
	private func didFinish() {
		if let livePhotoCompanionMoviePath = livePhotoCompanionMovieURL?.path {
			if FileManager.default.fileExists(atPath: livePhotoCompanionMoviePath) {
				do {
					try FileManager.default.removeItem(atPath: livePhotoCompanionMoviePath)
				}
				catch {
					log("photo capture delegate: Could not remove file at url: \(livePhotoCompanionMoviePath)")
				}
			}
		}
		
		completed(self)
	}
	
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
		if resolvedSettings.livePhotoMovieDimensions.width > 0 && resolvedSettings.livePhotoMovieDimensions.height > 0 {
			capturingLivePhoto(true)
		}
	}
	
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
		willCapturePhotoAnimation()
	}

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    guard let imageData = photo.fileDataRepresentation() else { return }
    
    let image = UIImage(data: imageData)
    let fixedImage = fixImageOrientation(image: image!)

    guard let rotatedImageData = dataFromRotatedImage(image: fixedImage) else { return }
    motionManager.stopAccelerometerUpdates()

    // Save the rotatedImageData to the asset
    let library = PHPhotoLibrary.shared()
    library.performChanges({
      let creationRequest = PHAssetCreationRequest.forAsset()
      creationRequest.addResource(with: .photo, data: rotatedImageData, options: nil)
    }, completionHandler: { (success, error) in
      if let error = error {
        self.processError = error
        print("Error: \(error.localizedDescription)")
      } else {
        self.photoData = rotatedImageData
        print("Photo added to the library successfully")
      }
    })
  }

  func deviceOrientationFromAccelerometer() -> UIDeviceOrientation {
      guard motionManager.isAccelerometerAvailable else {
          return .unknown
      }

      if let data = motionManager.accelerometerData {
          if data.acceleration.x >= 0.75 {
              return .landscapeLeft
          } else if data.acceleration.x <= -0.75 {
              return .landscapeRight
          } else if data.acceleration.y <= -0.75 {
              return .portrait
          } else if data.acceleration.y >= 0.75 {
              return .portraitUpsideDown
          }
      }

      return .unknown
  }

  func fixImageOrientation(image: UIImage) -> UIImage {
      let orientation = deviceOrientationFromAccelerometer()

      var rotationAngle: CGFloat = 0.0

      switch orientation {
      case .portrait:
          rotationAngle = 0.0
      case .landscapeRight:
          rotationAngle = -CGFloat.pi / 2
      case .portraitUpsideDown:
          rotationAngle = CGFloat.pi
      case .landscapeLeft:
          rotationAngle = CGFloat.pi / 2
      default:
          break
      }

      let imageSize = CGSize(width: image.size.height, height: image.size.width)
      UIGraphicsBeginImageContextWithOptions(imageSize, false, image.scale)
      let context = UIGraphicsGetCurrentContext()!

      context.translateBy(x: imageSize.width / 2, y: imageSize.height / 2)
      context.rotate(by: rotationAngle)
      context.translateBy(x: -image.size.width / 2, y: -image.size.height / 2)

      image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))

      let fixedImage = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()

      return fixedImage
  }

  func dataFromRotatedImage(image: UIImage) -> Data? {
      guard let imageData = image.jpegData(compressionQuality: 1.0) else {
          return nil
      }
      return imageData
  }

    //this method is not called on iOS 11 if method above is implemented
//    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
//		if let photoSampleBuffer = photoSampleBuffer {
//
//            photoData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
//		}
//		else if let error = error {
//			log("photo capture delegate: error capturing photo: \(error)")
//            processError = error
//			return
//		}
//	}
	
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        capturingLivePhoto(false)
	}
	
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
		if let error = error {
			log("photo capture delegate: error processing live photo companion movie: \(error)")
			return
		}
		
		livePhotoCompanionMovieURL = outputFileURL
	}
	
    func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
		
        if let error = error {
			log("photo capture delegate: Error capturing photo: \(error)")
			didFinish()
			return
		}
		
		guard let photoData = photoData else {
			log("photo capture delegate: No photo data resource")
			didFinish()
			return
		}
		
        guard savesPhotoToLibrary == true else {
            log("photo capture delegate: photo did finish without saving to photo library")
            didFinish()
            return
        }
        
		PHPhotoLibrary.requestAuthorization { [unowned self] status in
			if status == .authorized {
				PHPhotoLibrary.shared().performChanges({ [unowned self] in
						let creationRequest = PHAssetCreationRequest.forAsset()
						creationRequest.addResource(with: .photo, data: photoData, options: nil)
					
						if let livePhotoCompanionMovieURL = self.livePhotoCompanionMovieURL {
							let livePhotoCompanionMovieFileResourceOptions = PHAssetResourceCreationOptions()
							livePhotoCompanionMovieFileResourceOptions.shouldMoveFile = true
							creationRequest.addResource(with: .pairedVideo, fileURL: livePhotoCompanionMovieURL, options: livePhotoCompanionMovieFileResourceOptions)
						}
					
                    }, completionHandler: { [unowned self] success, error in
						if let error = error {
							log("photo capture delegate: Error occurered while saving photo to photo library: \(error)")
						}
						
						self.didFinish()
					}
				)
			}
			else {
				self.didFinish()
			}
		}
	}
}
