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
    public enum OutputMediaType : Int {
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
    
    public enum MediaQuality : Int {
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
    
    /// set this to true will automaticly save the captured data to the system library
    public var isSaveTheFileToLibrary = true
    
    // set mediaQuality default is high
    public var mediaQuality: MediaQuality! = nil {
        didSet {
            if oldValue != mediaQuality {
                
                if oldValue == nil {
                    change(mediaQuality: mediaQuality)

                } else {
                    
                    session.beginConfiguration()
                    change(mediaQuality: mediaQuality)
                    session.commitConfiguration()
                }
            }
        }
    }
    
    // set mediaType default is stillImage
    public var outputMediaType: OutputMediaType! = nil {
        didSet {
            
            if oldValue != outputMediaType {
                if oldValue == nil {
                    //switch to the new mediaType
                    change(mediaType: outputMediaType)
                    
                } else {
                    session.beginConfiguration()
                    change(mediaType: outputMediaType)
                    session.commitConfiguration()
                }
            }
        }
    }
    
    // set cameraPosition default is back
    public var cameraPosition: CameraPosition! = nil {
        didSet {
            if oldValue != cameraPosition {
                // switch to the new cameraPosition
                if oldValue == nil {// prepareCamera
                    change(cameraPosion: cameraPosition)
                } else {
                    dispatch_async(self.sessionQueue, {
                        self.session.beginConfiguration()
                        self.change(cameraPosion: self.cameraPosition)
                        self.session.commitConfiguration()
                    })
                }
            }
        }
    }
    
    // set flashModel default is auto
    public var flashModel: FlashModel! = nil {
        didSet {
            if oldValue != flashModel {
                // switch to the new flashModel
                
                if oldValue == nil {
                    //switch to the new mediaType
                    change(flashModel: flashModel)
                    
                } else {
                    session.beginConfiguration()
                    change(flashModel: flashModel)
                    session.commitConfiguration()
                }
            }
        }
    }
    
    
    // MARK:- private property
    private var videoCompleteHandler:((videoFileUrl: NSURL?, error: NSError?) -> ())?
    private var lastScale:CGFloat = 1.0
    
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
    
    // scale and adjust focus via pinGesture when the media type is stillImage
    private lazy var pinchGes:UIPinchGestureRecognizer = {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinGesture(_:)))
        return pinch
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

        // tapGesture is always useful
        let tapGes = UITapGestureRecognizer(target: self, action: #selector(self.handleTapGesture(_:)))
        addGestureRecognizer(tapGes)
        addGestureRecognizer(pinchGes)
        
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        // to fit the orientation
        previewLayer.frame = bounds
        
    }
    
    deinit {
        session.stopRunning()
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
}

// MARK:- private Helper
extension CameraView {
    
    private func change(mediaQuality mediaQuality: MediaQuality) {
        let preset:String
        
        switch mediaQuality {
        case .high:
            if outputMediaType == .stillImage {
            
                preset = AVCaptureSessionPresetPhoto
            } else {
                preset = AVCaptureSessionPresetHigh
                
            }
        case .low:
            preset = AVCaptureSessionPresetLow
        case .medium:
            preset = AVCaptureSessionPresetMedium
        }
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
    
    private func change(mediaType mediaType: OutputMediaType) {
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
    
    private func change(focusModel focusModel: AVCaptureFocusMode, exposureModel: AVCaptureExposureMode, at point: CGPoint, isMonitor: Bool) {
        if let device = videoDeviceInput?.device {
            do {
                // must lock it or it may causes crashing
                try device.lockForConfiguration()
                
                if device.focusPointOfInterestSupported && device.isFocusModeSupported(focusModel) {
                    device.focusPointOfInterest = point
                    device.focusMode = focusModel
                }
                
                if device.exposurePointOfInterestSupported && device.isExposureModeSupported(exposureModel) {
                    // only when setting the exposureMode after setting exposurePointOFInterest can be successful
                    device.exposurePointOfInterest = point
                    device.exposureMode = exposureModel
                }
                // only when set it true can we receive the AVCaptureDeviceSubjectAreaDidChangeNotification
                device.subjectAreaChangeMonitoringEnabled = isMonitor
                device.unlockForConfiguration()
                
                
            } catch {
                print("cannot change the focusModel")
            
            }
        }
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
    
    private func addObserver() {
        let notiCenter = NSNotificationCenter.defaultCenter()
        notiCenter.addObserver(self, selector: #selector(self.handleSubjectAreaChange(_:)), name: AVCaptureDeviceSubjectAreaDidChangeNotification, object: videoDeviceInput?.device)
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
    
    /// call this method to get and handle the captured still image after you have called prepareCamra()
    public func getStillImage(handler:((image: UIImage?, error: NSError?) -> Void)) -> Bool {
        
        if !hasCamera() {
            print("no avilable camera")
            return false
        }
        // capturing the still image
        dispatch_async(self.sessionQueue) {
            
            self.session.beginConfiguration()
            self.outputMediaType = .stillImage
            let connection = self.stillImageOutput?.connectionWithMediaType(AVMediaTypeVideo)
            connection?.videoOrientation = self.previewLayer.connection.videoOrientation
            self.session.commitConfiguration()
            
            self.stillImageOutput?.captureStillImageAsynchronouslyFromConnection(connection, completionHandler: { (buffer, error) in
                // got the data
                if buffer != nil {
                    
                    
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
                    let image = UIImage(data: imageData)
                    handler(image: image, error: nil)
                    if self.isSaveTheFileToLibrary {
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
        
        return true
        
    }
    
    /// if you call this method then it will automaticly change the flashModel to the next model in order
    /// if you want to switch to a particular flashModel you may need to set the flashModel property
    public func autoChangeFlashModel() -> FlashModel {
        flashModel = flashModel == nil ? FlashModel.auto : flashModel
        // automaticly change the flash model by this way
        if let newFlashModel = FlashModel(rawValue: (flashModel.rawValue + 1)%3) {
            // change the flash model
            flashModel = newFlashModel
        }
        return flashModel
    }
    
    /// if you call this method then it will automaticly change the camera' position to the next position in order
    /// if you want to switch to a particular position you may need to set the cameraPosition property
    public func autoChangeCameraPosition() -> CameraPosition {

        cameraPosition = cameraPosition == nil ? CameraPosition.back : cameraPosition
        if let newPosition = CameraPosition(rawValue: (cameraPosition.rawValue + 1)%2) {
            cameraPosition = newPosition
        }
        return cameraPosition
    }
    
    /// if you call this method then it will automaticly change the outputMediaType in order
    /// if you want to switch to a particular outputMediaType you may need to set the outputMediaType property
    public func autoChangeOutputMediaType() -> OutputMediaType {
        outputMediaType = outputMediaType == nil ? OutputMediaType.stillImage : outputMediaType
        if let newMediaType = OutputMediaType(rawValue: (outputMediaType.rawValue + 1)%2) {
            outputMediaType = newMediaType
        }
        return outputMediaType
    }
    
    public func autoChangeQualityType() -> MediaQuality {
        mediaQuality = mediaQuality == nil ? MediaQuality.high : mediaQuality
        if let newQuality = MediaQuality(rawValue: (mediaQuality.rawValue + 1)%3) {
            mediaQuality = newQuality
        }
        
        return mediaQuality
    }
    
    // call this method to start recoding video after you have called prepareCamra()
    public func startCapturingVideo() -> Bool {
        
        
        session.beginConfiguration()
        outputMediaType = .video
        if !hasCamera() {
            return false
        }
        let connection = movieFileOutput?.connectionWithMediaType(AVMediaTypeVideo)
        connection?.videoOrientation = previewLayer.connection.videoOrientation
        session.commitConfiguration()
        
        let tempFileName = "\(NSProcessInfo().globallyUniqueString).mov"
        let tempFilePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(tempFileName)
        let tempVideoURL = NSURL(fileURLWithPath: tempFilePath)
        
        movieFileOutput?.startRecordingToOutputFileURL(tempVideoURL, recordingDelegate: self)
        return true
    }
    
    // you may need to call this method to see if there are cameras now
    // or you can alse use the prepareCamera() return value
    public func hasCamera() -> Bool {
        if frontDeviceInput != nil || backDeviceInput != nil {
            return true
        } else {
            print("no avilable camera")
            return false
        }
    }
    // you are supposed to call this method first to prepare camera
    public func prepareCamera() -> Bool {
        
        
        if !hasCamera() {
            return false
        }

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
                // default is stillImage
                self.outputMediaType = .stillImage
                // setting flashModel
                self.flashModel = .auto
                // setting mediaQuality
                self.mediaQuality = .high
                // addAudioInputDevice
                self.addAudioInputDevice()
                self.session.commitConfiguration()
                self.addObserver()
                self.session.startRunning()
                
            })
        }
        
        return true
    }
    
    // call this method to stop and handle the captured video
    public func stopCapturingVideo(withHandler handler: (videoUrl: NSURL?, error: NSError?) -> ()) {
        videoCompleteHandler = handler
        movieFileOutput?.stopRecording()
    }
    
    public func resumeCapturing() {
        
    }
}

// MARK:- selector
extension CameraView {
    
    func handlePinGesture(pinGes: UIPinchGestureRecognizer) {
        
        var beginScale: CGFloat = 1.0
        
        switch pinGes.state {
        case .Began:
            beginScale = pinGes.scale
            
        case .Changed:
            if let device = videoDeviceInput?.device {
                do {
                    
                    // only when preset = photo is the videoMaxZoomFactor != 1.0
                    // and can zoom
                    let maxScale = min(20.0, device.activeFormat.videoMaxZoomFactor)
                    // do not change too fast
                    let tempScale = min(lastScale + 0.3*(pinGes.scale - beginScale), maxScale)
                    lastScale = max(1.0, tempScale)
                    
                    try device.lockForConfiguration()
                    device.videoZoomFactor = lastScale
                    device.unlockForConfiguration()
                } catch {
                    print("cannot lock ")
                }
            }

        default :
            break
        }
        
        
    }
    
    func handleTapGesture(tapGes: UITapGestureRecognizer) {
        let location = tapGes.locationInView(tapGes.view)
        let devicePoint = previewLayer.captureDevicePointOfInterestForPoint(location)
        dispatch_async(sessionQueue) { 
            self.change(focusModel: .AutoFocus, exposureModel: .AutoExpose, at: devicePoint, isMonitor: true)
        }
        
    }
    
    func handleSubjectAreaChange(noti: NSNotification) {
        // reset to center (0.0---1.0)
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        // set false
        dispatch_async(sessionQueue) { 
            // set to continuous and do not monitor
            self.change(focusModel: .ContinuousAutoFocus, exposureModel: .ContinuousAutoExposure, at: devicePoint, isMonitor: false)
        }
    }
    
}

// MARK:- public AVCaptureFileOutputRecordingDelegate
extension CameraView: AVCaptureFileOutputRecordingDelegate {
    public func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
    }
    
    public func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        
        var success = true
        if error != nil {// sometimes there may be error but the video is caputed successfully
            success = error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as! Bool
        }
        
        if (success) {
            if isSaveTheFileToLibrary {
                
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