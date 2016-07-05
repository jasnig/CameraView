//
//  CameraView.swift
//  CameraView
//
//  Created by ZeroJ on 16/7/6.
//  Copyright © 2016年 ZeroJ. All rights reserved.
//

import UIKit

import AVFoundation
import Photos
public class CameraView: UIView {
    
    // MARK:- public property
    public enum MediaType {
        case video, stillImage
    }
    
    public enum CameraPosition : Int {
        case back, front
    }
    
    public enum FlashModel : Int {
        case on, off, auto
        
        func changeToAvFlashModel() -> AVCaptureFlashMode {
            switch self {
            case .auto:
                return .Auto
            case .on:
                return .On
            case .off:
                return .Off
            }
        }
    }
    
    public enum MediaQuality {
        case high, medium, low
        
        func changeToAvPreset() -> String {
            switch self {
            case .high:
                return AVCaptureSessionPresetHigh
            case .low:
                return AVCaptureSessionPresetLow
            case .medium:
                return AVCaptureSessionPresetMedium
            }
        }
    }
    
    
    public var saveTheFileToLibrary = true
    
    public var mediaQuality: MediaQuality! = nil {
        didSet {
            if oldValue != mediaQuality {
                session.beginConfiguration()
                change(mediaQuality: mediaQuality)
                session.commitConfiguration()
            }
        }
    }
    
    public var mediaType: MediaType! = nil {
        didSet {
            if oldValue != mediaType {
                //switch to the new mediaType
                change(mediaType: mediaType)
            }
        }
    }
    
    
    public var cameraPosition: CameraPosition! = nil {
        didSet {
            if oldValue != cameraPosition {
                // switch to the new cameraPosition
                if oldValue == nil {// prepareCamera
                    change(cameraPosion: cameraPosition)
                } else {
                    dispatch_async(self.sessionQueue, {
                        self.change(cameraPosion: self.cameraPosition)
                    })
                }
            }
        }
    }
    
    public var flashModel: FlashModel! = nil {
        didSet {
            if oldValue != flashModel {
                // switch to the new flashModel
                change(flashModel: flashModel)
            }
        }
    }
    
    
    // MARK:- private property
    private var videoCompleteHandler:((videoFileUrl: NSURL?, error: NSError?) -> ())?
    
    private lazy var session = AVCaptureSession()
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    private lazy var movieFileOutput: AVCaptureMovieFileOutput? = {
        return AVCaptureMovieFileOutput()
    }()
    
    private lazy var stillImageOutput: AVCaptureStillImageOutput? = {
        return AVCaptureStillImageOutput()
    }()
    
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
    
    private var cannotAccessTheCameraHandler:(() -> Void)?
    
    //DISPATCH_QUEUE_SERIAL -> use the queue strategy to ensure FIFO
    private lazy var sessionQueue: dispatch_queue_t = dispatch_queue_create("cameraViewSessionQueue", DISPATCH_QUEUE_SERIAL)
    
    private lazy var frontDeviceInput: AVCaptureDeviceInput? = {
        self.deviceInput(forDevicePosition: .Front)
    }()
    
    private lazy var backDeviceInput: AVCaptureDeviceInput? = {
        self.deviceInput(forDevicePosition: .Back)
    }()
    
    // attention that for the movie the extension should't be 'jpg'
    
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        commonInit()
    }
    
    
    private func commonInit() {
        // set the resize model
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        // add the previewLayer
        layer.addSublayer(previewLayer)
        clipsToBounds = true
        // TODO:- !!scale and adjust focus via pinGesture
        // TODO:- !!adjust focus via tapGesture

        let pinchGes = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinGesture(_:)))
        addGestureRecognizer(pinchGes)
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        // to fit the orientation
        previewLayer.frame = bounds
        
    }
    
    deinit {
        session.stopRunning()
        
    }
    
    
}

// MARK:- private Helper
extension CameraView {
    
    private func change(mediaQuality mediaQuality: MediaQuality) {
        let preset = mediaQuality.changeToAvPreset()
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        }
    }
    
    
    private func change(flashModel flashModel: FlashModel) {
        let avFlashModel = flashModel.changeToAvFlashModel()
        
        if let trueVideoDevice = videoDeviceInput?.device where trueVideoDevice.hasFlash && trueVideoDevice.isFlashModeSupported(avFlashModel) {
            
            do {
                try trueVideoDevice.lockForConfiguration()
                trueVideoDevice.flashMode = avFlashModel
                trueVideoDevice.unlockForConfiguration()
            } catch {
                print("can not lock the device for configuration!! ---\(error)")
            }
            
        }
    }
    
    private func change(mediaType mediaType: MediaType) {
        if mediaType == .stillImage {
            self.session.removeOutput(movieFileOutput)
            self.session.addOutput(stillImageOutput)
        } else {
            self.session.removeOutput(stillImageOutput)
            self.session.addOutput(movieFileOutput)
            
        }
    }
    
    private func change(cameraPosion posion: CameraPosition) {
        self.session.removeInput(self.videoDeviceInput)
        switch posion {
        case .back:
            self.videoDeviceInput = self.backDeviceInput
        case .front:
            self.videoDeviceInput = self.frontDeviceInput
        }
        self.add(inputDevice: self.videoDeviceInput)
    }
    
    private func add(inputDevice inputDevice: AVCaptureDeviceInput!) {
        if self.session.canAddInput(inputDevice) {
            self.session.addInput(inputDevice)
        } else {
            print("can not add the input devices-- \(String(inputDevice))")
        }
        
    }
    
    private func add(stillImageOutput stillImageOutput: AVCaptureStillImageOutput!) {
        if self.session.canAddOutput(stillImageOutput) {
            self.session.addOutput(stillImageOutput)
        } else {
            print("can not add stillImageOutput !!")
            
        }
    }
    
    private func add(movieFileOutput movieFileOutput: AVCaptureMovieFileOutput!) {
        if self.session.canAddOutput(movieFileOutput) {
            self.session.addOutput(movieFileOutput)
        } else {
            print("can not add movieFileOutput !!")
        }
    }
    
    private func askForAccessDevice(withCompleteHandler completeHandler:((succeed: Bool) -> Void)?) {
        // suspend the queue untill the request end
        dispatch_suspend(self.sessionQueue)
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (succeed) in
            
            if succeed {
                AVCaptureDevice.requestAccessForMediaType(AVMediaTypeAudio, completionHandler: { (succeed) in
                    completeHandler?(succeed: succeed)
                    // resume the queue
                    dispatch_resume(self.sessionQueue)
                    
                })
                
            } else {
                completeHandler?(succeed: false)
                dispatch_resume(self.sessionQueue)
                
            }
        })
        
    }
    
    
    
    private func deviceInput(forDevicePosition position: AVCaptureDevicePosition) -> AVCaptureDeviceInput? {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as![AVCaptureDevice]
        var deviceInput: AVCaptureDeviceInput? = nil
        for device in devices {
            if device.position == position {
                deviceInput = try? AVCaptureDeviceInput(device: device)
                break
            }
        }
        // cause it cannot be failed so we use try!
        
        return deviceInput
    }
    
    private func addAudioInputDevice() {
        let audioDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
        do {
            
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            if self.session.canAddInput(audioDeviceInput) {
                self.session.addInput(audioDeviceInput)
            } else {
                print("can not add the audio inputDevice")
            }
            
        } catch {
            print("can not add create the audio input")
        }
    }
}

// MARK:- public Helper
extension CameraView {
    
    
    /// this closure will be invoked when can not access the camera
    /// and you can show some messages to the users
    /// and setting it is always been suggested
    public func setHandlerWhenCannotAccessTheCamera(handler: (() -> Void)?) {
        self.cannotAccessTheCameraHandler = handler
    }
    
    // get a captured still image
    public func getStillImage(handler:((image: UIImage?, error: NSError?) -> Void)) {
        // capturing the still image
        dispatch_async(self.sessionQueue) {
            
            self.session.beginConfiguration()
            self.mediaType = .stillImage
            let connection = self.stillImageOutput?.connectionWithMediaType(AVMediaTypeVideo)
            connection?.videoOrientation = self.previewLayer.connection.videoOrientation
            self.session.commitConfiguration()
            
            self.stillImageOutput?.captureStillImageAsynchronouslyFromConnection(connection, completionHandler: { (buffer, error) in
                // got the data
                if buffer != nil {
                    
                    
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
                    let image = UIImage(data: imageData)
                    handler(image: image, error: nil)
                    if self.saveTheFileToLibrary {
                        let tempFileName = "\(NSProcessInfo().globallyUniqueString).jpg"
                        let tempFilePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(tempFileName)
                        let tempImageURL = NSURL(fileURLWithPath: tempFilePath)
                        
                        PHPhotoLibrary.requestAuthorization({ (status) in
                            if status == .Authorized {
                                PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                                    do {
                                        // write to tempPath
                                        try imageData.writeToURL(tempImageURL, options: NSDataWritingOptions.AtomicWrite)
                                        // write to album
                                        PHAssetChangeRequest.creationRequestForAssetFromImageAtFileURL(tempImageURL)
                                    } catch {
                                        print("failed to save the picture to album")
                                    }
                                    }, completionHandler: { (succeed, error) in
                                        
                                        do {
                                            try NSFileManager.defaultManager().removeItemAtURL(tempImageURL)
                                        } catch {
                                            print("failed to save the picture to album")
                                        }
                                })
                            }
                        })
                    }
                    
                    
                } else {
                    handler(image: nil, error: error)
                    
                }
                
                
            })
        }
        
    }
    
    /// if you call this method then it will automaticly change the flashModel to the next model in order
    public func autoChangeFlashModel() -> FlashModel {
        let oldFlashModelRawValue = flashModel.rawValue
        
        // automaticly change the flash model by this way
        let newFlashModel = FlashModel(rawValue: (oldFlashModelRawValue + 1)%3)
        
        if let trueNewFlashModel = newFlashModel {
            // change the flash model
            flashModel = trueNewFlashModel
        }
        return flashModel
    }
    
    /// if you call this method then it will automaticly change the camera' position to the next position in order
    public func autoChangeCameraPosition() -> CameraPosition {
        let oldPositionRawValue = cameraPosition.rawValue
        let newPosition = CameraPosition(rawValue: (oldPositionRawValue + 1)%2)
        
        if let trueNewPosition = newPosition {
            cameraPosition = trueNewPosition
        }
        return cameraPosition
    }
    
    public func startCapturingVideo() {
        session.beginConfiguration()
        mediaType = .video
        let connection = movieFileOutput?.connectionWithMediaType(AVMediaTypeVideo)
        connection?.videoOrientation = previewLayer.connection.videoOrientation
        session.commitConfiguration()
        
        let tempFileName = "\(NSProcessInfo().globallyUniqueString).mov"
        let tempFilePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(tempFileName)
        let tempVideoURL = NSURL(fileURLWithPath: tempFilePath)
        
        movieFileOutput?.startRecordingToOutputFileURL(tempVideoURL, recordingDelegate: self)
    }
    
    public func prepareCamera() {
        
        // do not block the main queue
        dispatch_async(sessionQueue) {
            
            self.askForAccessDevice(withCompleteHandler: { (succeed) in
                if !succeed {
                    dispatch_async(dispatch_get_main_queue(), {
                        self.cannotAccessTheCameraHandler?()
                    })
                    return
                }
                
                // add inputs and outputs
                self.session.beginConfiguration()
                
                // this will add current device
                self.cameraPosition = .back
                // setting flashModel
                self.flashModel = .auto
                
                self.addAudioInputDevice()
                // default is stillImage
                self.mediaType = .stillImage
                self.session.commitConfiguration()
                
                self.session.startRunning()
            })
        }
    }
    
    public func stopCapturingVideo(withHandler handler: (videoUrl: NSURL?, error: NSError?) -> ()) {
        videoCompleteHandler = handler
        movieFileOutput?.stopRecording()
    }
    
    public func resumeCapturing() {
        
    }
}


extension CameraView: UIGestureRecognizerDelegate {
    
    func handlePinGesture(pinGes: UIPinchGestureRecognizer) {
        
    }
    
    func handleTapGesture(tapGes: UITapGestureRecognizer) {
        
    }
    
}

extension CameraView: AVCaptureFileOutputRecordingDelegate {
    public func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        print("start -video ")
    }
    
    public func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        
        var success = true
        if error != nil {// sometimes there may be error but the video is caputed successfully
            success = error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as! Bool
        }
        
        if (success) {
            if saveTheFileToLibrary {
                
                PHPhotoLibrary.requestAuthorization({ (status) in
                    if status == PHAuthorizationStatus.Authorized {
                        
                        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(outputFileURL)
                            
                            }, completionHandler: {[unowned self] (succeed, error) in
                                if succeed {
                                    self.videoCompleteHandler?(videoFileUrl: outputFileURL, error: error)
                                    
                                } else {
                                    self.videoCompleteHandler?(videoFileUrl: outputFileURL, error: error)
                                }
                                do {
                                    try NSFileManager.defaultManager().removeItemAtURL(outputFileURL)
                                } catch {
                                    print("can not save video to alblum")
                                }
                            })
                    }
                })
                
            } else {
                videoCompleteHandler?(videoFileUrl: outputFileURL, error: error)
                
            }
        }
    }
}