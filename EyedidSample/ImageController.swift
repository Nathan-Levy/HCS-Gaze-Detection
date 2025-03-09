//
//  Image.swift
//  EyedidSample
//
//  Created by Nathan Levy on 09/03/2025.
//

import UIKit
import AVFoundation
import Eyedid

class ImageController: UIViewController {

    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var stopBtn: UIButton!
    @IBOutlet weak var caliBtn: UIButton!
    @IBOutlet weak var homeBtn: UIButton!
    @IBOutlet weak var versionLabel: UILabel!

    var tracker: GazeTracker?
    let license: String = "dev_gu8vkaqajvi4b62kr08z5s77gt7aoq0tbrixntg5"

    let pointView: PointView = PointView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    let calibrationPointView: CalibrationPointView = CalibrationPointView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))

    // MARK: - Image & Target Region
    var imageView: UIImageView!
    
    // The bounding box (in the image’s coordinate space) that the user must look at:
    // You’ll need to adjust these values to exactly cover the wolf in the water region.
    var targetRect = CGRect(x: 220, y: 650, width: 100, height: 80)
    
    // Dwell detection properties
    var dwellTimer: Timer?
    var isGazingAtWolf = false

    // New properties for verification timing
    var verificationTimeoutTimer: Timer?
    var isVerified: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        versionLabel.text = "Version: \(GazeTracker.getFrameworkVersion())"
        checkCameraAuthorizationStatus()

        startBtn.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        stopBtn.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        caliBtn.addTarget(self, action: #selector(caliButtonTapped), for: .touchUpInside)
        homeBtn.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)

        startBtn.isEnabled = false
        stopBtn.isEnabled = false
        caliBtn.isEnabled = false
        homeBtn.isEnabled = false

        // Add the gaze point and calibration views
        view.addSubview(pointView)
        view.addSubview(calibrationPointView)
        pointView.isHidden = true
        calibrationPointView.isHidden = true
        
        // Set up the image
        setupImageView()

        // Bring the gaze indicator to the front
        view.bringSubviewToFront(pointView)
    }
    

    func setupImageView() {
        // Create the imageView to fill the screen
        imageView = UIImageView(frame: view.bounds)
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "WolfMoonSample")
        view.addSubview(imageView)
        view.sendSubviewToBack(imageView)
        
//        // Ensure we have an image to work with
//        guard let image = imageView.image else { return }
//
//        // Calculate the scale factor and image frame in the imageView
//        let imageSize = image.size
//        let imageViewSize = imageView.bounds.size
//        let scale = min(imageViewSize.width / imageSize.width, imageViewSize.height / imageSize.height)
//        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
//        let imageOrigin = CGPoint(
//            x: (imageViewSize.width - scaledImageSize.width) / 2,
//            y: (imageViewSize.height - scaledImageSize.height) / 2
//        )
//        let imageFrame = CGRect(origin: imageOrigin, size: scaledImageSize)
        
        
        // Convert the targetRect (defined in image coordinates) to imageView coordinates.
        // This assumes that targetRect is defined relative to the original image size.
        let targetRectInImageView = CGRect(
            x: 220,
            y: 650,
            width: 100,
            height: 80
        )
        
        print("imageView frame: \(imageView.frame)")
        print("targetRectInImageView: \(targetRectInImageView)")
        
        // Create a UIView (or UIButton) to represent the target box
        let targetView = UIView(frame: targetRectInImageView)
        targetView.backgroundColor = UIColor.clear
        targetView.layer.borderColor = UIColor.red.cgColor
        targetView.layer.borderWidth = 2
        imageView.addSubview(targetView)
    }

    // MARK: - Dwell-based Authentication
    func handleGazeForImageAuth() {
        guard !imageView.isHidden else { return }
        
        // Convert the gaze point from the main view’s coordinates to the imageView’s coordinates.
        let gazePointInImageView = imageView.convert(pointView.center, from: view)
        
        // If the gaze is inside the target rectangle...
        if targetRect.contains(gazePointInImageView) {
            // If we weren’t already dwelling on the target, start the dwell timer.
            if !isGazingAtWolf {
                isGazingAtWolf = true
                dwellTimer?.invalidate()
                // Set the dwell time to 3 seconds
                dwellTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    // The user has looked at the target region for 3 seconds.
                    self.isVerified = true
                    self.authenticationSuccess()  // This will flash green.
                    // Invalidate the timeout timer since we are verified.
                    self.verificationTimeoutTimer?.invalidate()
                }
            }
        } else {
            // If the gaze moves out of the target, cancel the dwell timer.
            isGazingAtWolf = false
            dwellTimer?.invalidate()
            dwellTimer = nil
        }
    }
    
    func authenticationSuccess() {
        // Example: Flash screen green, or show an alert, etc.
        print("Authenticated: user gazed at the wolf!")
        flashScreen(color: .green)
    }
    
    func flashScreen(color: UIColor) {
        let originalColor = view.backgroundColor
        view.backgroundColor = color
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.view.backgroundColor = originalColor
        }
    }

    // MARK: - Camera & Gaze Tracking
    func checkCameraAuthorizationStatus() {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraAuthorizationStatus {
        case .authorized:
            print("Camera access is authorized.")
            initGazeTracker()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.initGazeTracker()
                    print("Camera access granted.")
                } else {
                    print("Camera access denied.")
                }
            }
        case .denied, .restricted:
            print("Camera access is denied or restricted.")
            showSettingsAlert()
        @unknown default:
            fatalError("Unknown authorization status.")
        }
    }
    
    func initGazeTracker() {
        GazeTracker.initGazeTracker(license: license, delegate: self)
    }
    
    func showSettingsAlert() {
        let alert = UIAlertController(title: "Camera Access Needed",
                                      message: "Please allow camera access in settings to use the camera.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:])
            }
        }))
        present(alert, animated: true)
    }

    // MARK: - Button Actions
    @objc func startButtonTapped() {
        print("Start button tapped.")
        tracker?.startTracking()
    }
    
    @objc func stopButtonTapped() {
        print("Stop button tapped.")
        tracker?.stopTracking()
    }
    
    @objc func caliButtonTapped() {
        print("Calibration button tapped.")
        // Hide the image or other UI elements if needed during calibration.
        imageView.isHidden = true
        
        tracker?.startCalibration(mode: .fivePoint, criteria: .default, region: UIScreen.main.bounds)
        pointView.isHidden = true
        startBtn.isHidden = true
        stopBtn.isHidden = true
        caliBtn.isHidden = true
        homeBtn.isHidden = true
        versionLabel.isHidden = true
    }
    
  @objc func homeButtonTapped(_ sender: Any) {
     let storyboard = UIStoryboard(name: "Main", bundle: nil)
     guard let VC = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController else {
       return
     }
     VC.modalPresentationStyle = .fullScreen
     self.present(VC, animated: true, completion: nil)
  }
}

// MARK: - Extensions for GazeTracker Delegates
extension ImageController: InitializationDelegate, TrackingDelegate, CalibrationDelegate, StatusDelegate {
    
    func onInitialized(tracker: GazeTracker?, error: InitializationError) {
        if error == .errorNone {
            self.tracker = tracker
            self.tracker?.trackingDelegate = self
            self.tracker?.calibrationDelegate = self
            self.tracker?.statusDelegate = self
            startBtn.isEnabled = true
            homeBtn.isEnabled = true
        } else {
            print("Initialization error: \(error)")
        }
    }
    
    func onMetrics(timestamp: Int, gazeInfo: GazeInfo, faceInfo: FaceInfo, blinkInfo: BlinkInfo, userStatusInfo: UserStatusInfo) {
        DispatchQueue.main.async {
            if gazeInfo.trackingState == .success && self.tracker?.isCalibrating() == false {
                // Move the pointView to the user’s current gaze point
                self.pointView.center = CGPoint(x: CGFloat(gazeInfo.x), y: CGFloat(gazeInfo.y))
            }
            // Only check authentication if not calibrating
            if self.tracker?.isCalibrating() == false {
                self.imageView.isHidden = false
                self.pointView.isHidden = false
                self.handleGazeForImageAuth()
            }
        }
    }
    
    func onCalibrationNextPoint(x: Double, y: Double) {
        calibrationPointView.reset(to: .blue)
        calibrationPointView.movePoistion(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
        calibrationPointView.setProgress(progress: 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.calibrationPointView.isHidden = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.tracker?.startCollectSamples()
        }
    }
    
    func onCalibrationProgress(progress: Double) {
        calibrationPointView.setProgress(progress: progress)
    }
    
    func onCalibrationFinished(calibrationData: [Double]) {
        calibrationPointView.isHidden = true
        pointView.isHidden = false
        
        startBtn.isHidden = false
        stopBtn.isHidden = false
        caliBtn.isHidden = false
        homeBtn.isHidden = false
        versionLabel.isHidden = false
        
        // Show the image again after calibration
        imageView.isHidden = false
        
        // Reset verification flag
        isVerified = false
        
        // Start the timeout timer for 5 seconds.
        verificationTimeoutTimer?.invalidate()
        verificationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // If the user hasn't been verified within 5 seconds, flash red.
            if !self.isVerified {
                self.flashScreen(color: .red)
            }
        }
    }
    
    func onStarted() {
        stopBtn.isEnabled = true
        startBtn.isEnabled = false
        caliBtn.isEnabled = true
        pointView.isHidden = false
        homeBtn.isEnabled = true
    }
    
    func onStopped(error: StatusError) {
        startBtn.isEnabled = true
        stopBtn.isEnabled = false
        caliBtn.isEnabled = false
        homeBtn.isEnabled = true
    }
}
