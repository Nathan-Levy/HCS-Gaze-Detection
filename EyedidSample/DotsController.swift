//
//  DotsController.swift
//  EyedidSample
//
//  Created by Nathan Levy on 05/03/2025.
//

import UIKit
import AVFoundation
import Eyedid

class DotsController: UIViewController {

    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var stopBtn: UIButton!
    @IBOutlet weak var caliBtn: UIButton!
    @IBOutlet weak var homeBtn: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    
    var tracker: GazeTracker?
    let license: String = "dev_gu8vkaqajvi4b62kr08z5s77gt7aoq0tbrixntg5"

    let pointView: PointView = PointView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
    let calibrationPointView: CalibrationPointView = CalibrationPointView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))

    // MARK: - Gaze Password Properties
    // We'll still call them "gazeButtons," but they're effectively "dots."
    var gazeButtons: [UIButton] = []
    var inputSequence: [Int] = []
    let requiredSequence: [Int] = [1, 4, 7]  // Example password sequence

    // Dwell detection
    var currentGazedButton: UIButton?
    var dwellTimer: Timer?
    
    var authenticationStartTime: Date?
    var authenticationTimeLabel: UILabel!
    var dismissButton: UIButton!


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
        
        // Add the gaze point & calibration views
        view.addSubview(pointView)
        view.addSubview(calibrationPointView)
        pointView.isHidden = true
        calibrationPointView.isHidden = true
        
        // Set up a 3×3 layout of circular dots
        setupDotsLayout()
        
        // Bring the gaze indicator to the front
        view.bringSubviewToFront(pointView)
    
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

    // Dismiss function
    @objc func dismissPopup() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Setup Dots Layout
    func setupDotsLayout() {
        // We'll manually position a 3×3 grid of circles using spacing.
        // Adjust sizes and spacing to match your wireframe.
        let rows = 4
        let cols = 2
        
        let dotDiameter: CGFloat = 110
        let horizontalSpacing: CGFloat = 60
        let verticalSpacing: CGFloat = 30
        
        // Calculate total width and height
        let totalWidth = CGFloat(cols) * dotDiameter + CGFloat(cols - 1) * horizontalSpacing
        let totalHeight = CGFloat(rows) * dotDiameter + CGFloat(rows - 1) * verticalSpacing
        
        // Start in the center of the screen
        let startX = (view.bounds.width - totalWidth) / 2
        let startY = (view.bounds.height - totalHeight) / 4
        
        for row in 0..<rows {
            for col in 0..<cols {
                let index = row * cols + col
                // Calculate the dot's frame
                let x = startX + CGFloat(col) * (dotDiameter + horizontalSpacing)
                let y = startY + CGFloat(row) * (dotDiameter + verticalSpacing)
                let frame = CGRect(x: x, y: y, width: dotDiameter, height: dotDiameter)
                
                // Create a circular UIButton
                let dotButton = UIButton(frame: frame)
                dotButton.layer.cornerRadius = dotDiameter / 2
                dotButton.backgroundColor = .lightGray   // default gray
                dotButton.layer.borderWidth = 1
                dotButton.layer.borderColor = UIColor.darkGray.cgColor
                
                // Optionally store the index for debugging or logic
                dotButton.tag = index
                
                // If you want to show the index in the center, uncomment:
                // dotButton.setTitle("\(index)", for: .normal)
                // dotButton.setTitleColor(.black, for: .normal)
                
                view.addSubview(dotButton)
                gazeButtons.append(dotButton)
            }
        }
    }
    
    // MARK: - Gaze-based Dwell Detection
    func handleGazeForPasswordInput() {
        // Only process if the dots are visible (and not hidden during calibration)
        
        // Convert gaze point from main view to the same coordinate space as our dots
        // (Here, dots are in self.view directly, so no conversion is needed.)
        let gazePoint = pointView.center
        
        var gazedButton: UIButton?
        for button in gazeButtons {
            if button.frame.contains(gazePoint) {
                gazedButton = button
                break
            }
        }
        
        if let button = gazedButton {
            // If we moved to a new button, reset dwell timer
            if currentGazedButton != button {
                currentGazedButton = button
                dwellTimer?.invalidate()
                dwellTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    self.activateGazeButton(button)
                    self.currentGazedButton = nil
                }
            }
        } else {
            // If gaze left any button, cancel dwell
            currentGazedButton = nil
            dwellTimer?.invalidate()
            dwellTimer = nil
        }
    }
    
    func activateGazeButton(_ button: UIButton) {
        // Turn the dot green
        button.backgroundColor = .green
        
        // Use the button's tag to identify which dot was pressed
        let index = button.tag
        inputSequence.append(index)
        print("Dot \(index) activated. Current input sequence: \(inputSequence)")
        
        checkInputSequence()
    }
    
    func checkInputSequence() {
        if inputSequence.count == requiredSequence.count {
            if inputSequence == requiredSequence {
                print("Correct password entered!")
                flashScreen(color: .green)

                // **Calculate authentication time**
                if let startTime = authenticationStartTime {
                    let elapsedTime = Date().timeIntervalSince(startTime) // Time in seconds
                    print("Authentication successful! Time taken: \(elapsedTime) seconds")

                    // **Show the popup**
                    showAuthenticationPopup(timeElapsed: elapsedTime)
                }

            } else {
                print("Incorrect password!")
                flashScreen(color: .red)
            }
            // Reset for a new attempt
            inputSequence.removeAll()
            resetGazeButtons()
        }
    }
    
    func resetGazeButtons() {
        for button in gazeButtons {
            button.backgroundColor = .lightGray
        }
    }
    
    // Briefly flash the screen
    func flashScreen(color: UIColor) {
        let originalColor = view.backgroundColor
        view.backgroundColor = color
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.view.backgroundColor = originalColor
        }
    }
    
    // MARK: - Camera & Gaze Tracker
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
        let alert = UIAlertController(
            title: "Camera Access Needed",
            message: "Please allow camera access in settings to use the camera.",
            preferredStyle: .alert
        )
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
        // Hide dots during calibration
        for button in gazeButtons {
            button.isHidden = true
        }
        
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

extension DotsController: InitializationDelegate, TrackingDelegate, CalibrationDelegate, StatusDelegate {
    
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
                // Update the gaze indicator location
                self.pointView.center = CGPoint(x: CGFloat(gazeInfo.x), y: CGFloat(gazeInfo.y))
            }
            // Perform dwell detection if not calibrating
            if self.tracker?.isCalibrating() == false {
                self.handleGazeForPasswordInput()
            }
        }
    }
    
    func onCalibrationNextPoint(x: Double, y: Double) {
        calibrationPointView.reset(to: UIColor.blue)
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
        versionLabel.isHidden = false
        homeBtn.isHidden = false
        
        self.resetGazeButtons()
        self.inputSequence.removeAll()
        // Re-display the dots after calibration
        for button in gazeButtons {
            button.isHidden = false
        }
        
        authenticationStartTime = Date()
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
