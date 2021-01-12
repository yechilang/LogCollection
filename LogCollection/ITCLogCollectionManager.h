//
//  ITCLogCollectionManager.h
//  日志采集
//
//  Created by itc on 2020/11/24.
//

#import <Foundation/Foundation.h>

/**
 前提:
 pod 'SSZipArchive', "~> 2.9.2"
 pod "Qiniu", "~> 8.0.5"
 
 使用:
 1. 在AppDelegate处导入 #import "ITCLogCollectionManager.h"
 2. 在- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;处调用
     ITCLogCollectionManager *manager = ITCLogCollectionManager.shareManager;
     [manager defaultConfigModel]; // 必须构建模型, 或使用 - (void)configModel:(NSTimeInterval)validPeriod fileCount:(NSInteger)count fileSize:(double)size cache:(BOOL)cache; 配置
     [manager insertDeviceData]; // 可选插入设备信息
 
     // 可选配置七牛云信息, 但在上传前必须配置
     NSString *scope = @"infocollection";
     NSString *accessKey = @"mBFowxvZuNg7j88ADUR3mh37S2kyRRD35zee6Am5";
     NSString *secretKey = @"6UIbw1zXCZX3yvPxRx4CU9hMyRc0TpbeqsKmRMAT";
     [manager configUploadInfo:scope ak:accessKey sk:secretKey];
 3. 在私有入口处使用- (instancetype)initWithClickCallBack:(void(^)(ITCLogCollectionViewController *vc))block;创建ITCLogCollectionViewController
 4. 在需要添加到日志的地方使用以下方法添加日志
 - (void)insertDebugInfo:(NSString *)info;
 - (void)insertNetworkInfo:(NSString *)info;
 - (void)insertDeviceInfo:(NSString *)info;
 - (void)insertCrashInfo:(NSString *)info;
 5. 日志要附带以下信息, 并没条日志需要换行
 [NSString stringWithFormat:@"%@ %s %d %s\n\n", ITCLogCollectionManager.timeString, __FILE_NAME__, __LINE__, __func__]
 6. 使用宏去修改NSLog
 
 注意:
 如果使用cache再一次性存储的话, 需要防止强退导致日志没写入
 解决:
 AppDelegate里重写以下方法, 并且使用window而不使用scenes, 如果使用了scenes, 则需要替换成对应的方法
 - (void)applicationDidEnterBackground:(UIApplication *)application {
     [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{}];
 }

 - (void)applicationWillTerminate:(UIApplication *)application {
     [ITCLogCollectionManager.shareManager closeFile];
 }
 */

typedef NS_ENUM(NSUInteger, ITCUploadStatus) {
//    ITCUploadStatusIdle,
    ITCUploadStatusZip,
    ITCUploadStatusBeginUpload,
    ITCUploadStatusUploading,
    ITCUploadStatusCompletion,
    ITCUploadStatusFailure,
};

NS_ASSUME_NONNULL_BEGIN

@interface ITCLogCollectionManager : NSObject

/// 单例, 使用方法创建
+ (instancetype)shareManager;

/// 默认配置需要处理, 使用默认值调用 - (void)configModel:(NSTimeInterval)validPeriod fileCount:(NSInteger)count fileSize:(double)size cache:(BOOL)cache;
- (void)defaultConfigModel;

/// 配置需要处理的信息模型
/// @param validPeriod 有效期
/// @param count 记录文件数量
/// @param size 每个记录文件大小, 单位字节
/// @param cache 是否使用cache, true: 使用 false: 不使用
- (void)configModel:(NSTimeInterval)validPeriod fileCount:(NSInteger)count fileSize:(double)size cache:(BOOL)cache;

/// 配置上传信息, 需要调用上传模块则需要配置
/// @param scope 上传文件名
/// @param accessKey 七牛云accessKey
/// @param secretKey 七牛云secretKey
- (void)configUploadInfo:(NSString *)scope ak:(NSString *)accessKey sk:(NSString *)secretKey;

/// 插入debug信息
/// @param info 需要插入的信息
- (void)insertDebugInfo:(NSString *)info;

/// 插入网络信息
/// @param info 需要插入的信息
- (void)insertNetworkInfo:(NSString *)info;

/// 插入设备信息
/// @param info 需要插入的信息
- (void)insertDeviceInfo:(NSString *)info;

/// 插入崩溃信息, 会断开文件操作
/// @param info 需要插入的信息
- (void)insertCrashInfo:(NSString *)info;

/// 清除记录
- (void)cleanInfo;

/// 插入设备信息
- (void)insertDeviceData;

/// 关闭文件处理, 使用cache的话强退时需要调用
- (void)closeFile;

/// 压缩并上传, 需要先调用 - (void)configUploadInfo:(NSString *)scope ak:(NSString *)accessKey sk:(NSString *)secretKey; 进行配置七牛云信息
- (void)uploadToServer:(void(^)(ITCUploadStatus status, double progress))block;

/// 获取未压缩文件大小
- (NSInteger)uploadFileSize;

/// 文件大小转字符串
/// @param fileSize 文件大小
- (NSString *)fileSizeString:(NSInteger)fileSize;

/// 资源bundle
- (NSBundle *)logCollectionBundle;

/// 清除压缩包
- (void)cleanZip;

/// 当前时间戳
+ (NSTimeInterval)time;

/// 时间字符串
+ (NSString *)timeString;

@end

NS_ASSUME_NONNULL_END
