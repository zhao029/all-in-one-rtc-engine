/*
 * Module:   TRTCMainViewController
 *
 * Function: 使用TRTC SDK完成 1v1 和 1vn 的视频通话功能
 *
 *    1. 支持九宫格平铺和前后叠加两种不同的视频画面布局方式，该部分由 TRTCVideoViewLayout 来计算每个视频画面的位置排布和大小尺寸
 *
 *    2. 支持对视频通话的分辨率、帧率和流畅模式进行调整，该部分由 TRTCSettingViewController 来实现
 *
 *    3. 创建或者加入某一个通话房间，需要先指定 roomid 和 userid，这部分由 TRTCNewViewController 来实现
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "TRTCMainViewController.h"
#import "UIView+Additions.h"
#import "ColorMacro.h"
#import "AIORTCEngine.h"
#import "AIORTCEngineManager.h"
#import "TRTCVideoViewLayout.h"
#import "TRTCVideoView.h"
#import "BeautySettingPanel.h"
#import "TRTCFloatWindow.h"
#import "NSString+Common.h"
#import "LiteAVApollo-Swift.h"
#import "Masonry.h"
#import "SDKConfig.h"
#import "GenerateTestUserSig.h"

typedef enum : NSUInteger {
    TRTC_IDLE,       // SDK 没有进入视频通话状态
    TRTC_ENTERED,    // SDK 视频通话进行中
} TRTCStatus;

@interface TRTCMainViewController() <UITextFieldDelegate, AgoraRtcEngineDelegate, TRTCVideoViewDelegate> {
    TRTCStatus                _roomStatus;
    
    NSString                 *_mainViewUserId;     //视频画面支持点击切换，需要用一个变量记录当前哪一路画面是全屏状态的
    
    TRTCVideoViewLayout      *_layoutEngine;
    UIView                   *_holderView;
    
    NSMutableDictionary*      _remoteViewDic;      //一个或者多个远程画面的view
    NSMutableDictionary<NSString *, VideoSession*>* _videoSessions;
    UIButton                 *_btnCamSwitch;       //切换摄像头
    UIButton                 *_btnLog;             //用于显示通话质量的log按钮
    UIButton                 *_btnElapse;          //用于显示进房时间的按钮
    UIButton                 *_btnVideoMute;       //上行静画
    UIButton                 *_btnLayoutSwitch;    //布局切换按钮（九宫格 OR 前后叠加）
    UIButton                 *_btnBeauty;          //是否开启美颜（磨皮）
    UIButton                 *_bgmButton;          //BGM设置，点击打开TRTCBgmContainerViewController
    UIButton                 *_btnMute;            //上行静音
    UIButton                 *_btnCDN;             //CDN播放
    UIButton                 *_btnLinkMic;         //连麦，观众模式进房时显示

    NSInteger                _showLogType;         //LOG浮层显示详细信息还是精简信息
    NSInteger                _layoutBtnState;      //布局切换按钮状态

    BOOL                     _cameraMuted;
    BOOL                     _muteSwitch;
    CGFloat                  _dashboardTopMargin;
    BOOL                    _showLog;
    BeautySettingPanel*     _vBeauty;
    long _enterRoomElapsed;
}
@property (nonatomic, assign) id playingID;

@property uint32_t sdkAppid;
@property (nonatomic, copy) NSString* roomID;
@property (nonatomic, copy) NSString* selfUserID;
@property NSString  *selfUserSig;
@property (nonatomic, assign) NSInteger toastMsgCount;      //当前tips数量
@property (nonatomic, assign) NSInteger toastMsgHeight;
@property (nonatomic, strong) id<AIORTCEngine> agoraEngine;               //Agora SDK 实例对象
@property (nonatomic, strong) TRTCVideoView* localView;          //本地画面的view

@end

@implementation TRTCMainViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

/**
 * 检查当前APP是否已经获得摄像头和麦克风权限，没有获取边提示用户开启权限
 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _dashboardTopMargin = [UIApplication sharedApplication].statusBarFrame.size.height + self.navigationController.navigationBar.frame.size.height;
}

- (void)setAppScene:(AgoraChannelProfile)appScene {
    _appScene = appScene;
}

- (void)setParam:(TRTCLoginParam *)param {
    _param = param;
    _sdkAppid = param.sdkAppId.intValue;
    _selfUserID = param.userId;
    _selfUserSig = param.userSig;
    _roomID = param.roomId;
}

- (void)setLocalView:(UIView *)localView remoteViewDic:(NSMutableDictionary *)remoteViewDic {
    _agoraEngine.delegate = self;
    _localView = (TRTCVideoView*)localView;
    _localView.delegate = self;
    _remoteViewDic = remoteViewDic;

    if (_param.role != AgoraClientRoleAudience)
        _mainViewUserId = @"";
    
    for (id userID in _remoteViewDic) {
        TRTCVideoView *playerView = [_remoteViewDic objectForKey:userID];
        playerView.delegate = self;
    }
    [self clickGird:nil];
    [self relayout];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _videoSessions = [[NSMutableDictionary alloc] init];
    _dashboardTopMargin = 0.15;
    
    
    if (_agoraEngine == nil) {
        _agoraEngine = [AIORTCEngineManager sharedEngineWithAppId:self.useTRTC ? @([SDKConfig TXSDKAppID]).stringValue : [SDKConfig AgoraAppID] delegate:self useTRTC:self.useTRTC];
    }
    _roomStatus = TRTC_IDLE;
    _remoteViewDic = [[NSMutableDictionary alloc] init];

    _mainViewUserId = @"";
    _toastMsgCount = 0;
    _toastMsgHeight = 0;
    
    // 初始化 UI 控件
    [self initUI];
    [_btnVideoMute setImage:[UIImage imageNamed:(((_param.role == AgoraClientRoleAudience) || _cameraMuted) ?
                             @"unmuteVideo" : @"muteVideo")] forState:UIControlStateNormal];
    
    [_agoraEngine enableAudio];
    if (self.videoEnabled) {
        [_agoraEngine enableVideo];
    }
    [_agoraEngine setChannelProfile:_appScene];
    [_agoraEngine setClientRole:_param.role];
    [_agoraEngine setAudioProfile:_audioProfile];
    [_agoraEngine setVideoEncoderConfiguration:_videoProfile];
    [_agoraEngine enableAudioVolumeIndication:300 smooth:3 reportVad:NO];
    
    if (!_cameraMuted){
        [self startPreview];
    } else  {
        [_localView showVideoCloseTip:YES];
    }

    // 开始登录、进房
    [self enterRoom];
}

- (void)dealloc {
    if (_agoraEngine != nil) {
        [_agoraEngine leaveChannel:nil];
    }
    [[TRTCFloatWindow sharedInstance] close];
    [AIORTCEngineManager destroy];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - initUI
- (void)_setupBottomToolBarButtons:(NSArray<UIButton*> *)buttons {
    NSUInteger count = buttons.count;
    const CGFloat spacing = 10;
    CGFloat bottomSpace = 10;
    CGFloat buttonSize = roundf((CGRectGetWidth(self.view.bounds) - spacing * (count+1)) / count);
    if (@available(iOS 11, *)) {
        bottomSpace += [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom;
    }
    CGRect frame = CGRectMake(spacing, CGRectGetHeight(self.view.bounds) - bottomSpace - buttonSize, buttonSize, buttonSize);
    for (UIButton *button in buttons) {
        button.frame = frame;
        frame.origin.x += (buttonSize + spacing);
    }
}
/**
 * 初始化界面控件，包括主要的视频显示View，以及底部的一排功能按钮
 */
- (void)initUI {
    self.title = [NSString stringWithFormat:@"%@(%@)", _roomID, self.useTRTC ? @"TRTC" : @"Agora"];
    [self.view setBackgroundColor:UIColorFromRGB(0x333333)];
    
    
    _btnLayoutSwitch = [self createBottomBtnIcon:@"float_b"
                                          action:@selector(clickGird:)];
    
    if (_param.role == AgoraClientRoleAudience)  {
        _btnMute = [self createBottomBtnIcon:@"rtc_bottom_mic_off" action:@selector(clickMute:)];
    } else {
        _btnMute = [self createBottomBtnIcon:@"rtc_bottom_mic_on" action:@selector(clickMute:)];
    }

    _btnVideoMute = [self createBottomBtnIcon:@"muteVideo"
                                       action:@selector(clickVideoMute:)];
    
    _muteSwitch = NO;
    _cameraMuted = NO;
    
    _btnCamSwitch = [self createBottomBtnIcon:@"camera" action:@selector(clickSwitchCam:)];
    
    _showLogType = 0;
    _btnLog = [self createBottomBtnIcon:@"log_b2"
                                 action:@selector(clickLog:)];
    _btnElapse = [self createBottomBtnIcon:@"log_b2"
                                 action:@selector(clickElapse:)];

    [self _setupBottomToolBarButtons:@[_btnCamSwitch, _btnLayoutSwitch, _btnVideoMute, _btnMute, _btnLog]];
    
    // 本地预览view
    _localView = [TRTCVideoView newVideoViewWithType:VideoViewType_Local userId:_selfUserID];

    _localView.delegate = self;
    [_localView setBackgroundColor:UIColorFromRGB(0x262626)];
    
    _holderView = [[UIView alloc] initWithFrame:self.view.bounds];
    [_holderView setBackgroundColor:UIColorFromRGB(0x262626)];
    [self.view insertSubview:_holderView atIndex:0];
    
    _layoutEngine = [[TRTCVideoViewLayout alloc] init];
    _layoutEngine.view = _holderView;
    [self relayout];
}


- (void)back2FloatingWindow {
    [_agoraEngine showDebugView:0];
    [TRTCFloatWindow sharedInstance].engine = _agoraEngine;
    [TRTCFloatWindow sharedInstance].localView = _localView;
    [TRTCFloatWindow sharedInstance].remoteViewDic = _remoteViewDic;
    for (NSString* uid in _remoteViewDic) {
        TRTCVideoView* view = _remoteViewDic[uid];
        [view removeFromSuperview];
    }
    [TRTCFloatWindow sharedInstance].backController = self;
    // pop
    [self.navigationController popViewControllerAnimated:YES];
    [[TRTCFloatWindow sharedInstance] show];
}

- (UIButton*)createBottomBtnIcon:(NSString*)icon action:(SEL)action {
    UIButton * btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setImage:[UIImage imageNamed:icon] forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    return btn;
}


/**
 * 视频窗口排布函数，此处代码用于调整界面上数个视频画面的大小和位置
 */
#define IsIPhoneX ([[UIScreen mainScreen] bounds].size.height >= 812)
- (void)relayout {
    NSMutableArray *views = @[].mutableCopy;
    if ([_mainViewUserId isEqual:@""] || [_mainViewUserId isEqual:_selfUserID]) {
        [views addObject:_localView];
        _localView.enableMove = NO;
    } else if([_remoteViewDic objectForKey:_mainViewUserId] != nil) {
        [views addObject:_remoteViewDic[_mainViewUserId]];
    }
    for (id userID in _remoteViewDic) {
        TRTCVideoView *playerView = [_remoteViewDic objectForKey:userID];
        if ([_mainViewUserId isEqual:userID]) {
            [views addObject:_localView];
            playerView.enableMove = NO;
            _localView.enableMove = YES;
        } else {
            playerView.enableMove = YES;
            [views addObject:playerView];
        }
    }
    
    [_layoutEngine relayout:views];
    
    // TODO: Debug Views
    
    //观众角色隐藏预览view
     _localView.hidden = NO;
     if (_appScene == AgoraChannelProfileLiveBroadcasting && _param.role == AgoraClientRoleAudience)
         _localView.hidden = YES;
    
    // 更新 dashboard 边距
    UIEdgeInsets margin = UIEdgeInsetsMake(_dashboardTopMargin,  0, 0, 0);
    if (_remoteViewDic.count == 0) {
        [_agoraEngine setDebugViewMargin:_selfUserID margin:margin];
    } else {
        NSMutableArray *uids = [NSMutableArray arrayWithObject:_selfUserID];
        [uids addObjectsFromArray:[_remoteViewDic allKeys]];
        [uids removeObject:_mainViewUserId];
        for (NSString *uid in uids) {
            [_agoraEngine setDebugViewMargin:uid margin:UIEdgeInsetsZero];
        }
        
        [_agoraEngine setDebugViewMargin:_mainViewUserId margin:(_layoutEngine.type == TC_Float || _remoteViewDic.count == 0) ? margin : UIEdgeInsetsZero];
    }
}

/**
 * 防止iOS锁屏：如果视频通话进行中，则方式iPhone进入锁屏状态
 */
- (void)setRoomStatus:(TRTCStatus)roomStatus {
    _roomStatus = roomStatus;
    
    switch (_roomStatus) {
        case TRTC_IDLE:
            [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
            break;
        case TRTC_ENTERED:
            [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
            break;
        default:
            break;
    }
}


/**
 * 加入视频房间：需要 TRTCNewViewController 提供的  TRTCVideoEncParam 函数
 */
- (void)enterRoom {
    [self toastTip:@"开始进房"];
    
    NSString *trtcSig = [GenerateTestUserSig genTestUserSig:_param.userId];
    // 进房
    [_agoraEngine joinChannelByToken:self.useTRTC ? trtcSig : nil
                           channelId:_param.roomId
                                info:nil
                                 uid:_param.userId.integerValue
                         joinSuccess: nil];
}


/**
 * 退出房间，并且退出该页面
 */
- (void)exitRoom {
    [_agoraEngine leaveChannel:nil];
    [self setRoomStatus:TRTC_IDLE];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)startPreview {
    //视频通话默认开摄像头。直播模式主播才开摄像头
    if (_appScene == AgoraChannelProfileCommunication || _param.role == AgoraClientRoleBroadcaster) {
        AgoraRtcVideoCanvas *canvas = [[AgoraRtcVideoCanvas alloc] init];
        canvas.uid = _param.userId.integerValue;
        canvas.view = _localView;
        canvas.renderMode = AgoraVideoRenderModeHidden;
        [_agoraEngine setupLocalVideo:canvas];
        [_agoraEngine startPreview];
    }

    [_localView showVideoCloseTip:NO];
}

- (void)stopPreview {
    [_agoraEngine stopPreview];
}

#pragma mark - button

/**
 * 点击打开仪表盘浮层，仪表盘浮层是SDK中覆盖在视频画面上的一系列数值状态
 */
- (void)clickLog:(UIButton *)btn {
    _showLogType ++;
    if (_showLogType > 2) {
        //关闭进房耗时
        _showLogType = 0;
        const NSInteger Tag = 10123;
        UILabel *label = [self.view viewWithTag:Tag];
        if (label) {
            [label removeFromSuperview];
        }
        //更新按钮图标
        [btn setImage:[UIImage imageNamed:@"log_b2"] forState:UIControlStateNormal];
    }
    if(_showLogType == 1 ){
        //打开仪表盘
        if(!self.useTRTC){
            [_remoteViewDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, TRTCVideoView * view, BOOL * _Nonnull stop) {
                [view setLogHidden:NO];
            }];
            [_localView setLogHidden:NO];
        } else {
            [_agoraEngine showDebugView:2];
        }
        //更新按钮图标
        [btn setImage:[UIImage imageNamed:@"log_b"] forState:UIControlStateNormal];
    }
    if(_showLogType == 2){
        //关闭仪表盘
        if(!self.useTRTC){
            [_remoteViewDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, TRTCVideoView * view, BOOL * _Nonnull stop) {
                [view setLogHidden:YES];
            }];
            [_localView setLogHidden:YES];
        } else {
            [_agoraEngine showDebugView:0];
        }
        //显示进房耗时
        const NSInteger Tag = 10123;
        UILabel *label = [self.view viewWithTag:Tag];
        label = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 0, 0)];
        label.tag = Tag;
        label.text = [NSString stringWithFormat:@"进房耗时: %ld 毫秒", _enterRoomElapsed];
        [label sizeToFit];
        label.backgroundColor = [UIColor colorWithWhite:1 alpha:0.0];
        label.textColor = UIColorFromRGB(0xFFFF4081);
        [self.view addSubview:label];
        label.center = CGPointMake(100, 100);
    }
}

/**
 * 点击打开进房时间
 */
- (void)clickElapse:(UIButton *)btn {
    const NSInteger Tag = 10123;
    UILabel *label = [self.view viewWithTag:Tag];
    if (label) {
        [label removeFromSuperview];
        [btn setImage:[UIImage imageNamed:@"log_b2"] forState:UIControlStateNormal];
    } else {
        label = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 0, 0)];
        label.tag = Tag;
        label.text = [NSString stringWithFormat:@"进房耗时: %ld 毫秒", _enterRoomElapsed];
        [label sizeToFit];
        label.backgroundColor = [UIColor colorWithWhite:1 alpha:0.0];
        label.textColor = UIColorFromRGB(0xFFFF4081);
        [self.view addSubview:label];
        label.center = CGPointMake(100, 100);
        [btn setImage:[UIImage imageNamed:@"log_b"] forState:UIControlStateNormal];
    }
}

/**
 * 点击切换视频画面的九宫格布局模式和前后叠加模式
 */
- (void)clickGird:(UIButton *)btn {
    const int kStateFloat       = 0;
    const int kStateGrid        = 1;
    const int kStateFloatWindow = 2;
    if (_layoutBtnState == kStateFloat) {
        _layoutBtnState = kStateGrid;
        [_btnLayoutSwitch setImage:[UIImage imageNamed:@"gird_b"] forState:UIControlStateNormal];
        _layoutEngine.type = TC_Gird;
       [_agoraEngine setDebugViewMargin:_mainViewUserId margin:UIEdgeInsetsZero];
    } else if (_layoutBtnState == kStateGrid){
        _layoutBtnState = kStateFloatWindow;
        [self back2FloatingWindow];
        return;
    }
    else if (_layoutBtnState == kStateFloatWindow) {
        [_btnLayoutSwitch setImage:[UIImage imageNamed:@"float_b"] forState:UIControlStateNormal];
        _layoutBtnState = kStateFloat;
        _layoutEngine.type = TC_Float;
       [_agoraEngine setDebugViewMargin:_mainViewUserId margin:UIEdgeInsetsMake(_dashboardTopMargin, 0, 0, 0)];
    }
    if(_showLogType == 1){
        [_agoraEngine showDebugView:2];
    }else{
        [_agoraEngine showDebugView:0];
    }

}

/**
 * 打开或关闭本地视频上行
 */
- (void)clickVideoMute:(UIButton *)btn {
    _cameraMuted = !_cameraMuted;
    [btn setImage:[UIImage imageNamed:(_cameraMuted ? @"unmuteVideo" : @"muteVideo")] forState:UIControlStateNormal];
    if (_cameraMuted) {
        [_agoraEngine stopPreview];
        [_localView showVideoCloseTip:YES];
    } else {
        [self startPreview];
        [_localView showVideoCloseTip:NO];
    }
    [_agoraEngine muteLocalVideoStream:_cameraMuted];
}

- (void)setAudioMuted:(BOOL)muted {
    [_agoraEngine muteLocalAudioStream:muted];
    [_btnMute setImage:[UIImage imageNamed:(muted ? @"rtc_bottom_mic_off" : @"rtc_bottom_mic_on")] forState:UIControlStateNormal];
}

/**
 * 点击关闭或者打开本地的音频上行
 */
- (void)clickMute:(UIButton *)btn {
    if (_param.role == AgoraClientRoleAudience){
        _muteSwitch = YES;
    } else {
        _muteSwitch = !_muteSwitch;
    }
    [self setAudioMuted:_muteSwitch];
}

/**
* 点击切换摄像头按钮
*/
- (void)clickSwitchCam:(UIButton *)btn {
    #if TARGET_OS_IPHONE
    [_agoraEngine switchCamera];
    #endif
}

#pragma mark TRTCVideoViewDelegate
- (void)onMuteVideoBtnClick:(TRTCVideoView *)view stateChanged:(BOOL)stateChanged
{
    [_agoraEngine muteRemoteVideoStream:view.userId.integerValue mute:stateChanged];
}

- (void)onMuteAudioBtnClick:(TRTCVideoView *)view stateChanged:(BOOL)stateChanged
{
    [_agoraEngine muteRemoteAudioStream:view.userId.integerValue mute:stateChanged];
}

- (void)onScaleModeBtnClick:(TRTCVideoView *)view stateChanged:(BOOL)stateChanged
{
    AgoraRtcVideoCanvas *canvas = [[AgoraRtcVideoCanvas alloc] init];
    canvas.uid = view.userId.integerValue;
    canvas.view = view;
    canvas.renderMode = stateChanged ? AgoraVideoRenderModeHidden : AgoraVideoRenderModeFit;
    [_agoraEngine setupRemoteVideo:canvas];
}


#pragma mark - TRtcEngineDelegate

- (void)rtcEngine:(AgoraRtcEngineKit *)engine reportRtcStats:(AgoraChannelStats *)stats {
    VideoSession *session = [self localVideoSession];
    [session updateChannelStats:stats];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine remoteVideoStats:(AgoraRtcRemoteVideoStats * _Nonnull)stats {
    VideoSession *session = [self videoSession:@(stats.uid).stringValue];
    [session updateVideoStats:stats];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine remoteAudioStats:(AgoraRtcRemoteAudioStats *)stats {
    VideoSession *session = [self videoSession:@(stats.uid).stringValue];
    [session updateAudioStats:stats];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine firstLocalVideoFrameWithSize:(CGSize)size elapsed:(NSInteger)elapsed {
    VideoSession *session = [self localVideoSession];
    [session updateWithResolution:size];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine firstLocalAudioFrame:(NSInteger)elapsed {
    
}

/**
 * ERROR 大多是不可恢复的错误，需要通过 UI 提示用户
 */
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOccurError:(AgoraErrorCode)errorCode {
    NSString *msg = [NSString stringWithFormat:@"操作失败，didOccurError: %ld", errorCode];
    [self toastTip:msg];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinChannel:(NSString * _Nonnull)channel withUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    NSString *msg = [NSString stringWithFormat:@"[%@]进房成功[%@]: elapsed[%ld]", _selfUserID, _roomID, (long)elapsed];
    [self toastTip:msg];
    _enterRoomElapsed = elapsed;
    [self setRoomStatus:TRTC_ENTERED];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didLeaveChannelWithStats:(AgoraChannelStats * _Nonnull)stats {
//    NSString *msg = [NSString stringWithFormat:@"离开房间[%@]: reason[%ld]", _roomID, (long)reason];
//    [self toastTip:msg];
}

/**
 * 有新的用户加入了当前视频房间
 */
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinedOfUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    NSString *userId = @(uid).stringValue;
    
    TRTCVideoView *remoteView = [TRTCVideoView newVideoViewWithType:VideoViewType_Remote userId:userId];
    remoteView.delegate = self;
    [remoteView setBackgroundColor:UIColorFromRGB(0x262626)];
    [self.view addSubview:remoteView];
    [_remoteViewDic setObject:remoteView forKey:userId];
    
    // 将新进来的成员设置成大画面
    _mainViewUserId = userId;
    [self relayout];
    
    AgoraRtcVideoCanvas *videoCanvas = [[AgoraRtcVideoCanvas alloc] init];
    videoCanvas.uid = uid;
    videoCanvas.view = remoteView;
    videoCanvas.renderMode = AgoraVideoRenderModeHidden;
    [_agoraEngine setupRemoteVideo:videoCanvas];
}

/**
 * 有用户离开了当前视频房间
 */
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOfflineOfUid:(NSUInteger)uid reason:(AgoraUserOfflineReason)reason {
    NSString *userId = @(uid).stringValue;
    // 更新UI
    UIView *playerView = [_remoteViewDic objectForKey:userId];
    [playerView removeFromSuperview];
    [_remoteViewDic removeObjectForKey:userId];

    // 如果该成员是大画面，则当其离开后，大画面设置为本地推流画面
    if ([userId isEqual:_mainViewUserId]) {
        _mainViewUserId = _selfUserID;
    }
    [self relayout];
    
    AgoraRtcVideoCanvas *canvas = [[AgoraRtcVideoCanvas alloc] init];
    canvas.uid = userId.integerValue;
    canvas.view = nil;
    [_agoraEngine setupRemoteVideo:canvas];
    
    [_videoSessions removeObjectForKey:@(uid).stringValue];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didAudioMuted:(BOOL)muted byUid:(NSUInteger)uid {
    NSString *userId = @(uid).stringValue;
    BOOL available = !muted;
    TRTCVideoView *playerView = [_remoteViewDic objectForKey:userId];
    if (!available) {
        [playerView setAudioVolumeRadio:0.f];
    }
    NSLog(@"onUserAudioAvailable:userId:%@ alailable:%u", userId, available);
}

- (void)rtcEngine:(AgoraRtcEngineKit * _Nonnull)engine remoteVideoStateChangedOfUid:(NSUInteger)uid state:(AgoraVideoRemoteState)state reason:(AgoraVideoRemoteReason)reason elapsed:(NSInteger)elapsed {
    NSString *userId = @(uid).stringValue;
    if (!userId) {
        return;
    }
    TRTCVideoView* remoteView = [_remoteViewDic objectForKey:userId];
    BOOL mute = state == AgoraVideoRemoteStateStopped || state == AgoraVideoRemoteStateFailed;
    [remoteView showVideoCloseTip:mute];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine firstRemoteVideoFrameOfUid:(NSUInteger)uid size:(CGSize)size elapsed:(NSInteger)elapsed {
    VideoSession *session = [self videoSession:@(uid).stringValue];
    [session updateWithResolution:size];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didAudioRouteChanged:(AgoraAudioOutputRouting)routing {
    NSLog(@"onAudioRouteChanged to %ld", routing);
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didClientRoleChanged:(AgoraClientRole)oldRole newRole:(AgoraClientRole)newRole {
    NSLog(@"onSwitchRole old:%d, new:%d", (int)oldRole, (int)newRole);
}

#pragma mark - Statistics
- (VideoSession *)videoSession:(NSString *)userID {
    if (_useTRTC) {
        return nil;
    }
    TRTCVideoView *view = nil;
    if ([userID isEqualToString:@"0"]) {
        view = [self localView];
    } else {
        view = _remoteViewDic[userID];
    }
    
    VideoSession *session = _videoSessions[userID];


    if (nil == session) {
        NSUInteger uid = 0;
        if ([userID isKindOfClass:[NSString class]]) {
            uid = [(NSString *)userID integerValue];
        }
        session = [[VideoSession alloc] initWithUserID:uid view:view];
        if (uid == 0) {
            [session setToLocalSession];
        }
        _videoSessions[userID] = session;
    }
    session.hostingView = view;
    return session;
}

- (VideoSession *)localVideoSession {
    return [self videoSession:@"0"];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine networkQuality:(NSUInteger)uid txQuality:(AgoraNetworkQuality)txQuality rxQuality:(AgoraNetworkQuality)rxQuality {
    if (uid == 0) {
        [_localView setNetworkIndicatorImage:[self imageForNetworkQuality:txQuality]];
    } else {
        TRTCVideoView* remoteVideoView = [_remoteViewDic objectForKey:@(uid).stringValue];
        [remoteVideoView setNetworkIndicatorImage:[self imageForNetworkQuality:txQuality]];
    }
    if(_showLogType == 1 && !self.useTRTC){
        //打开仪表盘(防止远端用户重进房后仪表盘自动关闭)
        [_remoteViewDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, TRTCVideoView * view, BOOL * _Nonnull stop) {
            [view setLogHidden:NO];
        }];
        [_localView setLogHidden:NO];
    }
    [[self videoSession:@(uid).stringValue] updateWithTxQuality:txQuality rxQuality:rxQuality];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine reportAudioVolumeIndicationOfSpeakers:(NSArray<AgoraRtcAudioVolumeInfo *> *)speakers totalVolume:(NSInteger)totalVolume {
    [_remoteViewDic enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull key, TRTCVideoView * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj setAudioVolumeRadio:0.f];
        [obj showAudioVolume:YES];
    }];
    
    const float range = 255.0;

    for (AgoraRtcAudioVolumeInfo *info in speakers) {
        NSUInteger uid = info.uid;
        TRTCVideoView* videoView = [_remoteViewDic objectForKey:@(uid).stringValue];
        if (videoView) {
            float radio = info.volume / range;
            [videoView setAudioVolumeRadio:radio];
        }
    }
}

- (UIImage*)imageForNetworkQuality:(AgoraNetworkQuality)quality {
    
    UIImage* image = nil;
    switch (quality) {
        case AgoraNetworkQualityDown:
        case AgoraNetworkQualityVBad:
            image = [UIImage imageNamed:@"signal5"];
            break;
        case AgoraNetworkQualityBad:
            image = [UIImage imageNamed:@"signal4"];
            break;
        case AgoraNetworkQualityPoor:
            image = [UIImage imageNamed:@"signal3"];
            break;
        case AgoraNetworkQualityGood:
            image = [UIImage imageNamed:@"signal2"];
            break;
        case AgoraNetworkQualityExcellent:
            image = [UIImage imageNamed:@"signal1"];
            break;
        default:
            break;
    }
    
    return image;
}
#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

/**
 @method 获取指定宽度width的字符串在UITextView上的高度
 @param textView 待计算的UITextView
 @param width 限制字符串显示区域的宽度
 @result float 返回的高度
 */
- (float)heightForString:(UITextView *)textView andWidth:(float)width {
    CGSize sizeToFit = [textView sizeThatFits:CGSizeMake(width, MAXFLOAT)];
    return sizeToFit.height;
}

- (void)toastTip:(NSString *)toastInfo {
    _toastMsgCount++;
    
    CGRect frameRC = [[UIScreen mainScreen] bounds];
    frameRC.origin.y = frameRC.size.height - 110;
    frameRC.size.height -= 110;
    __block UITextView *toastView = [[UITextView alloc] init];
    
    toastView.editable = NO;
    toastView.selectable = NO;
    
    frameRC.size.height = [self heightForString:toastView andWidth:frameRC.size.width];
    
    // 避免新的tips将之前未消失的tips覆盖掉，现在是不断往上偏移
    frameRC.origin.y -= _toastMsgHeight;
    _toastMsgHeight += frameRC.size.height;
    
    toastView.frame = frameRC;
    
    toastView.text = toastInfo;
    toastView.backgroundColor = [UIColor whiteColor];
    toastView.alpha = 0.5;
    
    [self.view addSubview:toastView];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    
    __weak __typeof(self) weakSelf = self;
    dispatch_after(popTime, dispatch_get_main_queue(), ^() {
        [toastView removeFromSuperview];
        toastView = nil;
        if (weakSelf.toastMsgCount > 0) {
            weakSelf.toastMsgCount--;
        }
        if (weakSelf.toastMsgCount == 0) {
            weakSelf.toastMsgHeight = 0;
        }
    });
}

#pragma mark - 系统事件
/**
 * 在前后堆叠模式下，响应手指触控事件，用来切换视频画面的布局
 */

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
}

- (void)onViewTap:(TRTCVideoView *)view touchCount:(NSInteger)touchCount {
    if (_roomStatus != TRTC_ENTERED) {
        return;
    }
    
    if (_layoutEngine.type == TC_Gird)
        return;
    
    if (view == _localView) {
        _mainViewUserId = _selfUserID;
    } else {
        for (id userID in _remoteViewDic) {
            UIView *pw = [_remoteViewDic objectForKey:userID];
            if (view == pw ) {
                _mainViewUserId = userID;
            }
        }
    }
    [self relayout];
    return;
}

- (void)onAudioCapturePcm:(NSData *)pcmData sampleRate:(int)sampleRate channels:(int)channels ts:(uint32_t)timestampMs {
//    TRTCAudioFrame * frame = [[TRTCAudioFrame alloc] init];
//    frame.data = pcmData;
//    frame.sampleRate = sampleRate;
//    frame.channels = channels;
//    frame.timestamp = timestampMs;
//    [_trtc sendCustomAudioData:frame];
}

@end
