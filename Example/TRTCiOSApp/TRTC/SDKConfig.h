//
//  SDKConfig.h
//  APIExample-OC
//
//  Created by CY zhao on 2024/2/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SDKConfig : NSObject

/**
 * 腾讯云 SDKAppId，需要替换为您自己账号下的 SDKAppId。
 * <p>
 * 进入腾讯云云通信[控制台](https://console.cloud.tencent.com/avc) 创建应用，即可看到 SDKAppId，
 * 它是腾讯云用于区分客户的唯一标识。
 */
+ (int)TXSDKAppID;

+ (nullable NSString *)AgoraAppID;

+ (nullable NSString *)AgoraCertificate;

+ (NSString *)AgoraTemporaryToken;
@end

NS_ASSUME_NONNULL_END
