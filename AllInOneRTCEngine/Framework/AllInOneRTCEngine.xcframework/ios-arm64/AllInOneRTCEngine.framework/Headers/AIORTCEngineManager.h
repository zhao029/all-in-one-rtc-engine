//
//  AIORTCEngineManager.h
//  APIExample-OC
//
//  Created by CY zhao on 2024/3/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AIORTCEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface AIORTCEngineManager : NSObject
+ (id<AIORTCEngine> _Nonnull)sharedEngineWithAppId:(NSString *_Nonnull)appId
                                               delegate:(id<AgoraRtcEngineDelegate> _Nullable)delegate
                                                useTRTC: (BOOL)useTRTC;

+ (id<AIORTCEngine> _Nonnull)sharedEngineWithConfig:(AgoraRtcEngineConfig *_Nonnull)config
                                                delegate:(id<AgoraRtcEngineDelegate> _Nullable)delegate
                                                 useTRTC: (BOOL)useTRTC;

+ (void)destroy;

@end

NS_ASSUME_NONNULL_END
