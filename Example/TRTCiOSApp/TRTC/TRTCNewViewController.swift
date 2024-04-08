//
//  TRTCNewViewController.swift
//  LiteAVApollo
//
//  Created by cui on 2020/6/12.
//  Copyright © 2020 Tencent. All rights reserved.
//

import UIKit
import TXLiteAVSDK_TRTC
import AgoraRtcKit

class TRTCNewViewController: UIViewController {
    let userIDKey = "userID"
    let roomIDKey = "roomID"
    var keyboardToolbar : UIToolbar!

    @IBOutlet weak var userField: UITextField!
    @IBOutlet weak var roomField: UITextField!

    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet weak var vendorControl: UISegmentedControl!
    @IBOutlet weak var cameraControl: UISegmentedControl!
    @IBOutlet weak var sceneControl: UISegmentedControl!
    @IBOutlet weak var roleControl: UISegmentedControl!
    @IBOutlet weak var fpsControl: UISegmentedControl!
    @IBOutlet weak var bitrateField: UITextField!
    @IBOutlet weak var bitrateSlider: UISlider!
    @IBOutlet weak var resolutionControl: UISegmentedControl!
    @IBOutlet weak var audioQualityControl: UISegmentedControl!

    var resolution = CGSize(width: 960, height: 540)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "RTC对比测试"

        // Control Config
        joinButton.setTitleColor(.white, for: .normal)
        let layer = joinButton.layer
        layer.cornerRadius = 5
        layer.masksToBounds = true
        layer.backgroundColor = #colorLiteral(red: 0.1766264737, green: 0.4323883057, blue: 0.9996721148, alpha: 1)

        bitrateSlider.minimumValue = 425
        bitrateSlider.maximumValue = 1700
        bitrateSlider.value = 850
        bitrateField.text = String(Int(bitrateSlider.value))

        roleControl.isEnabled = false

        let defaults = UserDefaults.standard
        userField.text = defaults.string(forKey: userIDKey)
        roomField.text = defaults.string(forKey: roomIDKey)
        [userField!, roomField!].forEach { textField in
            if (textField.text ?? "").lengthOfBytes(using: .utf8) == 0 {
                textField.text = String(arc4random() % 100000)
            }
        }
        keyboardToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        keyboardToolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.onKeyboardDone))
        ]
    }

    @objc func onKeyboardDone() {
        self.view.endEditing(true)
    }

    func enterRoom() {
        self.navigationController?.navigationBar.isHidden = false
        guard let userID = userField.text,
            let roomID = roomField.text else {
            return
        }
        let mainViewCotnroller = TRTCMainViewController()
        let param = TRTCLoginParam()

        param.sdkAppId = String(SDKConfig.txsdkAppID())
        param.userId = userID;
        param.roomId = roomID;
        param.role = self.roleControl.selectedSegmentIndex == 0 ? .broadcaster : .audience
        param.userSig = GenerateTestUserSig.genTestUserSig(userID)

        mainViewCotnroller.param = param;
        mainViewCotnroller.appScene = self.sceneControl.selectedSegmentIndex == 0 ? .communication : .liveBroadcasting

        let audioProfile = buildAudioConfig()
       
        mainViewCotnroller.useTRTC = self.vendorControl.selectedSegmentIndex == 0
        mainViewCotnroller.videoProfile = buildVideoConfig()
        mainViewCotnroller.audioProfile = audioProfile
        mainViewCotnroller.videoEnabled = self.cameraControl.selectedSegmentIndex == 0
        let defaults = UserDefaults.standard
        defaults.setValue(param.userId, forKey: userIDKey)
        defaults.setValue(param.roomId, forKey: roomIDKey)

        navigationController?.pushViewController(mainViewCotnroller, animated: true)
    }

    func showResolutionActionSheet() {
        let resolutions = [
            ("160x160",TRTCVideoResolution._160_160),
            ("180x320",TRTCVideoResolution._320_180),
            ("240x320",TRTCVideoResolution._320_240),
            ("360x640",TRTCVideoResolution._640_360),
            ("480x480",TRTCVideoResolution._480_480),
            ("480x640",TRTCVideoResolution._640_480),
            ("540x960",TRTCVideoResolution._960_540),
            ("720x1280",TRTCVideoResolution._1280_720),
            ("1080x1920",TRTCVideoResolution._1920_1080)
        ]
        let alert = UIAlertController(title: "选择分辨率", message: nil, preferredStyle: .actionSheet)
        for item in resolutions {
            let action = UIAlertAction(title: item.0, style: .default) {[unowned self] (_) in
                let components = item.0.split(separator: "x")
                if case let (w, h)  = (String(components.first!), String(components.last!)),
                    let width = Int(w),
                    let height = Int(h) {
                    self.resolution = CGSize(width: width, height: height)
                    self.resolutionControl.removeSegment(at: 0, animated: false)
                    self.resolutionControl.insertSegment(withTitle: item.0, at: 0, animated: false)
                    self.resolutionControl.selectedSegmentIndex = 0
                    //将码率滑动条设为分辨率对应的默认值
                    let resolution = (width, height)
                    switch resolution {
                    case (160,160):
                        self.bitrateSlider.minimumValue = 50
                        self.bitrateSlider.maximumValue = 550
                        if(self.sceneControl.selectedSegmentIndex==0){//视频通话
                            self.bitrateSlider.value = 100;
                            self.bitrateField.text = "100"
                        }else{//直播
                            self.bitrateSlider.value=150;
                            self.bitrateField.text = "150"
                        }
                        break
                    case (180,320):
                        self.bitrateSlider.minimumValue = 125
                        self.bitrateSlider.maximumValue = 800
                        if(self.sceneControl.selectedSegmentIndex==0){//视频通话
                            self.bitrateSlider.value = 250;
                            self.bitrateField.text = "250"
                        }else{//直播
                            self.bitrateSlider.value = 400;
                            self.bitrateField.text = "400"
                        }
                        break
                    case (240,320):
                        self.bitrateSlider.minimumValue = 125
                        self.bitrateSlider.maximumValue = 775
                        if(self.sceneControl.selectedSegmentIndex==0){//视频通话
                            self.bitrateSlider.value = 250;
                            self.bitrateField.text = "250"
                        }else{//直播
                            self.bitrateSlider.value = 375;
                            self.bitrateField.text = "375"
                        }
                        break
                    case (360,640):
                        self.bitrateSlider.minimumValue = 275
                        self.bitrateSlider.maximumValue = 1300
                        if(self.sceneControl.selectedSegmentIndex==0){//视频通话
                            self.bitrateSlider.value = 550;
                            self.bitrateField.text = "550"
                        }else{//直播
                            self.bitrateSlider.value = 900;
                            self.bitrateField.text = "900"
                        }
                        break
                    case (480,480):
                        self.bitrateSlider.minimumValue = 175
                        self.bitrateSlider.maximumValue = 925
                        if(self.sceneControl.selectedSegmentIndex==0){//视频通话
                            self.bitrateSlider.value = 350;
                            self.bitrateField.text = "350"
                        }else{//直播
                            self.bitrateSlider.value = 525;
                            self.bitrateField.text = "525"
                        }
                        break
                    case (480,640):
                        self.bitrateSlider.minimumValue = 300
                        self.bitrateSlider.maximumValue = 1300
                        if(self.sceneControl.selectedSegmentIndex==0){//视频通话
                            self.bitrateSlider.value = 600;
                            self.bitrateField.text = "600"
                        }else{//直播
                            self.bitrateSlider.value=900;
                            self.bitrateField.text = "900"
                        }
                        break
                    case (540,960):
                        self.bitrateSlider.minimumValue = 425
                        self.bitrateSlider.maximumValue = 1700
                        if(self.sceneControl.selectedSegmentIndex==0){//视频通话
                            self.bitrateSlider.value = 850;
                            self.bitrateField.text = "850"
                        }else{//直播
                            self.bitrateSlider.value=1300;
                            self.bitrateField.text = "1300"
                        }
                        break
                    case (720,1280):
                        self.bitrateSlider.minimumValue = 600
                        self.bitrateSlider.maximumValue = 2200
                        if(self.sceneControl.selectedSegmentIndex==0){//视频通话
                             self.bitrateSlider.value=1200;
                             self.bitrateField.text = "1200"
                        }else{//直播
                             self.bitrateSlider.value=1800;
                             self.bitrateField.text = "1800"
                        }
                        break
                    case (1080,1920):
                        self.bitrateSlider.minimumValue = 900
                        self.bitrateSlider.maximumValue = 2400
                        if(self.sceneControl.selectedSegmentIndex==0){//视频通话
                            self.bitrateSlider.value=1800;
                            self.bitrateField.text = "1800"
                        }else{//直播
                            self.bitrateSlider.value=2000;
                            self.bitrateField.text = "2000"
                        }
                        break
                    default:
                        break
                    }
                    
                }
            }
            alert.addAction(action)
        }
        present(alert, animated: true, completion: nil)
    }

    func buildVideoConfig() -> AgoraVideoEncoderConfiguration {
        let videoConfig = AgoraVideoEncoderConfiguration()
        if resolution.width > resolution.height {
            (resolution.width, resolution.height) = (resolution.height, resolution.width)
        }
        videoConfig.dimensions = resolution
        videoConfig.bitrate = Int(bitrateSlider.value)
        let rateValue = Int(fpsControl.titleForSegment(at: fpsControl.selectedSegmentIndex)!)!
        videoConfig.frameRate = AgoraVideoFrameRate(rawValue: rateValue) ?? AgoraVideoFrameRate.fps15
        return videoConfig
    }

    func buildAudioConfig() -> AgoraAudioProfile {
        switch self.audioQualityControl.selectedSegmentIndex {
        case 0:
            return .speechStandard
        case 1:
            return .default
        case 2:
            return .musicHighQualityStereo
        default: // case 0
            return .speechStandard
        }
    }
}

// MARK: - ScrollView Events
extension TRTCNewViewController : UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.view.endEditing(true)
    }
}

// MARK: - UITextFieldDelegate
extension TRTCNewViewController : UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        textField.inputAccessoryView = keyboardToolbar
        return true
    }
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.contains(where: { (chr:Character) -> Bool in
            return !chr.isNumber
        }) {
            return false
        }
        return true
    }
}

// MARK: - User Actions
extension TRTCNewViewController {
    @IBAction func onSceneChanged(_ sender: UISegmentedControl) {
        roleControl.isEnabled = sender.selectedSegmentIndex == 1
        if(sender.selectedSegmentIndex==0){//视频通话
            self.bitrateSlider.value = self.bitrateSlider.minimumValue*2;
            self.roleControl.selectedSegmentIndex = 0;
        }else{//直播
            self.bitrateSlider.value = self.bitrateSlider.maximumValue-400;
        }
        self.bitrateField.text = String(Int(bitrateSlider.value))
    }

    @IBAction func onBitrateChanged(_ sender: Any) {
        if let textField = sender as? UITextView {
            bitrateSlider.value = Float(textField.text)?.rounded() ?? bitrateSlider.minimumValue
        } else if let slider = sender as? UISlider{
            bitrateField.text = String(Int(slider.value))
        }
    }
    @IBAction func onResolutionChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == sender.numberOfSegments - 1 {
            showResolutionActionSheet()
        } else {
            guard let components = sender.titleForSegment(at: sender.selectedSegmentIndex)?.split(separator: "x") else {
                return
            }
            if case let (w, h)  = (String(components.first!), String(components.last!)),
                let width = Int(w),
                let height = Int(h) {
                self.resolution = CGSize(width: width, height: height)
            }
        }
    }
    @IBAction func onTapEnterRoom(_ sender: Any) {
        enterRoom()
    }
}


