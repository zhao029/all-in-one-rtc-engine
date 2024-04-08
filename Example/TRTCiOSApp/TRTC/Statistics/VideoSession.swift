//
//  VideoSession.swift
//  OpenLive
//
//  Created by GongYuhua on 6/25/16.
//  Copyright © 2016 Agora. All rights reserved.
//

import UIKit
import AgoraRtcKit

class VideoSession: NSObject {
    enum SessionType {
        case local, remote
        
        var isLocal: Bool {
            switch self {
            case .local:  return true
            case .remote: return false
            }
        }
    }
    
    var uid: UInt
    @objc var hostingView: TRTCVideoView?
    var type: SessionType
    var statistics: StatisticsInfo
    
    @objc convenience init(userID: UInt, view: TRTCVideoView) {
        self.init(uid: userID, view: view, type: .remote)
    }
    @objc func setToLocalSession() {
        type = .local
        //别忘了将成员变量的type也设成Local
        statistics = StatisticsInfo(type: StatisticsInfo.StatisticsType.local(StatisticsInfo.LocalInfo()))
    }
    init(uid: UInt, view: TRTCVideoView, type: SessionType = .remote) {
        self.uid = uid
        self.type = type
        hostingView = view
        
        switch type {
        case .local:  statistics = StatisticsInfo(type: StatisticsInfo.StatisticsType.local(StatisticsInfo.LocalInfo()))
        case .remote: statistics = StatisticsInfo(type: StatisticsInfo.StatisticsType.remote(StatisticsInfo.RemoteInfo()))
        }
    }
}

extension VideoSession {
    static func localSession(view: TRTCVideoView) -> VideoSession {
        return VideoSession(uid: 0, view: view, type: .local)
    }
    @objc func update(resolution: CGSize) {
        updateInfo(resolution: resolution)
    }
    @objc func update(txQuality:AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        updateInfo(resolution: nil, fps: nil, txQuality: txQuality, rxQuality: rxQuality)
    }
    func updateInfo(resolution: CGSize? = nil, fps: Int? = nil, txQuality: AgoraNetworkQuality? = nil, rxQuality: AgoraNetworkQuality? = nil) {
        if let resolution = resolution {
            statistics.dimension = resolution
        }
        
        if let fps = fps {
            statistics.fps = fps
        }
        
        if let txQuality = txQuality {
            statistics.txQuality = txQuality
        }
        
        if let rxQuality = rxQuality {
            statistics.rxQuality = rxQuality
        }
        
        hostingView?.update(with: statistics)
    }
    
    @objc func updateChannelStats(_ stats: AgoraChannelStats) {
        guard self.type.isLocal else {
            return
        }
        statistics.updateChannelStats(stats)
        hostingView?.update(with: statistics)
    }
    
    @objc func updateVideoStats(_ stats: AgoraRtcRemoteVideoStats) {
        guard !self.type.isLocal else {
            return
        }
        statistics.fps = Int(stats.rendererOutputFrameRate)
        if stats.width > 0 && stats.height > 0 {
            statistics.dimension = CGSize(width: CGFloat(stats.width), height: CGFloat(stats.height))
        }
        statistics.updateVideoStats(stats)
        hostingView?.update(with: statistics)
    }
    
    @objc func updateAudioStats(_ stats: AgoraRtcRemoteAudioStats) {
        guard !self.type.isLocal else {
            return
        }
        statistics.updateAudioStats(stats)
        hostingView?.update(with: statistics)
    }
}
