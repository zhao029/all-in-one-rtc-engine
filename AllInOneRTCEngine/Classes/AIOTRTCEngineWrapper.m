//
//  AIOTRTCEngineWrapper.m
//  APIExample-OC
//
//  Created by CY zhao on 2024/2/29.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import "AIOTRTCEngineWrapper.h"
#import "AIOTRTCEngineWrapperUtils.h"
@import TXLiteAVSDK_TRTC;

static NSString * const kStrGroupIDKey = @"strGroupId";

typedef NS_ENUM(NSInteger, WrapperErrorCode) {
    WrapperErrorCodeNoError = 0,
    WrapperErrorCodeFailed = -1,
    WrapperErrorCodeInvalidArgument = -2,
};

@interface AIOTRTCEngineWrapper () <TRTCCloudDelegate>
@property (nonatomic, strong) TRTCCloud *trtcCloud;
@property (nonatomic,assign) TRTCAppScene scene;
@property (nonatomic, assign) UInt32 sdkAppId;
@property (nonatomic, strong) TRTCParams *TRTCParam;

@property (nonatomic, copy) void(^joinSuccessCallback)(NSString * _Nonnull channel, NSUInteger uid, NSInteger elapsed);
@property (nonatomic, copy) void(^leaveChannelCallback)(AgoraChannelStats * _Nonnull stat);
@property (nonatomic, assign) BOOL isSelfInRoom;

@property (nonatomic, assign)AgoraClientRole pendingRole;
@property (nonatomic, assign)AgoraClientRole currentRole;

@property (nonatomic, assign) BOOL isAudioEnabled;
@property (nonatomic, assign) BOOL isVideoEnabled;

@property (nonatomic, assign) TRTCAudioQuality currentAudioQuality;
@property (nonatomic, assign) BOOL speakerphoneEnabled;
@property (nonatomic, assign) BOOL didSetDefaultAudioRoute;

@property (nonatomic, assign) BOOL useFrontCamera;
@property (nonatomic, strong) AgoraRtcVideoCanvas *localCanvas;

@property (nonatomic, assign) AgoraConnectionState connectionState;
@property (nonatomic, assign) CFAbsoluteTime rejoinStartTime;
@property (nonatomic, assign) CFTimeInterval enterRoomTime;

@end

@implementation AIOTRTCEngineWrapper

static AIOTRTCEngineWrapper *sharedWrapper = nil;
static dispatch_once_t onceToken;

+ (instancetype _Nonnull)sharedEngineWithAppId:(NSString *_Nonnull)appId
                                               delegate:(id<AgoraRtcEngineDelegate> _Nullable)delegate {
    LOGI("init TRTCEngineWrapper with appId");
    dispatch_once(&onceToken, ^{
        sharedWrapper = [[AIOTRTCEngineWrapper alloc] initWithAppID:appId delegate:delegate];
    });
    return sharedWrapper;
}

+ (instancetype _Nonnull)sharedEngineWithConfig:(AgoraRtcEngineConfig *_Nonnull)config
                                       delegate:(id<AgoraRtcEngineDelegate> _Nullable)delegate {
    LOGI("init TRTCEngineWrapper with config");
    dispatch_once(&onceToken, ^{
        sharedWrapper = [[AIOTRTCEngineWrapper alloc] initWithConfig:config delegate:delegate];
    });
    return sharedWrapper;
}

+ (void)destroy {
    LOGI("destory TRTCEngineWrapper");
    @synchronized (self) {
        if (sharedWrapper == nil) {
            LOGI("TRTCEngineWrapper instance is nil");
            return;
        }
        [TRTCCloud destroySharedInstance];
        sharedWrapper = nil;
        onceToken = 0;
    }
}

- (instancetype)initWithAppID:(NSString *)appID delegate:(id<AgoraRtcEngineDelegate>)delegate {
    LOGI("TRTCEngineWrapper, %s appID:%s, delegate:%p",  __FUNCTION__, [appID UTF8String], delegate);
    //初始化成员变量纪录远端播放音量
    if (self = [super init]) {
        _delegate = delegate;
        _sdkAppId = [appID intValue];
        _trtcCloud = [TRTCCloud sharedInstance];
        [_trtcCloud addDelegate:self];
        _isAudioEnabled = YES;
        _isVideoEnabled = NO;
        [self setFramework];
        [self setupDefaultParams];
    }
    return self;
}

- (instancetype)initWithConfig:(AgoraRtcEngineConfig *)config delegate:(id<AgoraRtcEngineDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
        _sdkAppId = [config.appId intValue];
        _scene = [self transToTRTCAppScene:config.channelProfile];
        [self setupLogConfig:config.logConfig];
        _trtcCloud = [TRTCCloud sharedInstance];
        [_trtcCloud addDelegate:self];
        _isAudioEnabled = YES;
        _isVideoEnabled = NO;
        [self setFramework];
        [self setupDefaultParams];
    }
    return self;
}

- (void)setupLogConfig:(AgoraLogConfig *)logConfig {
    if (!logConfig) {
        return;
    }
    [self setLogFile:logConfig.filePath];
    [self setLogFilter:logConfig.level];
}

- (void)setupDefaultParams {
    _didSetDefaultAudioRoute = NO;
    _pendingRole = AgoraClientRoleAudience;
    _currentRole = AgoraClientRoleBroadcaster;
    _currentAudioQuality = TRTCAudioQualityDefault;
    _useFrontCamera = YES;
    _connectionState = AgoraConnectionStateDisconnected;
    _isSelfInRoom = NO;
}

#pragma mark - RTCEngine
- (int)joinChannelByToken:(NSString * _Nullable)token channelId:(NSString * _Nonnull)channelId info:(NSString * _Nullable)info uid:(NSUInteger)uid joinSuccess:(void (^ _Nullable)(NSString * _Nonnull, NSUInteger, NSInteger))joinSuccessBlock {
    LOGI("TRTCEngineWrapper, %s token_length:%d, channelId:%s, info:%s, uid:%ld joinSuccess:%p",  __FUNCTION__, token.length, [channelId UTF8String], [info UTF8String], uid, joinSuccessBlock);
    self.connectionState = AgoraConnectionStateConnecting;
    self.joinSuccessCallback = joinSuccessBlock;
    self.enterRoomTime = CFAbsoluteTimeGetCurrent();
    
    TRTCParams *param = [[TRTCParams alloc] init];
    param.sdkAppId = self.sdkAppId;
    param.userId = [NSString stringWithFormat:@"%lu", (unsigned long)uid];
    param.userSig = token;
    param.role = [self transToTRTCRole:self.pendingRole];
    param.strRoomId = channelId;
    
    self.TRTCParam = param;
    self.currentRole = self.pendingRole;
    
    [self.trtcCloud enterRoom:param appScene:self.scene];
    
    [self setupAudioRoute];
    if (self.isAudioEnabled && self.currentRole == AgoraClientRoleBroadcaster) {
        [self.trtcCloud startLocalAudio:self.currentAudioQuality];
    }
    return WrapperErrorCodeNoError;
}

- (void)setupAudioRoute {
    if (self.didSetDefaultAudioRoute) {
        return;
    }
    if (self.isVideoEnabled || self.scene == TRTCAppSceneLIVE) {
        // Agora视频通话、视频直播、语音直播场景默认走扬声器
        [self.trtcCloud setAudioRoute: TRTCAudioModeSpeakerphone];
    } else if (self.isAudioEnabled && self.scene == TRTCAppSceneVideoCall) {
        // Agora语音通话场景默认走听筒
        [self.trtcCloud setAudioRoute: TRTCAudioModeEarpiece];
    }
}

- (int)joinChannelByToken:(NSString * _Nullable)token channelId:(NSString * _Nonnull)channelId uid:(NSUInteger)uid mediaOptions:(AgoraRtcChannelMediaOptions * _Nonnull)mediaOptions joinSuccess:(void (^ _Nullable)(NSString * _Nonnull, NSUInteger, NSInteger))joinSuccessBlock {
    LOGI("TRTCEngineWrapper, %s token_length:%d, channelId:%s, uid:%ld joinSuccess:%p",  __FUNCTION__, token.length, [channelId UTF8String], uid, joinSuccessBlock);
    [self muteLocalVideoStream:!mediaOptions.publishCameraTrack];
    [self muteLocalAudioStream:!mediaOptions.publishMicrophoneTrack];
    [self.trtcCloud setDefaultStreamRecvMode:mediaOptions.autoSubscribeAudio video:mediaOptions.autoSubscribeVideo];
    [self setChannelProfile:mediaOptions.channelProfile];
    [self joinChannelByToken:token channelId:channelId info:@"" uid:uid joinSuccess:joinSuccessBlock];
    [self setClientRole:mediaOptions.clientRoleType];
    return WrapperErrorCodeNoError;
}

- (int)leaveChannel:(void (^ _Nullable)(AgoraChannelStats * _Nonnull))leaveChannelBlock {
    LOGI("TRTCEngineWrapper, %s leaveChannelBlock:%p",  __FUNCTION__, leaveChannelBlock);
    self.connectionState = AgoraConnectionStateDisconnected;
    self.leaveChannelCallback = leaveChannelBlock;
    
    [self.trtcCloud exitRoom];
    [self resetParams];
    
    return WrapperErrorCodeNoError;
}

- (int)setChannelProfile:(AgoraChannelProfile)profile {
    LOGI("TRTCEngineWrapper, %s, profile: %@",  __FUNCTION__, profile);
    self.scene = [self transToTRTCAppScene:profile];
    return WrapperErrorCodeNoError;
}

- (int)updateChannelWithMediaOptions:(AgoraRtcChannelMediaOptions *)mediaOptions {
    LOGI("TRTCEngineWrapper, %s, options: %@",  __FUNCTION__, mediaOptions);
    [self muteLocalVideoStream:!mediaOptions.publishCameraTrack];
    [self muteLocalAudioStream:!mediaOptions.publishMicrophoneTrack];
    [self setClientRole:mediaOptions.clientRoleType];
    return WrapperErrorCodeNoError;
}

- (int)setClientRole:(AgoraClientRole)role {
    LOGI("TRTCEngineWrapper, %s agora_role:%d",  __FUNCTION__, role);
    
    self.pendingRole = role;
    
    TRTCRoleType trtcRole = [self transToTRTCRole:role];
    [self.trtcCloud switchRole: trtcRole];
    return WrapperErrorCodeNoError;
}

- (int)setClientRole:(AgoraClientRole)role options:(AgoraClientRoleOptions *)options {
    LOGI("TRTCEngineWrapper, %s agora_role:%d",  __FUNCTION__, role);
    return [self setClientRole:role];
}

-  (AgoraConnectionState)getConnectionState {
    LOGI("TRTCEngineWrapper, %s connectionState:%ld",  __FUNCTION__, self.connectionState);
    return self.connectionState;
}

#pragma mark - Core Audio

- (int)muteAllRemoteAudioStreams:(BOOL)mute {
    AUDIO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s mute:%d",  __FUNCTION__, mute);
    [self.trtcCloud muteAllRemoteAudio:mute];
    return WrapperErrorCodeNoError;
}

- (int)muteLocalAudioStream:(BOOL)mute {
    AUDIO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s mute:%d",  __FUNCTION__, mute);
    [self.trtcCloud muteLocalAudio:mute];
    return WrapperErrorCodeNoError;
}

- (int)muteRemoteAudioStream:(NSUInteger)uid mute:(BOOL)mute {
    AUDIO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s uid:%d, mute:%d",  __FUNCTION__, uid, mute);
    [self.trtcCloud muteRemoteAudio:@(uid).stringValue mute:mute];
    return WrapperErrorCodeNoError;
}

- (int)adjustUserPlaybackSignalVolume:(NSUInteger)uid volume:(int)volume {
    AUDIO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s uid:%d, volume:%d",  __FUNCTION__, uid, volume);
    [self.trtcCloud setRemoteAudioVolume:@(uid).stringValue volume:volume];
    return WrapperErrorCodeNoError;
}

- (int)adjustPlaybackSignalVolume:(NSInteger)volume {
    AUDIO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s volume:%d",  __FUNCTION__, volume);
    NSInteger actualVolume = (float)volume / (float)4;
    [self.trtcCloud setAudioPlayoutVolume:actualVolume];
    return WrapperErrorCodeNoError;
}

- (int)disableAudio {
    LOGI("TRTCEngineWrapper, %s",  __FUNCTION__);
    self.isAudioEnabled = NO;
    
    if (self.isSelfInRoom) {
        [self.trtcCloud stopLocalAudio];
        [self.trtcCloud muteLocalAudio:YES];
        [self.trtcCloud muteAllRemoteAudio:YES];
    }
    return WrapperErrorCodeNoError;
}

- (int)enableAudio {
    LOGI("TRTCEngineWrapper, %s",  __FUNCTION__);
    self.isAudioEnabled = YES;
    
    if (self.isSelfInRoom) {
        [self.trtcCloud startLocalAudio:self.currentAudioQuality];
        [self.trtcCloud muteLocalAudio:NO];
        [self.trtcCloud muteAllRemoteAudio:NO];
    }
    return WrapperErrorCodeNoError;
}

- (int)enableAudioVolumeIndication:(NSInteger)interval smooth:(NSInteger)smooth reportVad:(BOOL)reportVad {
    AUDIO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s interval:%d, smooth:%d, report_vad:%d",  __FUNCTION__, interval, smooth, reportVad);
    TRTCAudioVolumeEvaluateParams *parma = [[TRTCAudioVolumeEvaluateParams alloc] init];
    parma.enableVadDetection = reportVad;
    parma.interval = interval;
    if (interval <= 0) {
        [self.trtcCloud enableAudioVolumeEvaluation:NO withParams:parma];
    } else {
        [self.trtcCloud enableAudioVolumeEvaluation:YES withParams:parma];
    }
    return WrapperErrorCodeNoError;
}

- (int)setAudioProfile:(AgoraAudioProfile)profile {
    LOGI("TRTCEngineWrapper, %s profile:%d",  __FUNCTION__, profile);
    self.currentAudioQuality = [self transToTRTCAudioQuality:profile];
    return WrapperErrorCodeNoError;
}

- (int)adjustRecordingSignalVolume:(NSInteger)volume {
    AUDIO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s volume:%d",  __FUNCTION__, volume);
    float actualVolume = (float)volume/(float)4;
    [self.trtcCloud setAudioCaptureVolume:actualVolume];
    return WrapperErrorCodeNoError;
}

- (int)enableInEarMonitoring:(BOOL)enabled {
    LOGI("TRTCEngineWrapper, %s enabled:%d",  __FUNCTION__, enabled);
    TXAudioEffectManager *manager = [self.trtcCloud getAudioEffectManager];
    NSAssert(manager, @"TRTC get Audio Manger fail, please try later");
    [manager enableVoiceEarMonitor:enabled];
    return WrapperErrorCodeNoError;
}

- (int)enableLocalAudio:(BOOL)enabled {
    AUDIO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s enabled:%d",  __FUNCTION__, enabled);
    if (enabled) {
        [self.trtcCloud startLocalAudio:self.currentAudioQuality];
    } else {
        [self.trtcCloud stopLocalAudio];
    }
    return WrapperErrorCodeNoError;
}

- (int)setInEarMonitoringVolume:(NSInteger)volume {
    LOGI("TRTCEngineWrapper, %s volume:%d",  __FUNCTION__, volume);
    float actualVolume = (float)volume/(float)4;
    TXAudioEffectManager *manager = [_trtcCloud getAudioEffectManager];
    NSAssert(manager, @"TRTC get Audio Manger fail, please try later");
    [manager setVoiceEarMonitorVolume:actualVolume];
    return WrapperErrorCodeNoError;
}

#pragma mark Audio Routing Controller

#if TARGET_OS_IPHONE
- (int)setDefaultAudioRouteToSpeakerphone:(BOOL)defaultToSpeaker {
    LOGI("TRTCEngineWrapper, %s defaultToSpeaker:%d",  __FUNCTION__, defaultToSpeaker);
    self.didSetDefaultAudioRoute = YES;
    [self.trtcCloud setAudioRoute:defaultToSpeaker?TRTCAudioModeSpeakerphone:TRTCAudioModeEarpiece];
    return WrapperErrorCodeNoError;
}

- (int)setEnableSpeakerphone:(BOOL)enableSpeaker {
    LOGI("TRTCEngineWrapper, %s enableSpeaker:%d",  __FUNCTION__, enableSpeaker);
    [self.trtcCloud setAudioRoute:enableSpeaker?TRTCAudioModeSpeakerphone:TRTCAudioModeEarpiece];
    return WrapperErrorCodeNoError;
}

- (BOOL)isSpeakerphoneEnabled {
    LOGI("TRTCEngineWrapper, %s _didSetToSpeakerPhone:%d",  __FUNCTION__, self.speakerphoneEnabled);
    return self.speakerphoneEnabled;
}
#endif

#pragma mark - Core Video

- (int)disableVideo {
    LOGI("TRTCEngineWrapper, %s",  __FUNCTION__);
    self.isVideoEnabled = NO;
    
    if (self.isSelfInRoom) {
        [self.trtcCloud stopLocalPreview];
        [self.trtcCloud muteLocalVideo:TRTCVideoStreamTypeBig mute:YES];
        [self.trtcCloud muteAllRemoteVideoStreams:YES];
    }
    
    return WrapperErrorCodeNoError;
}

- (int)enableVideo {
    LOGI("TRTCEngineWrapper, %s",  __FUNCTION__);
    self.isVideoEnabled = YES;
    
    if (self.isSelfInRoom) {
        [self.trtcCloud muteLocalVideo:TRTCVideoStreamTypeBig mute:NO];
        [self.trtcCloud muteAllRemoteVideoStreams:NO];
    }
    
    return WrapperErrorCodeNoError;
}

- (int)muteAllRemoteVideoStreams:(BOOL)mute {
    VIDEO_SWITCH_GUARD;
    LOGI("TRTCEngineWrapper, %s mute:%d",  __FUNCTION__, mute);
    [self.trtcCloud muteAllRemoteVideoStreams:mute];
    return WrapperErrorCodeNoError;
}

- (int)muteLocalVideoStream:(BOOL)mute {
    VIDEO_SWITCH_GUARD;
    LOGI("TRTCEngineWrapper, %s mute:%d",  __FUNCTION__, mute);
    [self.trtcCloud muteLocalVideo:TRTCVideoStreamTypeBig mute:mute];
    return WrapperErrorCodeNoError;
}

- (int)muteRemoteVideoStream:(NSUInteger)uid mute:(BOOL)mute {
    VIDEO_SWITCH_GUARD;
    LOGI("TRTCEngineWrapper, %s uid:%d, mute:%d",  __FUNCTION__, uid, mute);
    [self.trtcCloud muteRemoteVideoStream:@(uid).stringValue streamType:TRTCVideoStreamTypeBig mute:mute];
    return WrapperErrorCodeNoError;
}

- (int)setVideoEncoderConfiguration:(AgoraVideoEncoderConfiguration * _Nonnull)config {
    VIDEO_SWITCH_GUARD;
    LOGI("TRTCEngineWrapper, %s size:%s bitrate:%d minBitrate:%d fps:%d degrationPref:%d orientationMode:%d mirrorMode:%d",  __FUNCTION__,  [NSStringFromCGSize(config.dimensions) UTF8String], config.bitrate, config.minBitrate, config.frameRate, config.degradationPreference, config.orientationMode, config.mirrorMode);
    
    NSDictionary *encodeParam = [self generateVideoEncoderParam:config];
    [self setVideoEncodeParamInner:encodeParam];

    TRTCVideoQosPreference preference = config.degradationPreference == AgoraDegradationMaintainFramerate ? TRTCVideoQosPreferenceSmooth : TRTCVideoQosPreferenceClear;
    TRTCNetworkQosParam *param = [[TRTCNetworkQosParam alloc] init];
    param.controlMode = TRTCQosControlModeServer;
    param.preference = preference;
    [self.trtcCloud setNetworkQosParam:param];

    return WrapperErrorCodeNoError;
}

- (int)startPreview {
    VIDEO_SWITCH_GUARD;
    LOGI("TRTCEngineWrapper, %s",  __FUNCTION__);
    
    if (!self.localCanvas.view) {
        LOGE("TRTCEngineWrapper, %s, start Preview fail, setup local view first",  __FUNCTION__);
        return WrapperErrorCodeFailed;
    }
#if TARGET_OS_IPHONE
        [self.trtcCloud startLocalPreview:self.useFrontCamera view:self.localCanvas.view];
#else
        [self.trtcCloud startLocalPreview:self.localCanvas.view];
#endif
    return WrapperErrorCodeNoError;
}

- (int)stopPreview {
    VIDEO_SWITCH_GUARD;
    LOGI("TRTCEngineWrapper, %s",  __FUNCTION__);
    [self.trtcCloud stopLocalPreview];
    return WrapperErrorCodeNoError;
}

- (int)setLocalRenderMode:(AgoraVideoRenderMode)mode mirror:(AgoraVideoMirrorMode)mirror {
    VIDEO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s mode:%d, mirrorMode:%d",  __FUNCTION__, mode, mirror);
    TRTCRenderParams *param = [[TRTCRenderParams alloc] init];
    param.mirrorType = [self transAgoraMirrorType:mirror];
    param.fillMode = [self transAgoraVideoRenderMode:mode];
    [self.trtcCloud setLocalRenderParams:param];
    return WrapperErrorCodeNoError;
}

- (int)setRemoteRenderMode:(NSUInteger)uid mode:(AgoraVideoRenderMode)mode mirror:(AgoraVideoMirrorMode)mirror {
    VIDEO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s uid:%d, mode:%d, mirrorMode:%d",  __FUNCTION__, uid, mode, mirror);
    TRTCRenderParams *param = [[TRTCRenderParams alloc] init];
    param.fillMode = [self transAgoraVideoRenderMode:mode];
    param.mirrorType = [self transAgoraMirrorType:mirror];
    [_trtcCloud setRemoteRenderParams:@(uid).stringValue streamType:TRTCVideoStreamTypeBig params:param];
    return WrapperErrorCodeNoError;
}

- (int)setupLocalVideo:(AgoraRtcVideoCanvas *)local {
    VIDEO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s",  __FUNCTION__);
    self.localCanvas = local;
    [self.trtcCloud updateLocalView:self.localCanvas.view];
    [self setLocalRenderMode:local.renderMode mirror:local.mirrorMode];
    return WrapperErrorCodeNoError;
}

- (int)setupRemoteVideo:(AgoraRtcVideoCanvas *)remote {
    VIDEO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s remote:%p uid:%ld",  __FUNCTION__, remote, remote.uid);
    if (remote == nil) {
        return WrapperErrorCodeInvalidArgument;
    }
    if (remote.view == nil) {
        [self.trtcCloud stopRemoteView:@(remote.uid).stringValue streamType:TRTCVideoStreamTypeBig];
        return WrapperErrorCodeNoError;
    }
    [self.trtcCloud startRemoteView:@(remote.uid).stringValue streamType:TRTCVideoStreamTypeBig view:remote.view];
    [self setRemoteRenderMode:remote.uid mode:remote.renderMode mirror:remote.mirrorMode];
    return WrapperErrorCodeNoError;
}

#if TARGET_OS_IPHONE
- (int)switchCamera {
    VIDEO_SWITCH_GUARD
    LOGI("TRTCEngineWrapper, %s, use front: %d",  __FUNCTION__, !self.useFrontCamera);
    self.useFrontCamera = !self.useFrontCamera;
    
    TXDeviceManager *manager = [self.trtcCloud getDeviceManager];
    NSAssert(manager, @"TRTC get device manger fail, please try later");
    [manager switchCamera: self.useFrontCamera];
    return WrapperErrorCodeNoError;
}
#endif

#pragma mark - TRTC only method

- (void)showDebugView:(NSInteger)showType
{
    LOGI("TRTCEngineWrapper, %s showType:%d",  __FUNCTION__, showType);
    [self.trtcCloud showDebugView:showType];
}

- (void)setDebugViewMargin:(NSString *)userId margin:(TXEdgeInsets)margin
{
    LOGI("TRTCEngineWrapper, %s userId:%s  margin:%.2f,%.2f,%.2f,%.2f",  __FUNCTION__, [userId UTF8String], margin.top, margin.left, margin.bottom, margin.right);
    [self.trtcCloud setDebugViewMargin:userId margin:margin];
}

#pragma mark - TRTCCloudDelegate

- (void)onError:(TXLiteAVError)errCode errMsg:(nullable NSString *)errMsg extInfo:(nullable NSDictionary *)extInfo {
    if (errCode == ERR_CAMERA_NOT_AUTHORIZED || errCode == ERR_MIC_NOT_AUTHORIZED) {
        [self notifyPermisionError:errCode];
        return;
    }
    TXLiteAVError connectFailureCodes[] = {
        ERR_ROOM_REQUEST_IP_TIMEOUT,
        ERR_ROOM_REQUEST_ENTER_ROOM_TIMEOUT,
        ERR_ROOM_ENTER_FAIL,
        ERR_ENTER_ROOM_PARAM_NULL,
        ERR_SDK_APPID_INVALID,
        ERR_ROOM_ID_INVALID,
        ERR_USER_ID_INVALID,
        ERR_USER_SIG_INVALID,
        ERR_SERVER_INFO_SERVICE_SUSPENDED,
        ERR_SERVER_INFO_PRIVILEGE_FLAG_ERROR,
        ERR_SERVER_INFO_ECDH_GET_TINYID
    };
    for (int i = 0; i < sizeof(connectFailureCodes)/sizeof(TXLiteAVError); ++i) {
        if (errCode == connectFailureCodes[i]) {
            self.connectionState = AgoraConnectionStateFailed;
            break;
        }
    }
    LOGI("TRTCEngineWrapper, %s calling delegate: rtcEngine:%p didOccurError:%d",  __FUNCTION__, selfForDelegate, [self transErrorCode: errCode]);
    if ([self.delegate respondsToSelector:@selector(rtcEngine:didOccurError:)]) {
        [self.delegate rtcEngine:selfForDelegate didOccurError:[self transErrorCode: errCode]];
    }
}

- (void)notifyPermisionError:(TXLiteAVError)errorCode {
    AgoraPermissionType errType = AgoraPermissionTypeRecordAudio;
    if (errorCode == ERR_CAMERA_NOT_AUTHORIZED) {
        errType = AgoraPermissionTypeCamera;
    }
    if ([self.delegate respondsToSelector:@selector(rtcEngine:permissionError:)]) {
        [self.delegate rtcEngine:selfForDelegate permissionError:errType];
    }
}

- (void)onEnterRoom:(NSInteger)result {
    if (result < 0) {
        LOGE("TRTCEngineWrapper, %s join channel fail, errorCode:%d",  __FUNCTION__, result);
        return;
    }
    self.connectionState = AgoraConnectionStateConnected;
    self.isSelfInRoom = YES;
    
    if (self.joinSuccessCallback) {
        self.joinSuccessCallback(self.TRTCParam.strRoomId, self.TRTCParam.userId.integerValue, result);
        self.joinSuccessCallback = nil;
        return;
    }
    if ([self.delegate respondsToSelector:@selector(rtcEngine:didJoinChannel:withUid:elapsed:)]) {
        [self.delegate rtcEngine:(AgoraRtcEngineKit *)self
                  didJoinChannel:self.TRTCParam.strRoomId
                         withUid:self.TRTCParam.userId.integerValue
                         elapsed:result];
    }
 
}

- (void)onExitRoom:(NSInteger)reason {
    self.isSelfInRoom = NO;
    //TODO: pass real Statistics
    AgoraChannelStats *stats = [[AgoraChannelStats alloc] init];
    if (self.leaveChannelCallback) {
        self.leaveChannelCallback(stats);
        self.leaveChannelCallback = nil;
        return;
    }
    if ([self.delegate respondsToSelector:@selector(rtcEngine:didLeaveChannelWithStats:)]) {
        [self.delegate rtcEngine:(AgoraRtcEngineKit *)self didLeaveChannelWithStats:stats];
    }
}

- (void)onSwitchRole:(TXLiteAVError)errCode errMsg:(nullable NSString *)errMsg {
    if (errCode != 0) {
        if ([self.delegate respondsToSelector:@selector(rtcEngine:didClientRoleChangeFailed:currentRole:)]) {
            LOGI("TRTCEngineWrapper, %s call delegate didClientRoleChangeFailed, errorCode: %d, currentRole: %d",  __FUNCTION__, errCode, self.currentRole);
            //Error codes do not correspond to each other, so return request timeout error.
            [self.delegate rtcEngine: (AgoraRtcEngineKit *)self didClientRoleChangeFailed:AgoraClientRoleChangeFailedRequestTimeout currentRole:self.currentRole];
        }
        return;
    }
    if ([self.delegate respondsToSelector:@selector(rtcEngine:didClientRoleChanged:newRole:newRoleOptions:)]) {
        LOGI("TRTCEngineWrapper, %s call delegate didClientRoleChanged: %d, newRole: %d",  __FUNCTION__, self.currentRole, self.pendingRole);
        [self.delegate rtcEngine: (AgoraRtcEngineKit *)self didClientRoleChanged:self.currentRole newRole:self.pendingRole newRoleOptions:nil];
    }
    self.currentRole = self.pendingRole;
}

- (void)onRemoteUserEnterRoom:(NSString *)userId {
    LOGI("TRTCEngineWrapper, %s calling delegate didJoinedOfUid:%s elapsed:%d",  __FUNCTION__, [userId UTF8String], TIME_SINCE_ROOM_ENTRY_MS);
    if ([self.delegate respondsToSelector:@selector(rtcEngine:didJoinedOfUid:elapsed:)]) {
        [self.delegate rtcEngine:selfForDelegate didJoinedOfUid:userId.longLongValue elapsed:TIME_SINCE_ROOM_ENTRY_MS];
    }
}

- (void)onRemoteUserLeaveRoom:(NSString *)userId reason:(NSInteger)reason {
    LOGI("TRTCEngineWrapper, %s calling delegate didOfflineOfUid:%s reason:%d",  __FUNCTION__, [userId UTF8String], reason);
    if ([self.delegate respondsToSelector:@selector(rtcEngine:didOfflineOfUid:reason:)]) {
        [self.delegate rtcEngine:selfForDelegate didOfflineOfUid:userId.longLongValue reason:[self transLeaveReason:reason]];
    }
}

- (void)onUserVideoAvailable:(NSString *)userId available:(BOOL)available {
    LOGI("TRTCEngineWrapper, %s calling delegate, remoteVideoStateChangedOfUid: %d, didVideoMuted:%d",  __FUNCTION__, [userId UTF8String], !available);
    AgoraVideoRemoteState remoteVIdeoState = available ? AgoraVideoRemoteStateStarting : AgoraVideoRemoteStateStopped;
    if ([self.delegate respondsToSelector:@selector(rtcEngine:remoteVideoStateChangedOfUid:state:reason:elapsed:)]) {
        [self.delegate rtcEngine:selfForDelegate remoteVideoStateChangedOfUid:userId.longLongValue
                           state:remoteVIdeoState
                          reason:AgoraVideoRemoteReasonInternal
                         elapsed:TIME_SINCE_ROOM_ENTRY_MS];
    }
}

- (void)onUserAudioAvailable:(NSString *)userId available:(BOOL)available {
    LOGI("TRTCEngineWrapper, %s calling delegate, user: %d, didAudioMuted:%d",  __FUNCTION__, [userId UTF8String], !available);
    if ([self.delegate respondsToSelector:@selector(rtcEngine:didAudioMuted:byUid:)]) {  
        [self.delegate rtcEngine:selfForDelegate didAudioMuted:!available byUid:userId.longLongValue];
    } 
}

- (void)onFirstVideoFrame:(NSString *)userId streamType:(TRTCVideoStreamType)streamType width:(int)width height:(int)height {
    if (userId.length == 0) {
        LOGI("TRTCEngineWrapper, %s calling delegate firstLocalVideoFrameWithSize:%s",  __FUNCTION__, NSStringFromCGSize(CGSizeMake(width, height)));
        if ([self.delegate respondsToSelector:@selector(rtcEngine:firstLocalVideoFrameWithSize:elapsed:sourceType:)]) {
            [self.delegate rtcEngine:selfForDelegate firstLocalVideoFrameWithSize:CGSizeMake(width, height)
                             elapsed:TIME_SINCE_ROOM_ENTRY_MS
                          sourceType:[self transToAgoraVideoSourceType:streamType]];
        }
    } else {
        LOGI("TRTCEngineWrapper, %s calling delegate firstRemoteVideoFrameOfUid:%s size: %s",  __FUNCTION__, [userId UTF8String], NSStringFromCGSize(CGSizeMake(width, height)));
        if ([self.delegate respondsToSelector:@selector(rtcEngine:firstRemoteVideoFrameOfUid:size:elapsed:)]) {
            [self.delegate rtcEngine:selfForDelegate firstRemoteVideoFrameOfUid:userId.integerValue 
                                size:CGSizeMake(width, height)
                             elapsed:TIME_SINCE_ROOM_ENTRY_MS];
        }
    }
}

- (void)onFirstAudioFrame:(NSString *)userId {
    LOGI("TRTCEngineWrapper, %s calling delegate, remoteAudioStateChangedOfUid: %d",  __FUNCTION__, [userId UTF8String]);
    if ([self.delegate respondsToSelector:@selector(rtcEngine:remoteAudioStateChangedOfUid:state:reason:elapsed:)]) {
        [self.delegate rtcEngine:selfForDelegate remoteAudioStateChangedOfUid:userId.longLongValue state:AgoraAudioRemoteStateDecoding reason:AgoraAudioRemoteReasonInternal elapsed:TIME_SINCE_ROOM_ENTRY_MS];
    }
}

- (void)onSendFirstLocalVideoFrame:(TRTCVideoStreamType)streamType {
    LOGI("TRTCEngineWrapper, %s calling delegate, firstLocalVideoFramePublishedWithElapsed, streamType: %d",  __FUNCTION__, streamType);
    if ([self.delegate respondsToSelector:@selector(rtcEngine:firstLocalVideoFramePublishedWithElapsed:sourceType:)]) {
        [self.delegate rtcEngine:selfForDelegate firstLocalVideoFramePublishedWithElapsed:TIME_SINCE_ROOM_ENTRY_MS 
                      sourceType:[self transToAgoraVideoSourceType:streamType]];
    }
}

- (void)onSendFirstLocalAudioFrame {
    LOGI("TRTCEngineWrapper, %s calling delegate firstLocalAudioFramePublished, elapsed: %ld",  __FUNCTION__, TIME_SINCE_ROOM_ENTRY_MS);
    if ([self.delegate respondsToSelector:@selector(rtcEngine:firstLocalAudioFramePublished:)]) {
        [self.delegate rtcEngine:selfForDelegate firstLocalAudioFramePublished:TIME_SINCE_ROOM_ENTRY_MS];
    }
}

- (void)onRemoteVideoStatusUpdated:(NSString *)userId 
                        streamType:(TRTCVideoStreamType)streamType
                      streamStatus:(TRTCAVStatusType)status
                            reason:(TRTCAVStatusChangeReason)reason
                         extrainfo:(nullable NSDictionary *)extrainfo {
    LOGI("TRTCEngineWrapper, %s calling delegate remoteVideoStateChangedOfUid: %@, streamType:%d",  __FUNCTION__, userId, streamType);
    // In trtc 11.7 version, this callback is triggered abnormally.
}

- (void)onRemoteAudioStatusUpdated:(NSString *)userId 
                      streamStatus:(TRTCAVStatusType)status
                            reason:(TRTCAVStatusChangeReason)reason
                         extrainfo:(nullable NSDictionary *)extrainfo {
    LOGI("TRTCEngineWrapper, %s calling delegate remoteAudioStateChangedOfUid: %@",  __FUNCTION__, userId);
    if (status != TRTCAVStatusPlaying && status != TRTCAVStatusStopped) {
        // Only playing and stopped states are handled in this callback currently.
        return;
    }
    AgoraAudioRemoteState remoteStatus = status == TRTCAVStatusPlaying ? AgoraAudioRemoteStateStarting : AgoraAudioRemoteStateStopped;
    AgoraAudioRemoteReason remoteReason = [self transToAgoraAudioRemoteReason:reason];

    if ([self.delegate respondsToSelector:@selector(rtcEngine:remoteAudioStateChangedOfUid:state:reason:elapsed:)]) {
        [self.delegate rtcEngine:selfForDelegate remoteAudioStateChangedOfUid:userId.longLongValue
                           state:remoteStatus
                          reason:remoteReason
                         elapsed:TIME_SINCE_ROOM_ENTRY_MS];
    }
}

- (void)onUserVideoSizeChanged:(NSString *)userId streamType:(TRTCVideoStreamType)streamType newWidth:(int)newWidth newHeight:(int)newHeight {
    LOGI("TRTCEngineWrapper, %s calling delegate videoSizeChangedOfSourceType userID: %@, streamType: %d, newWidth:%d, newHeight:%d",  __FUNCTION__, userId, streamType, newWidth, newHeight);
    AgoraVideoSourceType sourceType = streamType == TRTCVideoStreamTypeSub ? AgoraVideoSourceTypeScreen : AgoraVideoSourceTypeCamera;
    if ([self.delegate respondsToSelector:@selector(rtcEngine:videoSizeChangedOfSourceType:uid:size:rotation:)]) {
        [self.delegate rtcEngine:selfForDelegate videoSizeChangedOfSourceType:sourceType
                             uid:userId.longLongValue
                            size:CGSizeMake(newWidth, newHeight)
                        rotation:0];
    }
}

#pragma mark Audio Routing Controller

- (void)onConnectionLost {
    if ([self.delegate respondsToSelector:@selector(rtcEngineConnectionDidLost:)]) {
        [self.delegate rtcEngineConnectionDidLost:(AgoraRtcEngineKit *)self];
    }
    self.rejoinStartTime = CFAbsoluteTimeGetCurrent();
}

- (void)onTryToReconnect {
    self.connectionState = AgoraConnectionStateReconnecting;
}

- (void)onConnectionRecovery {
    self.connectionState = AgoraConnectionStateConnected;
    if ([self.delegate respondsToSelector:@selector(rtcEngine:didRejoinChannel:withUid:elapsed:)]) {
        [self.delegate rtcEngine:(AgoraRtcEngineKit *)self
                didRejoinChannel:self.TRTCParam.strRoomId
                         withUid:self.TRTCParam.userId.integerValue
                         elapsed:(CFAbsoluteTimeGetCurrent() - _rejoinStartTime) * 1000];
    }
    self.rejoinStartTime = 0;
}

- (void)onCameraDidReady {
    LOGI("TRTCEngineWrapper, %s calling delegate: localVideoStateChanged",  __FUNCTION__);
    if ([self.delegate respondsToSelector:@selector(rtcEngine:localVideoStateChangedOfState:reason:sourceType:)]) {
        [self.delegate rtcEngine: selfForDelegate localVideoStateChangedOfState:AgoraVideoLocalStateCapturing 
                          reason:AgoraLocalVideoStreamReasonOK
                      sourceType:AgoraVideoSourceTypeCamera];
    }
}

#if TARGET_OS_IPHONE
- (void)onAudioRouteChanged:(TRTCAudioRoute)route fromRoute:(TRTCAudioRoute)fromRoute {
    AgoraAudioOutputRouting output = [self transToAgoraAudioRoute: route];
    LOGI("TRTCEngineWrapper, %s AudioRoute Change to: %d",  __FUNCTION__, output);
    self.speakerphoneEnabled = (route == TRTCAudioModeSpeakerphone);
    if ([self.delegate respondsToSelector:@selector(rtcEngine:didAudioRouteChanged:)]) {
        [self.delegate rtcEngine:(AgoraRtcEngineKit *)self
            didAudioRouteChanged: [self transToAgoraAudioRoute: route]];
    }
}
#endif

- (void)onUserVoiceVolume:(NSArray<TRTCVolumeInfo *> *)userVolumes totalVolume:(NSInteger)totalVolume {
    NSMutableArray<AgoraRtcAudioVolumeInfo*> *remoteInfoArray = [NSMutableArray array];
    NSMutableArray<AgoraRtcAudioVolumeInfo*> *localInfoArray = [NSMutableArray array];
    @synchronized (self) {
        for (TRTCVolumeInfo *trtcInfo in userVolumes) {
            AgoraRtcAudioVolumeInfo *info = [[AgoraRtcAudioVolumeInfo alloc] init];
            info.uid = trtcInfo.userId.longLongValue;
            info.volume = trtcInfo.volume;
            info.vad = trtcInfo.vad;
            if (trtcInfo.userId.length == 0) {
                [localInfoArray addObject:info];
            } else {
                [remoteInfoArray addObject:info];
            }
        }
    }
    if ([self.delegate respondsToSelector:@selector(rtcEngine:reportAudioVolumeIndicationOfSpeakers:totalVolume:)]) {
        [self.delegate rtcEngine:selfForDelegate reportAudioVolumeIndicationOfSpeakers:localInfoArray totalVolume:totalVolume];
        [self.delegate rtcEngine:selfForDelegate reportAudioVolumeIndicationOfSpeakers:remoteInfoArray totalVolume:totalVolume];
    }
}

#pragma mark Statistics

- (void)onStatistics:(TRTCStatistics *)statistics {
    NSArray<TRTCLocalStatistics *> *trtcLocalArray = statistics.localStatistics;

    UInt32 totalLocalAudioBitrate = 0;
    UInt32 totalLocalVideoBitrate = 0;
    UInt32 totalRemoteAudioBitrate = 0;
    UInt32 totalRemoteVideoBitrate = 0;
    TRTCLocalStatistics *localBigStream = nil;
    
    for (TRTCLocalStatistics *trtcLocal in trtcLocalArray) {
        totalLocalAudioBitrate += trtcLocal.audioBitrate;
        totalLocalVideoBitrate += trtcLocal.videoBitrate;
        if (trtcLocal.streamType == TRTCVideoStreamTypeBig) {
            localBigStream = trtcLocal;
        }
    }
    for (TRTCRemoteStatistics *trtcRemote in statistics.remoteStatistics) {
        totalRemoteAudioBitrate += trtcRemote.audioBitrate;
        totalRemoteVideoBitrate += trtcRemote.videoBitrate;
    }
    
    [self reportLocalAudioStats:localBigStream withTotalAudioBitrate:totalLocalAudioBitrate];
    [self reportLocalVideoBigStreamStats:localBigStream withTotalVideoBitrate:totalLocalVideoBitrate];
    [self reportRtcStats:statistics withLocalAudioBitrate:totalLocalAudioBitrate
       localVideoBitrate:totalLocalVideoBitrate
      remoteAudioBitrate:totalRemoteAudioBitrate
      remoteVideoBitrate:totalRemoteVideoBitrate];
    
    for (TRTCRemoteStatistics *trtcRemote in statistics.remoteStatistics) {
        [self reportRemoteAuidoStats:trtcRemote];
        [self reportRemoteVideoStats:trtcRemote];
    }
}

- (void)reportLocalAudioStats:(TRTCLocalStatistics *)stats withTotalAudioBitrate:(UInt32)totalBitrate {
    AgoraRtcLocalAudioStats *localAudio = [[AgoraRtcLocalAudioStats alloc] init];
    localAudio.sentSampleRate = stats.audioSampleRate;
    localAudio.sentBitrate = totalBitrate;
    if ([self.delegate respondsToSelector:@selector(rtcEngine:localAudioStats:)]) {
        [self.delegate rtcEngine:selfForDelegate localAudioStats:localAudio];
    }
}

- (void)reportLocalVideoBigStreamStats:(TRTCLocalStatistics *)stats withTotalVideoBitrate:(UInt32)totalBitrate {
    AgoraRtcLocalVideoStats *localVideo = [[AgoraRtcLocalVideoStats alloc] init];
    localVideo.sentBitrate = totalBitrate;
    localVideo.sentFrameRate = stats.frameRate;
    localVideo.encodedFrameWidth = stats.width;
    localVideo.encodedFrameHeight = stats.height;
    if ([self.delegate respondsToSelector:@selector(rtcEngine:localVideoStats:sourceType:)]) {
        [self.delegate rtcEngine:selfForDelegate localVideoStats:localVideo sourceType:AgoraVideoSourceTypeCamera];
    }
}

- (void)reportRtcStats:(TRTCStatistics *)statistics 
 withLocalAudioBitrate:(UInt32)totalLocalAudio
     localVideoBitrate:(UInt32)totalLocalVideo
    remoteAudioBitrate:(UInt32)totalRemoteAudio
    remoteVideoBitrate:(UInt32)totalRemoteVideo {
    AgoraChannelStats *channelStats = [[AgoraChannelStats alloc] init];
    channelStats.duration = (NSInteger)(CFAbsoluteTimeGetCurrent() - _enterRoomTime) * 1000;
    channelStats.cpuAppUsage = statistics.systemCpu;
    channelStats.cpuTotalUsage = statistics.systemCpu;
    channelStats.lastmileDelay = statistics.rtt;
    channelStats.rxAudioKBitrate = totalRemoteAudio;
    channelStats.txAudioKBitrate = totalLocalAudio;
    channelStats.rxVideoKBitrate = totalRemoteVideo;
    channelStats.txVideoKBitrate = totalLocalVideo;
    channelStats.rxBytes = statistics.receivedBytes;
    channelStats.txBytes = statistics.sentBytes;
    channelStats.userCount = statistics.remoteStatistics.count;
    if ([self.delegate respondsToSelector:@selector(rtcEngine:reportRtcStats:)]) {
        [self.delegate rtcEngine:selfForDelegate reportRtcStats:channelStats];
    }
}

- (void)reportRemoteAuidoStats:(TRTCRemoteStatistics *)stats {
    AgoraRtcRemoteAudioStats *agoraStats = [[AgoraRtcRemoteAudioStats alloc] init];
    agoraStats.uid = stats.userId.longLongValue;
    agoraStats.jitterBufferDelay = stats.jitterBufferDelay;
    agoraStats.audioLossRate = stats.audioPacketLoss;
    agoraStats.receivedSampleRate = stats.audioSampleRate;
    agoraStats.receivedBitrate = stats.audioBitrate;
    agoraStats.totalFrozenTime = stats.audioTotalBlockTime;
    agoraStats.frozenRate = stats.audioBlockRate;
    agoraStats.quality = -1;
    agoraStats.networkTransportDelay = -1;
    agoraStats.numChannels = -1;
    agoraStats.totalActiveTime = -1;
    agoraStats.publishDuration = -1;
    agoraStats.qoeQuality = -1;
    agoraStats.qualityChangedReason = -1;
    agoraStats.mosValue = -1;
    if ([self.delegate respondsToSelector:@selector(rtcEngine:remoteAudioStats:)]) {
        [self.delegate rtcEngine:selfForDelegate remoteAudioStats:agoraStats];
    }
}

- (void)reportRemoteVideoStats:(TRTCRemoteStatistics *)stats {
    AgoraRtcRemoteVideoStats *agoraStats = [[AgoraRtcRemoteVideoStats alloc] init];
    agoraStats.uid = stats.userId.longLongValue;
    agoraStats.width = stats.width;
    agoraStats.height = stats.height;
    agoraStats.receivedBitrate = stats.videoBitrate;
    agoraStats.e2eDelay = stats.point2PointDelay;
    agoraStats.receivedFrameRate = stats.frameRate;
    agoraStats.frameLossRate = stats.videoPacketLoss;
    agoraStats.rxStreamType = (AgoraVideoStreamType)stats.streamType;
    agoraStats.totalFrozenTime = stats.videoTotalBlockTime;
    agoraStats.frozenRate = stats.videoBlockRate;
    agoraStats.publishDuration = -1;
    agoraStats.rendererOutputFrameRate = -1;
    agoraStats.decoderOutputFrameRate = -1;
    agoraStats.packetLossRate = -1;
    agoraStats.totalActiveTime = -1;
    agoraStats.avSyncTimeMs = -1;
    if ([self.delegate respondsToSelector:@selector(rtcEngine:remoteVideoStats:)]) {
        [self.delegate rtcEngine:selfForDelegate remoteVideoStats:agoraStats];
    }
}

#pragma mark - private functions

- (void)resetParams {
    self.connectionState = AgoraConnectionStateDisconnected;
    self.didSetDefaultAudioRoute = NO;
    self.useFrontCamera = YES;
    self.currentAudioQuality = TRTCAudioQualityDefault;
}

- (void)setLogFilter:(NSUInteger)filter {
    TRTCLogLevel logLevel = TRTCLogLevelNone;
    switch(filter){
        case AgoraLogFilterOff:
            logLevel = TRTCLogLevelNone;
            break;
        case AgoraLogFilterDebug:
            logLevel = TRTCLogLevelDebug;
            break;
        case AgoraLogFilterInfo:
            logLevel = TRTCLogLevelInfo;
            break;
        case AgoraLogFilterWarning:
            logLevel = TRTCLogLevelWarn;
            break;
        case AgoraLogFilterError:
            logLevel = TRTCLogLevelError;
            break;
        case AgoraLogFilterCritical:
            logLevel = TRTCLogLevelFatal;
            break;
        default:
            break;
    }
    [TRTCCloud setLogLevel:logLevel];
}

- (void)setLogFile:(NSString * _Nonnull)filePath {
    NSString *path = [filePath stringByDeletingLastPathComponent];
    if (path.length == 0) {
        return;
    }
    [TRTCCloud setLogDirPath:path];
}

- (TRTCAppScene)transToTRTCAppScene:(AgoraChannelProfile)profile {
    switch (profile) {
        case AgoraChannelProfileCommunication:
            return TRTCAppSceneVideoCall;
            break;
        case AgoraChannelProfileLiveBroadcasting:
            return TRTCAppSceneLIVE;
            break;
        default:
            NSLog(@"AgoraChannelProfileGame is not supported. Using as TRTCAppSceneVideoCall.");
            return TRTCAppSceneVideoCall;
            break;
    }
}

- (AgoraAudioOutputRouting)transToAgoraAudioRoute:(TRTCAudioRoute)audioRoute {
    switch (audioRoute) {
        case TRTCAudioModeSpeakerphone:
            return AgoraAudioOutputRoutingSpeakerphone;
            break;
        case TRTCAudioModeEarpiece:
            return AgoraAudioOutputRoutingEarpiece;
            break;
        default:
            return AgoraAudioOutputRoutingDefault;
            break;
    }
}

- (TRTCRoleType)transToTRTCRole:(AgoraClientRole)role {
    return role == AgoraClientRoleBroadcaster ? TRTCRoleAnchor : TRTCRoleAudience;
}

- (AgoraUserOfflineReason)transLeaveReason:(NSInteger)trtcReason {
    if (trtcReason == 0) {
        return AgoraUserOfflineReasonQuit;
    } else if (trtcReason == 1) {
        return AgoraUserOfflineReasonDropped;
    } else if (trtcReason == 3) {
        return AgoraUserOfflineReasonBecomeAudience;
    }
    return (AgoraUserOfflineReason)-1;
}


- (TRTCAudioQuality)transToTRTCAudioQuality:(AgoraAudioProfile)profile {
    switch (profile) {
        case AgoraAudioProfileSpeechStandard:
            return TRTCAudioQualitySpeech;
        case AgoraAudioProfileMusicStandard:
            return TRTCAudioQualityDefault;
        case AgoraAudioProfileMusicHighQuality:
            return TRTCAudioQualityMusic;
        case AgoraAudioProfileMusicHighQualityStereo:
            return TRTCAudioQualityMusic;
        default:
            return TRTCAudioQualityDefault;
    }
}

- (AgoraAudioRemoteReason)transToAgoraAudioRemoteReason:(TRTCAVStatusChangeReason)reason {
    switch (reason) {
        case TRTCAVStatusChangeReasonBufferingBegin:
            return AgoraAudioRemoteReasonNetworkCongestion;
        case TRTCAVStatusChangeReasonBufferingEnd:
            return AgoraAudioRemoteReasonNetworkRecovery;
        case TRTCAVStatusChangeReasonLocalStarted:
            return AgoraAudioRemoteReasonLocalUnmuted;
        case TRTCAVStatusChangeReasonLocalStopped:
            return AgoraAudioRemoteReasonLocalMuted;
        case TRTCAVStatusChangeReasonRemoteStarted:
            return AgoraAudioRemoteReasonRemoteUnmuted;
        case TRTCAVStatusChangeReasonRemoteStopped:
            return AgoraAudioRemoteReasonRemoteMuted;
        default:
            return AgoraAudioRemoteReasonInternal;
    }
}

- (AgoraVideoRemoteReason)transToAgoraVideoRemoteReason:(TRTCAVStatusChangeReason)reason {
    switch (reason) {
        case TRTCAVStatusChangeReasonBufferingBegin:
            return AgoraVideoRemoteReasonCongestion;
        case TRTCAVStatusChangeReasonBufferingEnd:
            return AgoraVideoRemoteReasonRecovery;
        case TRTCAVStatusChangeReasonLocalStarted:
            return AgoraVideoRemoteReasonLocalUnmuted;
        case TRTCAVStatusChangeReasonLocalStopped:
            return AgoraVideoRemoteReasonLocalMuted;
        case TRTCAVStatusChangeReasonRemoteStarted:
            return AgoraVideoRemoteReasonRemoteUnmuted;
        case TRTCAVStatusChangeReasonRemoteStopped:
            return AgoraVideoRemoteReasonRemoteMuted;
        default:
            return AgoraVideoRemoteReasonInternal;
    }
}

- (TRTCVideoFillMode)transAgoraVideoRenderMode:(AgoraVideoRenderMode)mode{
    switch(mode) {
        case AgoraVideoRenderModeFit:
            return TRTCVideoFillMode_Fit;
            break;
        case AgoraVideoRenderModeHidden: 
        default:
            return TRTCVideoFillMode_Fill;
            break;
    }
}

- (TRTCVideoMirrorType)transAgoraMirrorType:(AgoraVideoMirrorMode)mode {
    switch (mode) {
        case AgoraVideoMirrorModeAuto:
            return TRTCVideoMirrorTypeAuto;
        case AgoraVideoMirrorModeEnabled:
            return TRTCVideoMirrorTypeEnable;
        case AgoraVideoMirrorModeDisabled:
            return TRTCVideoMirrorTypeDisable;
    }
}

- (AgoraVideoSourceType)transToAgoraVideoSourceType:(TRTCVideoStreamType)type {
    switch (type) {
        case TRTCVideoStreamTypeBig:
        case TRTCVideoStreamTypeSmall:
            return AgoraVideoSourceTypeCamera;
        default:
            return AgoraVideoSourceTypeScreen;
    }
}

- (AgoraErrorCode)transErrorCode:(TXLiteAVError)trtcCode
{
    static int errorMap[] = {
        ERR_NULL, AgoraErrorCodeNoError,
        ERR_ROOM_ENTER_FAIL, AgoraErrorCodeJoinChannelRejected,
        ERR_SDK_APPID_INVALID, AgoraErrorCodeInvalidAppId,
        ERR_ROOM_ID_INVALID, AgoraErrorCodeInvalidChannelId,
        ERR_MIC_START_FAIL, AgoraErrorCodeConnectionInterrupted,
        ERR_SPEAKER_STOP_FAIL, AgoraErrorCodeConnectionInterrupted,
        ERR_CAMERA_START_FAIL, AgoraErrorCodeStartCamera,
        ERR_PLAY_LIVE_STREAM_NET_DISCONNECT, AgoraErrorCodeConnectionInterrupted,
        ERR_MIC_STOP_FAIL, AgoraErrorCodeAdmStopPlayout,
        ERR_SPEAKER_STOP_FAIL, AgoraErrorCodeAdmStopPlayout,
        ERR_CAMERA_NOT_AUTHORIZED, AgoraErrorCodeVdmCameraNotAuthorized,
        0xffff, 0xffff
    };

    AgoraErrorCode agoraErrCode = AgoraErrorCodeFailed;
    for (int i = 0; errorMap[i] != 0xffff; i+=2) {
        if (errorMap[i] == trtcCode) {
            agoraErrCode = (AgoraErrorCode)errorMap[i+1];
            break;
        }
    }

    return agoraErrCode;
}

- (void)setVideoEncodeParamInner:(NSDictionary *)param {
    NSDictionary *paramDict = @{
                                @"api" : @"setVideoEncodeParamEx",
                                @"params" : param
                                };
    NSError *error = nil;
    NSData *paramData = [NSJSONSerialization dataWithJSONObject:paramDict options:0 error:&error];
    NSAssert(error == nil, @"set video encode param fail, %@", error);
    NSString *strParam = [[NSString alloc] initWithData:paramData encoding:NSUTF8StringEncoding];
    [_trtcCloud callExperimentalAPI:strParam];
}

- (NSDictionary *)generateVideoEncoderParam:(AgoraVideoEncoderConfiguration *)config {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"videoWidth"] = @(config.dimensions.width);
    dict[@"videoHeight"] = @(config.dimensions.height);
    dict[@"videoFps"] = @(config.frameRate);
    dict[@"videoBitrate"] = @(config.bitrate);
    dict[@"minVideoBitrate"] = @(config.minBitrate);
    if (config.orientationMode == AgoraVideoOutputOrientationModeFixedLandscape) {
        dict[@"resolutionMode"] = @(TRTCVideoResolutionModeLandscape);
    } else if (config.orientationMode == AgoraVideoOutputOrientationModeFixedPortrait) {
        dict[@"resolutionMode"] = @(TRTCVideoResolutionModePortrait);
    }
    dict[@"streamType"] = @0;
    return [dict copy];
}

- (void)setFramework {
    NSDictionary *jsonDic = @{ @"api": @"setFramework",
                               @"params": @{ @"framework": @(1),
                                             @"component": @(20),
                               }};
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDic options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [[TRTCCloud sharedInstance] callExperimentalAPI: jsonString];
}

@end
