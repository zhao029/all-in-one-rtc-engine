//
//  AIORTCEngine.h
//  APIExample-OC
//
//  Created by CY zhao on 2024/2/29.
//  Copyright © 2024 Tencent. All rights reserved.
//

#ifndef RTCEngine_h
#define RTCEngine_h

@import AgoraRtcKit;

@protocol AIORTCEngine <NSObject>

@property(nonatomic, weak) id<AgoraRtcEngineDelegate> _Nullable delegate;

#pragma mark - Core Method
- (int)joinChannelByToken:(NSString * _Nullable)token
                channelId:(NSString * _Nonnull)channelId
                     info:(NSString * _Nullable)info
                      uid:(NSUInteger)uid
              joinSuccess:(void(^ _Nullable)(NSString * _Nonnull channel, NSUInteger uid, NSInteger elapsed))joinSuccessBlock NS_SWIFT_NAME(joinChannel(byToken:channelId:info:uid:joinSuccess:));

/**
 * 设置媒体选项并进入房间（频道）
 * 相比上一个joinChannelByToken方法，该方法该方法增加了 options 参数，用于配置用户加入频道时是否自动订阅频道内所有远端音视频流。
 * @note mediaOptions目前仅生效publishCameraTrack、publishMicrophoneTrack、clientRoleType、autoSubscribeAudio、autoSubscribeVideo、channelProfile，其他设置不生效。
 * @param token 用户签名（必填），当前 userId 对应的验证签名，相当于使用云服务的登录密码，用户可以通过官网的方式自己生成，也可以填空字符串，sdk内部自己生成
 * @param channelId 频道名，限制长度为 64 字节。以下为支持的字符集范围（共 89 个字符）:
                    - 大小写英文字母（a-zA-Z）；
                    - 数字（0-9）；
                    - 空格、 ! 、 # 、 $ 、 % 、 & 、 ( 、 ) 、 + 、 - 、 : 、 ; 、 < 、 = 、 . 、 > 、 ? 、 @ 、 [ 、 ] 、 ^ 、 _ 、 { 、 } 、 | 、 ~ 、 , 。
 *  @param uid 用户标识（必填
 *  @param mediaOptions 频道媒体设置选项。详见 AgoraRtcChannelMediaOptions。
 *  @param joinSuccessBlock 成功加入频道回调。joinSuccessBlock 优先级高于 didJoinChannel，两个同时存在时，didJoinChannel 会被忽略。需要有 didJoinChannel 回调时，请将 joinSuccessBlock 设置为 nil。
 */
- (int)joinChannelByToken:(NSString * _Nullable)token
               channelId:(NSString * _Nonnull)channelId
                     uid:(NSUInteger)uid
            mediaOptions:(AgoraRtcChannelMediaOptions * _Nonnull)mediaOptions
             joinSuccess:(void(^ _Nullable)(NSString * _Nonnull channel, NSUInteger uid, NSInteger elapsed))joinSuccessBlock NS_SWIFT_NAME(joinChannel(byToken:channelId:uid:mediaOptions:joinSuccess:));

- (int)leaveChannel:(void(^ _Nullable)(AgoraChannelStats * _Nonnull stat))leaveChannelBlock NS_SWIFT_NAME(leaveChannel(_:));

/**
* 设置频道场景
* SDK 会针对不同的使用场景采用不同的优化策略，以获取最佳的音视频传输体验。
* @note  该方法必须在 joinChannelByToken 前调用和进行设置，进入频道后无法再设置。
* @param profile 频道使用场景。详见 AgoraChannelProfile，仅支持AgoraChannelProfileCommunication和AgoraChannelProfileLiveBroadcasting
*/
- (int)setChannelProfile:(AgoraChannelProfile)profile NS_SWIFT_NAME(setChannelProfile(_:));

/**
* 加入频道后更新频道媒体选项。
* @note mediaOptions参数目前仅支持配置publishCameraTrack、publishMicrophoneTrack、clientRoleType，其他设置不生效。
* @param mediaOptions 频道频道媒体选项场景, 详见 AgoraRtcChannelMediaOptions。
*/
- (int)updateChannelWithMediaOptions:(AgoraRtcChannelMediaOptions* _Nonnull)mediaOptions NS_SWIFT_NAME(updateChannel(with:));

- (int)setClientRole:(AgoraClientRole)role NS_SWIFT_NAME(setClientRole(_:));

- (int)setClientRole:(AgoraClientRole)role options:(AgoraClientRoleOptions * _Nullable)options NS_SWIFT_NAME(setClientRole(_:options:));

/**
 * 获取当前网络连接状态。
 *
 * @return 当前网络连接状态.,详见 AgoraConnectionState。
 */
- (AgoraConnectionState)getConnectionState NS_SWIFT_NAME(getConnectionState());

#pragma mark Core Audio

- (int)muteAllRemoteAudioStreams:(BOOL)mute NS_SWIFT_NAME(muteAllRemoteAudioStreams(_:));

- (int)muteLocalAudioStream:(BOOL)mute NS_SWIFT_NAME(muteLocalAudioStream(_:));

- (int)muteRemoteAudioStream:(NSUInteger)uid mute:(BOOL)mute NS_SWIFT_NAME(muteRemoteAudioStream(_:mute:));

/**
 调节本地播放的指定远端用户信号音量
 @param uid 要调节的用户ID
 @param volume 音量范围为 0~100。
 */
- (int)adjustUserPlaybackSignalVolume:(NSUInteger)uid volume:(int)volume NS_SWIFT_NAME(adjustUserPlaybackSignalVolume(_:volume:));

/** 调节本地播放的所有远端用户信号音量。

 @param volume 音量，取值范围为 [0,400]。
 * 0: Mute
 * 400: 默认
 */
- (int)adjustPlaybackSignalVolume:(NSInteger)volume NS_SWIFT_NAME(adjustPlaybackSignalVolume(_:));

/**
 * 关闭音频模块。
 */
- (int)disableAudio NS_SWIFT_NAME(disableAudio());

/**
 * 启用音频模块
 */
- (int)enableAudio NS_SWIFT_NAME(enableAudio());

/**
 * 启用用户音量大小提示。
 *
 * @note 开启此功能后，engine会按设置的时间间隔触发 reportAudioVolumeIndicationOfSpeakers 回调报告音量信息。
 *
 * @param interval 回调的触发间隔，单位为毫秒
 * - <= 0: 关闭回调。
 * - > 0: 返回音量提示的间隔，单位为毫秒，最小间隔为 100ms，推荐值：300ms
 * @param smooth 平滑系数，该参数目前不生效
 * @param reportVad 是否开启本地人声检测功能，在 enableLocalAudio之前调用才可以生效
 *
 * @return
 * - 0: Success.
 * - < 0: Failure.
 */
- (int)enableAudioVolumeIndication:(NSInteger)interval
                            smooth:(NSInteger)smooth
                         reportVad:(BOOL)reportVad NS_SWIFT_NAME(enableAudioVolumeIndication(_:smooth:reportVad:));

/**
 * 设置音频编码属性。
 *
 * @note 进房前和开启本地音频采集前调用可生效
 *
 * @param profile 音频编码属性，包含采样率、码率、编码模式和声道数
 */
- (int)setAudioProfile:(AgoraAudioProfile)profile NS_SWIFT_NAME(setAudioProfile(_:));

/** 调节音频采集信号音量。

 @param volume 音量，取值范围为 [0,400]。

 * 0: 静音
 * 400: （默认）原始音量。
 */
- (int)adjustRecordingSignalVolume:(NSInteger)volume NS_SWIFT_NAME(adjustRecordingSignalVolume(_:));

/**
 * 开启耳返功能。
 *
 * @param enabled 开启/关闭耳返功能
 * - `YES`：开启
 * - `NO`：关闭
 */
- (int)enableInEarMonitoring:(BOOL)enabled NS_SWIFT_NAME(enable(inEarMonitoring:));

/**
 * 开启本地音频的采集和发布
 * @Note SDK 默认不开启麦克风，当用户需要发布本地音频时，需要调用该接口开启麦克风采集，并将音频编码并发布到当前的房间中。
 开启本地音频的采集和发布后，房间中的其他用户会收到 onUserAudioAvailable(userId, YES) 的通知。
 */
- (int)enableLocalAudio:(BOOL)enabled NS_SWIFT_NAME(enableLocalAudio(_:));

/**
 * 设置耳返音量
 *
 * @param volume 音量大小，取值范围为 0 - 400，默认值：400。
 *
 */
- (int)setInEarMonitoringVolume:(NSInteger)volume NS_SWIFT_NAME(setInEarMonitoringVolume(_:));

#pragma mark Audio Routing Controller

#if TARGET_OS_IPHONE
- (int)setEnableSpeakerphone:(BOOL)enableSpeaker NS_SWIFT_NAME(setEnableSpeakerphone(_:));

- (BOOL)isSpeakerphoneEnabled NS_SWIFT_NAME(isSpeakerphoneEnabled());

- (int)setDefaultAudioRouteToSpeakerphone:(BOOL)defaultToSpeaker NS_SWIFT_NAME(setDefaultAudioRouteToSpeakerphone(_:));
#endif


#pragma mark Core Video
/**
 启用视频模块
 
 */
- (int)enableVideo NS_SWIFT_NAME(enableVideo());

- (int)disableVideo NS_SWIFT_NAME(disableVideo());

- (int)muteAllRemoteVideoStreams:(BOOL)mute NS_SWIFT_NAME(muteAllRemoteVideoStreams(_:));

- (int)muteLocalVideoStream:(BOOL)mute NS_SWIFT_NAME(muteLocalVideoStream(_:));

- (int)muteRemoteVideoStream:(NSUInteger)uid
                        mute:(BOOL)mute NS_SWIFT_NAME(muteRemoteVideoStream(_:mute:));


/**
 * 设置视频编码属性。
 *
 *@note 仅支持dimensions、frameRate、bitrate、minbitrate、orientationMode几项配置。
 * bitrate推荐取值：请参见TRTCVideoResolution 在各档位注释的最佳码率，也可以在此基础上适当调高。比如：TRTCVideoResolution_1280_720 对应 1200kbps 的目标码率，您也可以设置为 1500kbps 用来获得更好的观感清晰度。
 * minVideoBitrate推荐取值：您可以通过同时设置 videoBitrate 和 minVideoBitrate 两个参数，用于约束 SDK 对视频码率的调整范围：
 * 如果您追求 弱网络下允许卡顿但要保持清晰 的效果，可以设置 minVideoBitrate 为 videoBitrate 的 60%。
 * 如果您追求 弱网络下允许模糊但要保持流畅 的效果，可以设置 minVideoBitrate 为一个较低的数值（比如 100kbps）。
 * 如果您将 videoBitrate 和 minVideoBitrate 设置为同一个值，等价于关闭 SDK 对视频码率的自适应调节能力。
 *
 * @param config 用于设置视频编码器的相关参数
 *
 * @return
 * - 0: Success.
 * - < 0: Failure.
 */
- (int)setVideoEncoderConfiguration:(AgoraVideoEncoderConfiguration * _Nonnull)config NS_SWIFT_NAME(setVideoEncoderConfiguration(_:));

/**
 * 开启本地摄像头的预览画面
 *
 * @note 在 joinChannel 之前调用此函数，SDK 只会开启摄像头，并一直等到您调用 joinChannel 之后才开始推流。
 * 在 joinChannel 之后调用此函数，SDK 会开启摄像头并自动开始视频推流。
 * 调用该方法前，必须先调用 setupLocalVideo 初始化本地视图。
 *
 */
- (int)startPreview NS_SWIFT_NAME(startPreview());

/**
 * 停止摄像头预览.
 */
- (int)stopPreview NS_SWIFT_NAME(stopPreview());

/**
 * 设置本地画面的渲染参数
 *
 * After initialzing the local video view, you can call this method to update
 * its rendering mode. It affects only the video view that the local user sees, not the published local video stream.
 *
 * @note
 * 可设置的参数包括有：填充模式以及左右镜像。
 *
 * @param mode 填充模式，【推荐取值】填充（画面可能会被拉伸裁剪）或适应（画面可能会有黑边
 * @param mirror 画面镜像模式
 */
- (int)setLocalRenderMode:(AgoraVideoRenderMode)mode
                   mirror:(AgoraVideoMirrorMode)mirror NS_SWIFT_NAME(setLocalRenderMode(_:mirror:));

/** 设置远端画面的渲染模式
 
 * @note 可设置的参数包括有：填充模式以及左右镜像。
 * @param uid  指定远端用户的 ID。
 * @param mode 画面填充模式。
 * @param mirror 画面镜像模式。
*/
- (int)setRemoteRenderMode:(NSUInteger)uid
                      mode:(AgoraVideoRenderMode)mode
                    mirror:(AgoraVideoMirrorMode)mirror NS_SWIFT_NAME(setRemoteRenderMode(_:mode:mirror:));

/**
 * 初始化本地视图。
 *
 * 仅支持绑定本地摄像头的预览画面窗口、画面填充模式、镜像模式
 *
 * @param local 本地视频显示属性.，仅支持绑定本地摄像头的预览画面窗口、画面填充模式、镜像模式。
 *
 */
- (int)setupLocalVideo:(AgoraRtcVideoCanvas * _Nullable)local NS_SWIFT_NAME(setupLocalVideo(_:));

/** 初始化远端用户视图。

 订阅远端用户的视频流，并绑定视频渲染控件，如果您已经知道房间中有视频流的用户的 userid，可以直接调用 startRemoteView 订阅该用户的画面； 如果您不知道房间中有哪些用户在发布视频，您可以在 joinChannel之后等待来自 didJoinedOfUid 的通知。

 @param remote 远端视频显示属性，仅支持绑定远端摄像头的预览画面窗口、画面填充模式、镜像模式。

 */
- (int)setupRemoteVideo:(AgoraRtcVideoCanvas * _Nonnull)remote NS_SWIFT_NAME(setupRemoteVideo(_:));

#pragma mark Camera Control

#if TARGET_OS_IPHONE
/**
 * 切换前置/后置摄像头。
 * @note  这个方法仅在iOS系统下生效，macOS不生效。
 */
- (int)switchCamera NS_SWIFT_NAME(switchCamera());
#endif


#pragma mark - ThirdBeauty method
/**
 * 注册原始视频观测器对象。
 * @note 可以获取原始视频数据，用于接入第三方美颜。
 */
- (BOOL)setVideoFrameDelegate:(id _Nullable)delegate;

#pragma mark - TRTC only method
/**
 显示TRTC仪表盘
 “仪表盘”是位于视频渲染控件之上的一个半透明的调试信息浮层，用于展示音视频信息和事件信息，便于对接和调试
 @note 该方法仅TRTC支持，对agora RTC调用没有效果
 
 @param showType 显示类型 ，0：不显示；1：显示精简版（仅显示音视频信息）；2：显示完整版（包含音视频信息和事件信息）。
 */
- (void)showDebugView:(NSInteger)showType;

/**
 设置TRTC仪表盘的边距
 用于调整仪表盘在视频渲染控件中的位置，必须在 showDebugView 之前调用才能生效。
 @note 该方法仅TRTC支持，对agora RTC调用没有效果
 
 @param userId 用户 ID。
 @param margin 仪表盘内边距，注意这里是基于 parentView 的百分比，margin 的取值范围是0 - 1。
 */
- (void)setDebugViewMargin:(NSString *_Nullable)userId margin:(UIEdgeInsets)margin;
@end

#endif /* RTCEngine_h */
