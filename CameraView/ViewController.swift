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

    override func viewDidLoad() {
        super.viewDidLoad()
        cameraView.layer.cornerRadius = 100
        cameraView.layer.masksToBounds = true
        let isSuccess = cameraView.prepareCamera()
        
        if !isSuccess {
            print("没有相机")
        }
        
        cameraView.setHandlerWhenCannotAccessTheCamera {
            print("用户未授权访问相机")
        }
    }
    
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func changeCameraPosition(sender: UIButton) {
        let cameraPosition = cameraView.autoChangeCameraPosition()
        switch cameraPosition {
        case .back:
            sender.setTitle("后面", forState: .Normal)
        case .front:
            sender.setTitle("前面", forState: .Normal)
        }
        
    }
    @IBAction func changeFlashType(sender: UIButton) {
        
        
        let flashModel = cameraView.autoChangeFlashModel()
        //cameraView.flashModel = CameraView.FlashModel.auto
        //let flashModel = cameraView.flashModel
        switch flashModel {
        case .on:
            sender.setTitle("打开", forState: .Normal)
        case .off:
            sender.setTitle("关闭", forState: .Normal)
        case .auto:
            sender.setTitle("自动", forState: .Normal)
        }
    }
    
    @IBAction func changeMediaQuality(sender: UIButton) {
        cameraView.autoChangeQualityType()
        //cameraView.mediaQuality = CameraView.MediaQuality.high
    }
    @IBAction func changeOutputType(sender: UIButton) {
        cameraView.autoChangeOutputMediaType()
        //cameraView.outputMediaType = CameraView.OutputMediaType.stillImage
    }
    @IBAction func takePicture(sender: UIButton) {
        
        
        if cameraView.outputMediaType == CameraView.OutputMediaType.stillImage {
            // 拍照
            cameraView.getStillImage { (image, error) in
                print(image)
            }
        } else {
            // 录视频
            if sender.selected {// 正在录制, 点击停止
                cameraView.stopCapturingVideo(withHandler: { (videoUrl, error) in
                    print(videoUrl)
                })
                sender.selected = false
            } else {// 点击开始录制
                sender.selected = true
                cameraView.startCapturingVideo()
            }
        }


    }


}

