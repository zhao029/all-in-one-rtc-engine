//
//  AIOTRTCEngineWrapperUtils.h
//  APIExample-OC
//
//  Created by CY zhao on 2024/3/7.
//  Copyright © 2024 Tencent. All rights reserved.
//

#ifndef AIOTRTCEngineWrapperUtils_h
#define AIOTRTCEngineWrapperUtils_h

#ifdef __cplusplus
extern "C" {
#else
#include <stdbool.h>
#endif

typedef enum {
    TXE_LOG_VERBOSE = 0,
    TXE_LOG_DEBUG,
    TXE_LOG_INFO,
    TXE_LOG_WARNING,
    TXE_LOG_ERROR,
    TXE_LOG_FATAL,
    TXE_LOG_NONE,
} TXELogLevel;

void txf_log(TXELogLevel level, const char *file, int line, const char *func, const char *format, ...);

#ifdef __cplusplus
}
#endif

#define LOGI(fmt, ...) \
    txf_log(TXE_LOG_INFO, __FILE__, __LINE__, __FUNCTION__, fmt, ##__VA_ARGS__)

#define LOGE(fmt, ...) \
    txf_log(TXE_LOG_ERROR, __FILE__, __LINE__, __FUNCTION__, fmt, ##__VA_ARGS__)

#define selfForDelegate (AgoraRtcEngineKit *)self

#define TIME_SINCE_ROOM_ENTRY_MS ((NSInteger)(CFAbsoluteTimeGetCurrent() - self.enterRoomTime) * 1000)

#define AUDIO_SWITCH_GUARD if (!self.isAudioEnabled) { LOGI("apollo_api, %s, Audio disabled", __FUNCTION__); return WrapperErrorCodeFailed; }
#define VIDEO_SWITCH_GUARD if (!self.isVideoEnabled) { LOGI("apollo_api, %s, Video disabled", __FUNCTION__); return WrapperErrorCodeFailed; }

#endif /* AIOTRTCEngineWrapperUtils_h */
