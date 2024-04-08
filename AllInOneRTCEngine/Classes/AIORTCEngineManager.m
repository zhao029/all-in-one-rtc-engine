//
//  AIORTCEngineManager.m
//  APIExample-OC
//
//  Created by CY zhao on 2024/3/15.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import "AIORTCEngineManager.h"
#import "AIOTRTCEngineWrapper.h"
#import "AIOAgoraEngineWrapper.h"

@implementation AIORTCEngineManager

+ (id<AIORTCEngine> _Nonnull)sharedEngineWithAppId:(NSString *_Nonnull)appId
                                               delegate:(id<AgoraRtcEngineDelegate> _Nullable)delegate
                                                useTRTC: (BOOL)useTRTC {
    if (useTRTC) {
        [AIOAgoraEngineWrapper destroy];
        return [AIOTRTCEngineWrapper sharedEngineWithAppId:appId delegate:delegate];
    } else {
        [AIOTRTCEngineWrapper destroy];
        return [AIOAgoraEngineWrapper sharedEngineWithAppId:appId delegate:delegate];
    }
}

+ (id<AIORTCEngine> _Nonnull)sharedEngineWithConfig:(AgoraRtcEngineConfig *_Nonnull)config
                                                delegate:(id<AgoraRtcEngineDelegate> _Nullable)delegate
                                                 useTRTC: (BOOL)useTRTC {
    if (useTRTC) {
        [AIOAgoraEngineWrapper destroy];
        return [AIOTRTCEngineWrapper sharedEngineWithConfig:config delegate:delegate];
    } else {
        [AIOTRTCEngineWrapper destroy];
        return [AIOAgoraEngineWrapper sharedEngineWithConfig:config delegate:delegate];
    }
}

+ (void)destroy {
    [AIOAgoraEngineWrapper destroy];
    [AIOTRTCEngineWrapper destroy];
}

@end
