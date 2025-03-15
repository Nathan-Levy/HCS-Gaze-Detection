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
  @IBOutlet weak var homeBtn: UIButton!
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
    
    var authenticationStartTime: Date?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    versionLabel.text = "Version : \(GazeTracker.getFrameworkVersion())"
    checkCameraAuthorizationStatus()

    startBtn.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
    stopBtn.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
    caliBtn.addTarget(self, action: #selector(caliButtonTapped), for: .touchUpInside)
    homeBtn.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)

    startBtn.isEnabled = false
    stopBtn.isEnabled = false
    caliBtn.isEnabled = false
    homeBtn.isEnabled = false

    self.view.addSubview(pointView)
    self.view.addSubview(calibrationPointView)
    pointView.isHidden = true
    calibrationPointView.isHidden = true

    // Set up the passcode layout in the center of the screen.
    setupPasscodeView()
      
    self.view.bringSubviewToFront(pointView)
      
    setupExtraAuthButtons()
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

  func setupExtraAuthButtons() {
    // Define button dimensions and spacing
    let buttonWidth: CGFloat = 120
    let buttonHeight: CGFloat = 40
    let spacing: CGFloat = 10
    
    // Calculate positions (example: bottom right corner)
    let startX = view.bounds.width - buttonWidth - spacing
    let firstY = view.bounds.height - (buttonHeight * 2 + spacing * 3)
    
  }
    
  // MARK: - Passcode UI Setup
  func setupPasscodeView() {
    // Define the size of the passcode container
    let width: CGFloat = 350
    let height: CGFloat = 390
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
    let buttonHeight: CGFloat = 70  // Increased from 50
    
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

        // If a 4-digit passcode is required, check it here
        if passcodeInput.count == 4 {
            if passcodeInput == "123456" {  // Example correct passcode
                print("Passcode correct!")
                passcodeView.isHidden = true

                // **Calculate authentication time**
                if let startTime = authenticationStartTime {
                    let elapsedTime = Date().timeIntervalSince(startTime) // Time in seconds
                    print("Authentication successful! Time taken: \(elapsedTime) seconds")

                    // **Show the popup**
                    showAuthenticationPopup(timeElapsed: elapsedTime)
                }

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
          dwellTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
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
    homeBtn.isHidden = true
    versionLabel.isHidden = true
    passcodeView.isHidden = true
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

extension PasscodeController: InitializationDelegate, TrackingDelegate, CalibrationDelegate, StatusDelegate {

  func onInitialized(tracker: GazeTracker?, error: InitializationError) {
    if error == .errorNone {
      self.tracker = tracker
      self.tracker?.trackingDelegate = self
      self.tracker?.calibrationDelegate = self
      self.tracker?.statusDelegate = self
      self.startBtn.isEnabled = true
      self.homeBtn.isEnabled = true
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
    self.homeBtn.isHidden = false
    self.versionLabel.isHidden = false
    self.passcodeView.isHidden = false
    self.index = 0
      
    // **Start the authentication timer NOW**
    authenticationStartTime = Date()
  }

  func onStarted() {
    self.stopBtn.isEnabled = true
    self.startBtn.isEnabled = false
    self.caliBtn.isEnabled = true
      self.homeBtn.isEnabled = true
    self.pointView.isHidden = false
  }

  func onStopped(error: StatusError) {
    self.startBtn.isEnabled = true
    self.stopBtn.isEnabled = false
    self.caliBtn.isEnabled = false
    self.homeBtn.isEnabled = true
  }
}

