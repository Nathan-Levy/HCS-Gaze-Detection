//
//  DirectionBasedController.swift
//  EyedidSample
//
//  Created by Nathan Levy on 05/03/2025.
//

import UIKit
import AVFoundation
import Eyedid

enum Direction: String {
    case up, down, left, right, none
}

class DirectionBasedController: UIViewController {

  @IBOutlet weak var startBtn: UIButton!
  @IBOutlet weak var stopBtn: UIButton!
  @IBOutlet weak var caliBtn: UIButton!
  @IBOutlet weak var versionLabel: UILabel!
  @IBOutlet weak var homeBtn: UIButton!
  @IBOutlet weak var upArrow: UILabel!
  @IBOutlet weak var downArrow: UILabel!
  @IBOutlet weak var leftArrow: UILabel!
  @IBOutlet weak var rightArrow: UILabel!
  
  var tracker: GazeTracker?
  // TODO: change licence key
  let license: String = "dev_gu8vkaqajvi4b62kr08z5s77gt7aoq0tbrixntg5"

  let pointView: PointView = PointView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
  let calibrationPointView: CalibrationPointView = CalibrationPointView(frame: CGRect(x: 0, y: 0, width: 90, height: 90))

  var index = 0
  let colorList: [UIColor] = [UIColor.red, UIColor.blue, UIColor.green, UIColor.orange, UIColor.cyan]

  let semaphore = DispatchSemaphore(value: 1)
  var isMove: Bool = false

  // MARK: - Directional Input Properties
  var deadzoneView: UIView!   // Central deadzone view
  let deadzoneSize: CGFloat = 150  // (Not used directly, using a custom size below)

  // State for directional input via gaze:
  var canRecordNextDirection: Bool = false
  var currentGazeDirection: Direction = .none
  var dwellTimer: Timer?
  var inputSequence: [Direction] = []
    let requiredSequence: [Direction] = [.up, .up, .right, .left, .down, .down]
    
    var authenticationStartTime: Date?

  // Dot views for sequence display
  var dotViews: [UIView] = []

  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Set a black background to match your wireframe.
    view.backgroundColor = .black
    
    versionLabel.text = "Version : \(GazeTracker.getFrameworkVersion())"
    checkCameraAuthorizationStatus()
    
    // Setup button actions
    startBtn.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
    stopBtn.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
    caliBtn.addTarget(self, action: #selector(caliButtonTapped), for: .touchUpInside)
    homeBtn.addTarget(self, action: #selector(homeButtonTapped(_:)), for: .touchUpInside)
    
    startBtn.isEnabled = false
    stopBtn.isEnabled = false
    caliBtn.isEnabled = false
    homeBtn.isEnabled = true
    
    // Add gaze point and calibration views
    view.addSubview(pointView)
    view.addSubview(calibrationPointView)
    pointView.isHidden = true
    calibrationPointView.isHidden = true
    
    // Build the stylized UI:
    setupCenterDeadzone()
    setupSequenceDots()
    
    // Bring the gaze indicator to the front
    self.view.bringSubviewToFront(pointView)
  }
    
    func showAuthenticationPopup(timeElapsed: Double) {
        // Create the alert controller
        let alert = UIAlertController(
            title: "Authentication Successful",
            message: String(format: "Authentication Time: %.2f sec", timeElapsed),
            preferredStyle: .alert
        )

        // Add a dismiss button
        let dismissAction = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
        alert.addAction(dismissAction)

        // Present the alert on the main thread to ensure UI updates properly
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
  // MARK: - UI Setup Methods
  
  func setupCenterDeadzone() {
    // Create a circular deadzone in the center
    let size: CGFloat = 100  // Adjust as needed
    deadzoneView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
    deadzoneView.center = view.center
    deadzoneView.backgroundColor = .clear
    deadzoneView.layer.cornerRadius = size / 2
    deadzoneView.layer.borderColor = UIColor.white.cgColor
    deadzoneView.layer.borderWidth = 3
    view.addSubview(deadzoneView)
    
    // Allow input when the user is in the center
    canRecordNextDirection = true
  }
    
    
  func setupSequenceDots() {
    let dotSize: CGFloat = 20
    let totalDots = 6
    let spacing: CGFloat = 20
    let totalWidth = (CGFloat(totalDots) * dotSize) + (CGFloat(totalDots - 1) * spacing)
    let startX = (view.bounds.width - totalWidth) / 2
    let yPosition: CGFloat = 80  // from the top
    
    for i in 0..<totalDots {
        let dot = UIView(frame: CGRect(x: startX + CGFloat(i) * (dotSize + spacing),
                                       y: yPosition,
                                       width: dotSize,
                                       height: dotSize))
        dot.backgroundColor = .clear
        dot.layer.cornerRadius = dotSize / 2
        dot.layer.borderWidth = 2
        dot.layer.borderColor = UIColor.white.cgColor
        view.addSubview(dot)
        dotViews.append(dot)
    }
  }
  
  // MARK: - Gaze-Driven Directional Input
  
  func handleGazeForDirectionalInput() {
    updateGazeIndicator()
    // Process directional input only if the deadzone is present.
    guard deadzoneView != nil, !deadzoneView.isHidden else { return }
    
    // Get current gaze point (in view's coordinate system)
    let gazePoint = pointView.center
    let center = view.center
    
    // Check if gaze is within the deadzone.
    if deadzoneView.frame.contains(gazePoint) {
      canRecordNextDirection = true
      if currentGazeDirection != .none {
        currentGazeDirection = .none
        dwellTimer?.invalidate()
        dwellTimer = nil
      }
      return
    }
    
    // Only record new input if user returned to center.
    guard canRecordNextDirection else { return }
    
    let dx = gazePoint.x - center.x
    let dy = gazePoint.y - center.y
    var detectedDirection: Direction = .none
    
    if abs(dx) > abs(dy) {
      detectedDirection = dx > 0 ? .right : .left
    } else {
      detectedDirection = dy > 0 ? .down : .up
    }
    
    // Start a dwell timer if this is a new direction candidate.
    if currentGazeDirection == .none || currentGazeDirection != detectedDirection {
      currentGazeDirection = detectedDirection
      dwellTimer?.invalidate()
      dwellTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
        guard let self = self else { return }
        // Record the detected direction.
        self.inputSequence.append(detectedDirection)
        print("Direction \(detectedDirection.rawValue) recorded")
        
        // Update the corresponding dot.
        let index = self.inputSequence.count - 1
        if index >= 0 && index < self.dotViews.count {
            self.dotViews[index].backgroundColor = .white
        }
        
        // Disable further input until user returns to center.
        self.canRecordNextDirection = false
        self.currentGazeDirection = .none
        self.dwellTimer = nil
        
        // Check if the complete sequence is entered.
        self.checkInputSequence()
      }
    }
  }
    
  func updateGazeIndicator() {
    // pointView.center is updated based on gaze
    if deadzoneView.frame.contains(pointView.center) {
        pointView.isHidden = false
    } else {
        pointView.isHidden = true
    }
  }
  
    func checkInputSequence() {
        if inputSequence.count == requiredSequence.count {
            if inputSequence == requiredSequence {
                print("Correct sequence!")
                flashScreenGreen()

                // **Calculate authentication time**
                if let startTime = authenticationStartTime {
                    let elapsedTime = Date().timeIntervalSince(startTime) // Time in seconds
                    print("Authentication successful! Time taken: \(elapsedTime) seconds")

                    // **Show the popup**
                    showAuthenticationPopup(timeElapsed: elapsedTime)
                }
            } else {
                print("Incorrect sequence. Try again.")
                flashScreenRed()
            }
            
            // Reset sequence and dots for the next attempt.
            inputSequence.removeAll()
            resetDots()
        }
    }
  
  func resetDots() {
    for dot in dotViews {
      dot.backgroundColor = .clear
    }
  }
  
  func flashScreenGreen() {
    let originalColor = view.backgroundColor
    view.backgroundColor = UIColor.green
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.view.backgroundColor = originalColor
    }
  }
  
  func flashScreenRed() {
    let originalColor = view.backgroundColor
    view.backgroundColor = UIColor.red
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
        self.initGazeTracker()
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
  
  func showSettingsAlert() {
    let alert = UIAlertController(title: "Camera Access Needed",
                                  message: "Please allow camera access in settings to use the camera.",
                                  preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: { _ in
      if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
      }
    }))
    present(alert, animated: true, completion: nil)
  }
  
  func initGazeTracker() {
    GazeTracker.initGazeTracker(license: license, delegate: self)
  }
  
  @objc func startButtonTapped() {
    print("Start button tapped.")
    self.tracker?.startTracking()
  }
  
  @objc func stopButtonTapped() {
    print("Stop button tapped.")
    self.tracker?.stopTracking()
  }
  
  @objc func caliButtonTapped() {
    print("Calibration button tapped.")
    self.tracker?.startCalibration(mode: .fivePoint, criteria: .default, region: UIScreen.main.bounds)
    pointView.isHidden = true
    startBtn.isHidden = true
    stopBtn.isHidden = true
    caliBtn.isHidden = true
    homeBtn.isHidden = true
    versionLabel.isHidden = true
    upArrow.isHidden = true
    downArrow.isHidden = true
    leftArrow.isHidden = true
    rightArrow.isHidden = true
    deadzoneView.isHidden = true
  }

  @objc func homeButtonTapped(_ sender: Any) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let VC = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController else {
      return
    }
    VC.modalPresentationStyle = .fullScreen
    self.present(VC, animated: true, completion: nil)
  }
  
  func showErrorAlert(message: String) {
    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    present(alert, animated: true, completion: nil)
  }
}

extension DirectionBasedController: InitializationDelegate, TrackingDelegate, CalibrationDelegate, StatusDelegate {
    
  func onInitialized(tracker: GazeTracker?, error: InitializationError) {
    if error == .errorNone {
      self.tracker = tracker
      self.tracker?.trackingDelegate = self
      self.tracker?.calibrationDelegate = self
      self.tracker?.statusDelegate = self
      self.startBtn.isEnabled = true
    } else {
      showErrorAlert(message: error.description)
    }
  }
    
  func onMetrics(timestamp: Int, gazeInfo: GazeInfo, faceInfo: FaceInfo, blinkInfo: BlinkInfo, userStatusInfo: UserStatusInfo) {
    DispatchQueue.main.async {
      if gazeInfo.trackingState == .success && self.tracker?.isCalibrating() == false {
        self.pointView.center = CGPoint(x: CGFloat(gazeInfo.x), y: CGFloat(gazeInfo.y))
      }
    }
    if self.tracker?.isCalibrating() == false {
      self.handleGazeForDirectionalInput()
    }
  }
    
  func onCalibrationNextPoint(x: Double, y: Double) {
    self.calibrationPointView.reset(to: self.colorList[self.index])
    self.calibrationPointView.movePoistion(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
    self.calibrationPointView.setProgress(progress: 0)
    self.index += 1

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      self.calibrationPointView.isHidden = false
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
      self.tracker?.startCollectSamples()
    }
  }
    
  func onCalibrationProgress(progress: Double) {
    self.calibrationPointView.setProgress(progress: progress)
  }
    
  func onCalibrationFinished(calibrationData: [Double]) {
    self.calibrationPointView.isHidden = true
    self.pointView.isHidden = false
    self.startBtn.isHidden = false
    self.stopBtn.isHidden = false
    self.caliBtn.isHidden = false
    self.homeBtn.isHidden = false
    self.versionLabel.isHidden = false
    self.deadzoneView.isHidden = false
    self.upArrow.isHidden = false
    self.downArrow.isHidden = false
    self.leftArrow.isHidden = false
    self.rightArrow.isHidden = false
    self.resetDots()
    self.inputSequence.removeAll()
    self.index = 0
      
    // **Start the authentication timer NOW**
    authenticationStartTime = Date()
  }
    
  func onStarted() {
    self.stopBtn.isEnabled = true
    self.startBtn.isEnabled = false
    self.caliBtn.isEnabled = true
    self.pointView.isHidden = false
    self.homeBtn.isHidden = false
  }
    
  func onStopped(error: StatusError) {
    self.startBtn.isEnabled = true
    self.stopBtn.isEnabled = false
    self.caliBtn.isEnabled = false
    self.homeBtn.isEnabled = true
  }
}
