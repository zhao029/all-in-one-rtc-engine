//
//  StatisticsView.swift
//  LiteAVApollo
//
//  Created by shengcui on 2020/6/17.
//  Copyright © 2020 Tencent. All rights reserved.
//

import Foundation

@objcMembers
class TRTCVideoViewConstants : NSObject {
    static let logLabelTag = 101010
}

extension TRTCVideoView {
    private func infoLabel() -> UILabel {
        var label : UILabel! = viewWithTag(TRTCVideoViewConstants.logLabelTag) as? UILabel
        if nil == label {
            label = UILabel()
            label.tag = TRTCVideoViewConstants.logLabelTag
            label.translatesAutoresizingMaskIntoConstraints = false
            label.backgroundColor = UIColor(white: 1, alpha: 0.0)
            label.numberOfLines = 0
            addSubview(label)
            addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[label]|", options: [], metrics: nil, views: ["label":label!]))
            addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[label]|", options: [], metrics: nil, views: ["label":label!]))
        } else {
            addSubview(label)
        }
        label.isHidden = self.logHidden
        return label
    }
    func update(with info: StatisticsInfo) {
        infoLabel().text = info.description()
        infoLabel().textColor = UIColor(
            red: CGFloat((0x4081 & 0x0000) >> 16) / 255.0,
            green: CGFloat((0x4081 & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(0x4081 & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}
