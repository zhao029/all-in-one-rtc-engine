//
//  AIOAgoraEngineWrapper.m
//  APIExample-OC
//
//  Created by CY zhao on 2024/3/13.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import "AIOAgoraEngineWrapper.h"

@interface AIOAgoraEngineWrapper()
@property (nonatomic, strong) AgoraRtcEngineKit *engine;
@end

@implementation AIOAgoraEngineWrapper

static AIOAgoraEngineWrapper *sharedWrapper = nil;
static dispatch_once_t onceToken;

+ (instancetype _Nonnull)sharedEngineWithAppId:(NSString *_Nonnull)appId
                                               delegate:(id<AgoraRtcEngineDelegate> _Nullable)delegate {
    dispatch_once(&onceToken, ^{
        sharedWrapper = [[AIOAgoraEngineWrapper alloc] initWithAppID:appId delegate:delegate];
    });
    return sharedWrapper;
}

+ (instancetype _Nonnull)sharedEngineWithConfig:(AgoraRtcEngineConfig *_Nonnull)config
                                       delegate:(id<AgoraRtcEngineDelegate> _Nullable)delegate {
    dispatch_once(&onceToken, ^{
        sharedWrapper = [[AIOAgoraEngineWrapper alloc] initWithConfig:config delegate:delegate];
    });
    return sharedWrapper;
}

+ (void)destroy {
    @synchronized (self) {
        if (sharedWrapper == nil) {
            return;
        }
        [AgoraRtcEngineKit destroy];
        sharedWrapper = nil;
        onceToken = 0;
    }
}

- (instancetype)initWithAppID:(NSString *)appID delegate:(id<AgoraRtcEngineDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
        _engine = [AgoraRtcEngineKit sharedEngineWithAppId:appID delegate:delegate];
    }
    return self;
}

- (instancetype)initWithConfig:(AgoraRtcEngineConfig *)config delegate:(id<AgoraRtcEngineDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
        _engine = [AgoraRtcEngineKit sharedEngineWithConfig:config delegate:delegate];
    }
    return self;
}

- (void)setDelegate:(id<AgoraRtcEngineDelegate>)delegate {
    _delegate = delegate;
    self.engine.delegate = delegate;
}

- (int)adjustPlaybackSignalVolume:(NSInteger)volume {
    return [self.engine adjustPlaybackSignalVolume:volume];
}

- (int)adjustRecordingSignalVolume:(NSInteger)volume {
    return [self.engine adjustRecordingSignalVolume:volume];
}

- (int)adjustUserPlaybackSignalVolume:(NSUInteger)uid volume:(int)volume { 
    return [self.engine adjustUserPlaybackSignalVolume:uid volume:volume];
}

- (int)disableAudio { 
    return [self.engine disableAudio];
}

- (int)disableVideo { 
    return [self.engine disableVideo];
}

- (int)enableAudio { 
    return [self.engine enableAudio];
}

- (int)enableAudioVolumeIndication:(NSInteger)interval smooth:(NSInteger)smooth reportVad:(BOOL)reportVad { 
    return [self.engine enableAudioVolumeIndication:interval smooth:smooth reportVad:reportVad];
}

- (int)enableInEarMonitoring:(BOOL)enabled { 
    return [self.engine enableInEarMonitoring:enabled];
}

- (int)enableLocalAudio:(BOOL)enabled { 
    return [self.engine enableLocalAudio:enabled];
}

- (int)enableVideo { 
    return [self.engine enableVideo];
}

- (AgoraConnectionState)getConnectionState {
    return [self.engine getConnectionState];
}

- (BOOL)isSpeakerphoneEnabled { 
    return [self.engine isSpeakerphoneEnabled];
}

- (int)joinChannelByToken:(NSString * _Nullable)token channelId:(NSString * _Nonnull)channelId info:(NSString * _Nullable)info uid:(NSUInteger)uid joinSuccess:(void (^ _Nullable)(NSString * _Nonnull, NSUInteger, NSInteger))joinSuccessBlock { 
    return [self.engine joinChannelByToken:token channelId:channelId info:info uid:uid joinSuccess:joinSuccessBlock];
}

- (int)joinChannelByToken:(NSString * _Nullable)token channelId:(NSString * _Nonnull)channelId uid:(NSUInteger)uid mediaOptions:(AgoraRtcChannelMediaOptions * _Nonnull)mediaOptions joinSuccess:(void (^ _Nullable)(NSString * _Nonnull, NSUInteger, NSInteger))joinSuccessBlock { 
    return [self.engine joinChannelByToken:token channelId:channelId uid:uid mediaOptions:mediaOptions joinSuccess:joinSuccessBlock];
}

- (int)leaveChannel:(void (^ _Nullable)(AgoraChannelStats * _Nonnull))leaveChannelBlock { 
    return [self.engine leaveChannel:leaveChannelBlock];
}

- (int)muteAllRemoteAudioStreams:(BOOL)mute { 
    return [self.engine muteAllRemoteAudioStreams:mute];
}

- (int)muteAllRemoteVideoStreams:(BOOL)mute { 
    return [self.engine muteAllRemoteVideoStreams:mute];
}

- (int)muteLocalAudioStream:(BOOL)mute { 
    return [self.engine muteLocalAudioStream:mute];
}

- (int)muteLocalVideoStream:(BOOL)mute { 
    return [self.engine muteLocalVideoStream:mute];
}

- (int)muteRemoteAudioStream:(NSUInteger)uid mute:(BOOL)mute { 
    return [self.engine muteRemoteAudioStream:uid mute:mute];
}

- (int)muteRemoteVideoStream:(NSUInteger)uid mute:(BOOL)mute { 
    return [self.engine muteRemoteVideoStream:uid mute:mute];
}

- (int)setAudioProfile:(AgoraAudioProfile)profile { 
    return [self.engine setAudioProfile:profile];
}

- (int)setChannelProfile:(AgoraChannelProfile)profile { 
    return [self.engine setChannelProfile:profile];
}

- (int)setClientRole:(AgoraClientRole)role { 
    return [self.engine setClientRole:role];
}

- (int)setClientRole:(AgoraClientRole)role options:(AgoraClientRoleOptions * _Nullable)options { 
    return [self.engine setClientRole:role options:options];
}

- (int)setDefaultAudioRouteToSpeakerphone:(BOOL)defaultToSpeaker { 
    return [self.engine setDefaultAudioRouteToSpeakerphone:defaultToSpeaker];
}

- (int)setEnableSpeakerphone:(BOOL)enableSpeaker { 
    return [self.engine setEnableSpeakerphone:enableSpeaker];
}

- (int)setInEarMonitoringVolume:(NSInteger)volume { 
    return [self.engine setInEarMonitoringVolume:volume];
}

- (int)setLocalRenderMode:(AgoraVideoRenderMode)mode mirror:(AgoraVideoMirrorMode)mirror { 
    return [self.engine setLocalRenderMode:mode mirror:mirror];
}

- (int)setRemoteRenderMode:(NSUInteger)uid mode:(AgoraVideoRenderMode)mode mirror:(AgoraVideoMirrorMode)mirror { 
    return [self.engine setRemoteRenderMode:uid mode:mode mirror:mirror];
}

- (int)setVideoEncoderConfiguration:(AgoraVideoEncoderConfiguration * _Nonnull)config { 
    return [self.engine setVideoEncoderConfiguration:config];
}

- (int)setupLocalVideo:(AgoraRtcVideoCanvas * _Nullable)local { 
    return [self.engine setupLocalVideo:local];
}

- (int)setupRemoteVideo:(AgoraRtcVideoCanvas * _Nonnull)remote { 
    return [self.engine setupRemoteVideo:remote];
}

- (int)startPreview { 
    return [self.engine startPreview];
}

- (int)stopPreview { 
    return [self.engine stopPreview];
}

- (int)updateChannelWithMediaOptions:(AgoraRtcChannelMediaOptions * _Nonnull)mediaOptions { 
    return [self.engine updateChannelWithMediaOptions:mediaOptions];
}

- (int)switchCamera { 
    return [self.engine switchCamera];
}

#pragma mark - TRTC only method

- (void)showDebugView:(NSInteger)showType {
    
}

- (void)setDebugViewMargin:(NSString *)userId margin:(UIEdgeInsets)margin {
    
}

@end
