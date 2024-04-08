//
//  TXLivePlayerViewController.h
//  TXLiteAVDemo_TRTC
//
//  Created by ericxwli on 2019/1/9.
//  Copyright © 2019年 Tencent. All rights reserved.
//
#ifdef ENABLE_PLAY
#import <UIKit/UIKit.h>
#define BIZID @"8525"
NS_ASSUME_NONNULL_BEGIN

@interface TXLivePlayerViewController : UIViewController
@property(nonatomic,strong)NSString *roomId;
@property(nonatomic,strong)NSString *userId;
@property(nonatomic,strong)NSString *streamStr;
@end

NS_ASSUME_NONNULL_END
#endif
