# CameraView
很方便的实现自定义照相机和摄像机, 本身是一个view, 可以自定义形状和位置等, 方便的闪光灯, 前后摄像头切换...(totally customize the camera )

####最终使用的效果之一

![Snip20160710_1.png](http://upload-images.jianshu.io/upload_images/1271831-beb7ccfeddaa2352.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

####Usage

* first prepareCamera
 
  `let isSuccess = cameraView.prepareCamera()`

* second capturing photo like this

   `cameraView.getStillImage { (image, error) in
                print(image)
            }`
* or capturing video like this

```
	// start capturing video
    cameraView.startCapturingVideo()

	// finish capturing video and get the video file
	cameraView.stopCapturingVideo(withHandler: { (videoUrl, error) in
                    print(videoUrl)
                })

```


####如果你在使用中遇到问题: 可以通过[简书](http://www.jianshu.com/users/fb31a3d1ec30/latest_articles)私信给我

## License

CameraView is released under the MIT license. See LICENSE for details.
