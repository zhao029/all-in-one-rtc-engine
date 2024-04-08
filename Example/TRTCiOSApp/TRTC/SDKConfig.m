//
//  SDKConfig.m
//  APIExample-OC
//
//  Created by CY zhao on 2024/2/29.
//

#import "SDKConfig.h"

static const int TXSDKAppID = YOUR_TX_APPID;

static NSString *const kAgoraAppID = YOUR_AGORA_APPID;
static NSString *const kAgoraCertificate = @"";
static NSString *const kAgoraTemporaryToken = @"";

@implementation SDKConfig

+ (int)TXSDKAppID {
    return TXSDKAppID;
}

+ (nullable NSString *)AgoraAppID;{
    return kAgoraAppID;
}

+ (nullable NSString *)AgoraCertificate {
    return kAgoraCertificate;
}

+ (NSString *)AgoraTemporaryToken {
    return kAgoraTemporaryToken;
}
@end
