//
//  AIOAgoraEngineWrapper.h
//  APIExample-OC
//
//  Created by CY zhao on 2024/3/13.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AIORTCEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface AIOAgoraEngineWrapper : NSObject<AIORTCEngine>

@property(nonatomic, weak) id<AgoraRtcEngineDelegate> _Nullable delegate;

+ (instancetype _Nonnull)sharedEngineWithAppId:(NSString *_Nonnull)appId
                                      delegate:(id<AgoraRtcEngineDelegate> _Nullable)delegate;

+ (instancetype _Nonnull)sharedEngineWithConfig:(AgoraRtcEngineConfig *_Nonnull)config
                                       delegate:(id<AgoraRtcEngineDelegate> _Nullable)delegate;

+ (void)destroy;

@end

NS_ASSUME_NONNULL_END
