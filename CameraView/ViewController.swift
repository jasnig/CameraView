//
//  ViewController.swift
//  CameraView
//
//  Created by ZeroJ on 16/7/4.
//  Copyright © 2016年 ZeroJ. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var cameraView: CameraView!

    @IBAction func cameraPosition(sender: UIButton) {
        let cameraPosition = cameraView.autoChangeCameraPosition()
        switch cameraPosition {
        case .back:
            sender.setTitle("后面", forState: .Normal)
        case .front:
            sender.setTitle("前面", forState: .Normal)
        }
        
    }
    @IBAction func flashType(sender: UIButton) {
        
        let flashModel = cameraView.autoChangeFlashModel()
        switch flashModel {
        case .on:
            sender.setTitle("打开", forState: .Normal)
        case .off:
            sender.setTitle("关闭", forState: .Normal)
        case .auto:
            sender.setTitle("自动", forState: .Normal)
        }
    }
    
    @IBAction func takePicture(sender: UIButton) {
        
        cameraView.getStillImage { (image, error) in
            print(image)
        }
//        if sender.selected {
//            cameraView.stopCapturingVideo(withHandler: { (videoUrl, error) in
//                print(videoUrl)
//            })
//            sender.selected = false
//        } else {
//            sender.selected = true
//            cameraView.startCapturingVideo()
//        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        cameraView.layer.cornerRadius = 100
        cameraView.layer.masksToBounds = true
        cameraView.prepareCamera()

        cameraView.setHandlerWhenCannotAccessTheCamera {
            
        }
    }

    
    override func viewWillAppear(animated: Bool) {
         super.viewWillAppear(animated)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

