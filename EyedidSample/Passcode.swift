//
//  Passcode.swift
//  EyedidSample
//
//  Created by Nathan Levy on 09/03/2025.
//

//
//  ViewController2.swift
//  EyedidSample
//
//  Created by Nathan Levy on 04/03/2025.
//

//
//  ViewController.swift
//  EyedidSample
//
//  Created by David on 10/18/24.
//

import UIKit
import AVFoundation
import Eyedid

class PasscodeController: UIViewController {

  @IBOutlet weak var startBtn: UIButton!
  @IBOutlet weak var stopBtn: UIButton!
  @IBOutlet weak var caliBtn: UIButton!
  @IBOutlet weak var versionLabel: UILabel!
  
  var tracker: GazeTracker?
  // TODO: change licence key
  let license : String = "dev_gu8vkaqajvi4b62kr08z5s77gt7aoq0tbrixntg5"

  let pointView : PointView = PointView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
  let calibrationPointView : CalibrationPointView = CalibrationPointView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))

  var index = 0
  let colorList : [UIColor] = [UIColor.red, UIColor.blue, UIColor.green, UIColor.orange, UIColor.cyan]

  let semaphore = DispatchSemaphore(value: 1)
  var isMove : Bool = false

  // MARK: - Passcode UI Properties
  var passcodeView: UIView!
  var passcodeLabel: UILabel!
  var passcodeInput: String = ""
    
  // MARK: - Gaze Dwell Detection Properties
  var currentGazedButton: UIButton?
  var dwellTimer: Timer?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    versionLabel.text = "Version : \(GazeTracker.getFrameworkVersion())"
    checkCameraAuthorizationStatus()

    startBtn.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
    stopBtn.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
    caliBtn.addTarget(self, action: #selector(caliButtonTapped), for: .touchUpInside)

    startBtn.isEnabled = false
    stopBtn.isEnabled = false
    caliBtn.isEnabled = false

    self.view.addSubview(pointView)
    self.view.addSubview(calibrationPointView)
    pointView.isHidden = true
    calibrationPointView.isHidden = true

    // Set up the passcode layout in the center of the screen.
    setupPasscodeView()
      
    self.view.bringSubviewToFront(pointView)
      
    setupExtraAuthButtons()
  }

  func setupExtraAuthButtons() {
    // Define button dimensions and spacing
    let buttonWidth: CGFloat = 120
    let buttonHeight: CGFloat = 40
    let spacing: CGFloat = 10
    
    // Calculate positions (example: bottom right corner)
    let startX = view.bounds.width - buttonWidth - spacing
    let firstY = view.bounds.height - (buttonHeight * 2 + spacing * 3)
    
    // Create a button for Direction-based Authentication
    let directionButton = UIButton(frame: CGRect(x: startX, y: firstY, width: buttonWidth, height: buttonHeight))
    directionButton.setTitle("Direction", for: .normal)
    directionButton.backgroundColor = .systemBlue
    directionButton.layer.cornerRadius = 5
    directionButton.addTarget(self, action: #selector(directionAuthTapped), for: .touchUpInside)
    view.addSubview(directionButton)
    
    // Create a button for Highlight Dots Authentication
    let dotsButton = UIButton(frame: CGRect(x: startX, y: firstY + buttonHeight + spacing, width: buttonWidth, height: buttonHeight))
    dotsButton.setTitle("Highlight Dots", for: .normal)
    dotsButton.backgroundColor = .systemGreen
    dotsButton.layer.cornerRadius = 5
    dotsButton.addTarget(self, action: #selector(dotsAuthTapped), for: .touchUpInside)
    view.addSubview(dotsButton)
    
    // Bring these buttons to the front (if needed)
    view.bringSubviewToFront(directionButton)
    view.bringSubviewToFront(dotsButton)
  }
    
  // MARK: - Passcode UI Setup
  func setupPasscodeView() {
    // Define the size of the passcode container
    let width: CGFloat = 250
    let height: CGFloat = 300
    passcodeView = UIView(frame: CGRect(x: (view.frame.width - width) / 2,
                                        y: (view.frame.height - height) / 2,
                                        width: width,
                                        height: height))
    passcodeView.backgroundColor = UIColor.systemGray6
    passcodeView.layer.cornerRadius = 10
    view.addSubview(passcodeView)
    
    // Create a label to display the passcode input
    passcodeLabel = UILabel(frame: CGRect(x: 0, y: 10, width: width, height: 40))
    passcodeLabel.textAlignment = .center
    passcodeLabel.font = UIFont.systemFont(ofSize: 24)
    passcodeLabel.text = "Enter Passcode"
    passcodeView.addSubview(passcodeLabel)
    
    // Define the button titles in a grid layout (for example, 3 columns)
    let buttonTitles = [
      ["1", "2", "3"],
      ["4", "5", "6"],
      ["7", "8", "9"],
      ["", "0", "⌫"]
    ]
    let buttonWidth = width / 3
    let buttonHeight: CGFloat = 50
    
    // Loop over the rows and columns to create the buttons
    for (rowIndex, row) in buttonTitles.enumerated() {
      for (colIndex, title) in row.enumerated() {
        let x = CGFloat(colIndex) * buttonWidth
        let y = 60 + CGFloat(rowIndex) * (buttonHeight + 10)
        let button = UIButton(frame: CGRect(x: x, y: y, width: buttonWidth, height: buttonHeight))
        button.setTitle(title, for: .normal)
        button.setTitleColor(.blue, for: .normal)
        button.backgroundColor = UIColor.white
        button.layer.cornerRadius = 5
        button.addTarget(self, action: #selector(passcodeButtonTapped(_:)), for: .touchUpInside)
        passcodeView.addSubview(button)
      }
    }
  }
  
  @objc func passcodeButtonTapped(_ sender: UIButton) {
    guard let title = sender.currentTitle else { return }
    
    if title == "⌫" {
      // Remove the last digit if available
      if !passcodeInput.isEmpty {
        passcodeInput.removeLast()
      }
    } else if title != "" {
      // Append digit to the input
      passcodeInput.append(title)
    }
    
    // Update the label (showing dots or the actual numbers is up to you)
    passcodeLabel.text = passcodeInput.isEmpty ? "Enter Passcode" : passcodeInput
    
    // For example, if a 4-digit passcode is required, check it here
    if passcodeInput.count == 4 {
      // Validate passcode; here "1234" is used as an example
      if passcodeInput == "1234" {
        print("Passcode correct!")
        // Optionally, hide the passcode view or transition to another screen
        passcodeView.isHidden = true
      } else {
        print("Incorrect passcode!")
        // Reset the input on error
        passcodeInput = ""
        passcodeLabel.text = "Enter Passcode"
      }
    }
  }
    
  // MARK: - Gaze-Driven Passcode Input
  // In the onMetrics callback below, after updating the gaze point, we determine whether the gaze falls over one of the passcode buttons.
  // If it does, we start a dwell timer. If the gaze stays on the same button for 0.5 seconds, we trigger the corresponding button tap.
  func handleGazeForPasscode() {
    // Only process if passcodeView is visible
    guard passcodeView != nil, !passcodeView.isHidden else { return }
    
    // Convert gaze point (in self.view coordinates) to passcodeView's coordinate system.
    let gazePointInPasscode = passcodeView.convert(pointView.center, from: view)
    
    var gazedButton: UIButton?
    for subview in passcodeView.subviews {
      if let button = subview as? UIButton, button.frame.contains(gazePointInPasscode) {
        gazedButton = button
        break
      }
    }
    
    if let button = gazedButton {
      if currentGazedButton != button {
        currentGazedButton = button
        dwellTimer?.invalidate()
        dwellTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
          guard let self = self else { return }
          // Trigger the passcode input for this button via gaze.
          self.passcodeButtonTapped(button)
          // Optionally, clear the current gazed button after activation.
          self.currentGazedButton = nil
        }
      }
    } else {
      // If gaze is not on any button, cancel any running timer.
      currentGazedButton = nil
      dwellTimer?.invalidate()
      dwellTimer = nil
    }
  }
  
  // MARK: - Existing Methods
  
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
    let alert = UIAlertController(title: "Camera Access Needed", message: "Please allow camera access in settings to use the camera.", preferredStyle: .alert)
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
    versionLabel.isHidden = true
    passcodeView.isHidden = true
  }
    
  @objc func directionAuthTapped() {
    // Hide other views if needed and display the direction-based authentication view
    print("Switching to Direction-based Authentication")
    // e.g., directionAuthView.isHidden = false
  }

  @objc func dotsAuthTapped() {
    // Hide other views if needed and display the highlight-dots authentication view
    print("Switching to Highlight Dots Authentication")
    // e.g., dotsAuthView.isHidden = false
  }
  
  func showErrorAlert(message: String) {
    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    present(alert, animated: true, completion: nil)
  }
}

extension PasscodeController: InitializationDelegate, TrackingDelegate, CalibrationDelegate, StatusDelegate {

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
      
    self.handleGazeForPasscode()
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
    self.versionLabel.isHidden = false
    self.passcodeView.isHidden = false
    self.index = 0
  }

  func onStarted() {
    self.stopBtn.isEnabled = true
    self.startBtn.isEnabled = false
    self.caliBtn.isEnabled = true
    self.pointView.isHidden = false
  }

  func onStopped(error: StatusError) {
    self.startBtn.isEnabled = true
    self.stopBtn.isEnabled = false
    self.caliBtn.isEnabled = false
  }
}

