// Copyright © 2018 INLOOPX. All rights reserved.

import UIKit
import AVFoundation

final class LivePhotoCameraCell: CameraCollectionViewCell {
  @IBOutlet weak var snapButton: UIButton!
  @IBOutlet weak var enableLivePhotosButton: StationaryButton!
  @IBOutlet weak var cameraPermission: UIButton!
  @IBOutlet weak var liveIndicator: CarvedLabel!

  override func awakeFromNib() {
    super.awakeFromNib()
    liveIndicator.alpha = 0
    liveIndicator.tintColor = UIColor(red: 245/255, green: 203/255, blue: 47/255, alpha: 1)

    enableLivePhotosButton.unselectedTintColor = .white
    enableLivePhotosButton.selectedTintColor = UIColor(red: 245/255, green: 203/255, blue: 47/255, alpha: 1)
    self.cameraPermission.isHidden = AVCaptureDevice.authorizationStatus(for: AVMediaType.video) ==  AVAuthorizationStatus.authorized
    self.cameraPermission.setTitle(NSLocalizedString("enableCameraPermission", comment: ""), for: .normal)
  }

  @IBAction func snapButtonTapped(_ sender: UIButton) {
    if enableLivePhotosButton.isSelected {
      takeLivePhoto()
    } else {
      takePicture()
    }
  }

  @IBAction func flipButtonTapped(_ sender: UIButton) {
    flipCamera()
  }

  func updateWithCameraMode(_ mode: CaptureSettings.CameraMode) {
    switch mode {
    case .photo:
      liveIndicator.isHidden = true
      enableLivePhotosButton.isHidden = true
    case .photoAndLivePhoto:
      liveIndicator.isHidden = false
      enableLivePhotosButton.isHidden = false
    default:
      fatalError("Image Picker - unsupported camera mode for \(type(of: self))")
    }
  }

  @IBAction func cameraPermissionAction(_ sender: Any) {
    if let url = URL(string:UIApplication.openSettingsURLString) {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
    }
  }

  override func updateLivePhotoStatus(isProcessing: Bool, shouldAnimate: Bool) {
    let updates = {
      self.liveIndicator.alpha = isProcessing ? 1 : 0
    }

    if shouldAnimate {
      UIView.animate(withDuration: 0.25, animations: updates)
    } else {
      updates()
    }
  }
}
