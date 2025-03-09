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

class ViewController: UIViewController {

  @IBOutlet weak var versionLabel: UILabel!
    
  @IBOutlet weak var dirBtn: UIButton!
  @IBOutlet weak var dotBtn: UIButton!
  @IBOutlet weak var pasBtn: UIButton!
  @IBOutlet weak var imgBtn: UIButton!
  
  // TODO: change licence key
  let license : String = "dev_gu8vkaqajvi4b62kr08z5s77gt7aoq0tbrixntg5"


  var index = 0
  let colorList : [UIColor] = [UIColor.red, UIColor.blue, UIColor.green, UIColor.orange, UIColor.cyan]

  
  override func viewDidLoad() {
    super.viewDidLoad()
    versionLabel.text = "Version : \(GazeTracker.getFrameworkVersion())"

      
    dirBtn.addTarget(self, action: #selector(directionAuthTapped), for: .touchUpInside)
    dotBtn.addTarget(self, action: #selector(dotsAuthTapped), for: .touchUpInside)
    pasBtn.addTarget(self, action: #selector(passcodeAuthTapped), for: .touchUpInside)
    imgBtn.addTarget(self, action: #selector(imageAuthTapped), for: .touchUpInside)
      
    dirBtn.isEnabled = true
    dotBtn.isEnabled = true
    imgBtn.isEnabled = true
    pasBtn.isEnabled = true


    
  }
    
  @objc func directionAuthTapped(_ sender: Any) {
      let storyboard = UIStoryboard(name: "Main", bundle: nil)
      guard let directionVC = storyboard.instantiateViewController(
          withIdentifier: "DirectionBasedController"
      ) as? DirectionBasedController else {
          return
      }

      // Force the view to fill the entire screen
      directionVC.modalPresentationStyle = .fullScreen

      // Now present it
      self.present(directionVC, animated: true, completion: nil)
  }

  @objc func dotsAuthTapped(_ sender: Any) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let dotsVC = storyboard.instantiateViewController(
        withIdentifier: "DotsController"
    ) as? DotsController else {
        return
    }

    // Force the view to fill the entire screen
    dotsVC.modalPresentationStyle = .fullScreen

    // Now present it
    self.present(dotsVC, animated: true, completion: nil)
  }
    
  @objc func passcodeAuthTapped() {
  // Hide other views if needed and display the direction-based authentication view
    print("Switching to Direction-based Authentication")
  // e.g., directionAuthView.isHidden = false
  }

  @objc func imageAuthTapped() {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let imgVC = storyboard.instantiateViewController(
        withIdentifier: "ImageController"
    ) as? ImageController else {
        return
    }

    // Force the view to fill the entire screen
    imgVC.modalPresentationStyle = .fullScreen

    // Now present it
    self.present(imgVC, animated: true, completion: nil)
  }
  
  func showErrorAlert(message: String) {
    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    present(alert, animated: true, completion: nil)
  }
}
