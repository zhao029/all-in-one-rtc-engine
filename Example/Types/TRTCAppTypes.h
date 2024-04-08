//
//  TRTCAppTypes.h
//  TRTCApp
//
//  Created by user on 2019/6/18.
//  Copyright © 2019 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AgoraRtcKit;

NS_ASSUME_NONNULL_BEGIN

@interface TRTCLoginParam : NSObject
@property (nonatomic, strong, nonnull) NSString* sdkAppId;
@property (nonatomic, strong, nonnull) NSString* userId;
@property (nonatomic, strong, nonnull) NSString* userSig;
@property (nonatomic, strong, nonnull) NSString * roomId;
@property (nonatomic, assign) AgoraClientRole role;
@end
#if ((!TARGET_OS_IPHONE) && TARGET_OS_MAC)
@interface TRTCAppScreenCaptureSourceInfo : NSObject
/// 分享类型：要分享的是某个窗口还是整个屏幕
@property (assign, nonatomic) BOOL isScreen;
/// 窗口ID
@property (copy, nonatomic, nullable) NSString * sourceId;
/// 窗口名称
@property (copy, nonatomic, nullable) NSString * sourceName;
/// 窗口属性
@property (nonatomic, strong, nullable) NSDictionary * extInfo;
/// 窗口缩略图
@property (nonatomic, readonly, nullable) NSImage *thumbnail;
/// 窗口小图标
@property (nonatomic, readonly, nullable) NSImage *icon;
@end
#endif
NS_ASSUME_NONNULL_END
