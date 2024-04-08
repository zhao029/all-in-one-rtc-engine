//
//  TXLivePlayerViewController.m
//  TXLiteAVDemo_TRTC
//
//  Created by ericxwli on 2019/1/9.
//  Copyright © 2019年 Tencent. All rights reserved.
//
#ifdef ENABLE_PLAY
#import "TXLivePlayerViewController.h"
#import "TXLivePlayer.h"
#import "ColorMacro.h"
#import "NSString+Common.h"

@interface TXLivePlayerViewController ()
{
    TXLivePlayer *_txLivePlayer;
    UIView *_mVideoContainer;
    UIButton *_btnLog;
}
@end

@implementation TXLivePlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _txLivePlayer = [[TXLivePlayer alloc] init];
    [self.view setBackgroundColor:UIColorFromRGB(0x333333)];
    
    CGRect VideoFrame = self.view.bounds;
    _mVideoContainer = [[UIView alloc] initWithFrame:CGRectMake(VideoFrame.size.width, 0, VideoFrame.size.width, VideoFrame.size.height)];
    [self.view insertSubview:_mVideoContainer atIndex:0];
    _mVideoContainer.center = self.view.center;
    
    int ICON_SIZE = self.view.frame.size.width / 8;
    _btnLog = [self createBottomBtnIcon:@"log_b2"
                                 Action:@selector(clickLog:)
                                 Center:CGPointMake(self.view.center.x , self.view.frame.size.height - ICON_SIZE/2)
                                   Size:ICON_SIZE];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
    [_txLivePlayer setupVideoWidget:CGRectMake(0, 0, 0, 0) containView:_mVideoContainer insertIndex:0];
    [_txLivePlayer startPlay:self.playUrl type:PLAY_TYPE_LIVE_FLV];
    [_txLivePlayer showVideoDebugLog:YES];
    [_txLivePlayer setRenderMode:RENDER_MODE_FILL_EDGE];
}
- (NSString *)playUrl{
    NSString *md5 = [[NSString stringWithFormat:@"%@_%@_%@",self.roomId,self.userId,self.streamStr] md5];
    NSString *url = [NSString stringWithFormat:@"http://%@.liveplay.myqcloud.com/live/%@_%@.flv",BIZID,BIZID,md5];
    return url;
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
}
- (void)dealloc{
    [_txLivePlayer stopPlay];
}
- (void)clickLog:(UIButton *)btn{
    btn.selected = !btn.selected;
    [_txLivePlayer showVideoDebugLog:!btn.selected];
}
- (UIButton*)createBottomBtnIcon:(NSString*)icon Action:(SEL)action Center:(CGPoint)center  Size:(int)size
{
    UIButton * btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.center = center;
    btn.bounds = CGRectMake(0, 0, size, size);
    [btn setImage:[UIImage imageNamed:icon] forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    return btn;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
#endif
