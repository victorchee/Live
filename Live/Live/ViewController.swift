//
//  ViewController.swift
//  Live
//
//  Created by Victor Chee on 2017/2/22.
//  Copyright © 2017年 VictorChee. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let rtmpUrl = "rtmp://192.168.0.103:1935/hls/stream"
        let client = LivePublishClient()
        client.startPublish(toUrl: rtmpUrl)
        
        let preview = client.videoPreviewView
        preview.frame = view.bounds
        view.addSubview(preview)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

