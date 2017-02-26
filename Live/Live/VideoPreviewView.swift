//
//  VideoPreviewView.swift
//  Live
//
//  Created by Migu on 2016/12/22.
//  Copyright © 2016年 VictorChee. All rights reserved.
//

import UIKit
import AVFoundation

public class VideoPreviewView: UIView {
    required override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        backgroundColor = UIColor.black
    }
    
    override public class var layerClass: AnyClass {
        get {
            return AVCaptureVideoPreviewLayer.self
        }
    }

    var session: AVCaptureSession {
        get {
            let previewLayer = self.layer as! AVCaptureVideoPreviewLayer
            return previewLayer.session
        }
        set {
           let previewLayer = self.layer as! AVCaptureVideoPreviewLayer
            previewLayer.session = newValue
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        }
    }
}
