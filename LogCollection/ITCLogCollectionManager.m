//
//  ITCLogCollectionManager.m
//  日志采集
//
//  Created by itc on 2020/11/24.
//

#import "ITCLogCollectionManager.h"
#import "SSZipArchive.h" // 上传前压缩
#import <CommonCrypto/CommonHMAC.h> // hmac加密
#import <Qiniu/QiniuSDK.h> // 七牛云上传
#import <Qiniu/QN_GTM_Base64.h> // 七牛云 base64转码
#import <sys/utsname.h> // 获取手机型号
#import <UIKit/UIKit.h> // 获取系统版本
#import "ITCInfoModel.h" // 实例

@interface ITCLogCollectionManager ()

@property (nonatomic, weak) NSFileManager *fileManager; //!< 文件管理者
@property (nonatomic, copy) NSString *rootName; //!< 存储主文件夹名称
@property (nonatomic, copy) NSString *rootPath; //!< 存储主路径
@property (nonatomic, strong) ITCInfoModel *debugInfo; //!< 处理debug信息模型
@property (nonatomic, strong) ITCInfoModel *networkInfo; //!< 处理网络信息模型
@property (nonatomic, strong) ITCInfoModel *deviceInfo; //!< 处理设备信息模型

@property (nonatomic, strong) NSBundle *bundle; //!< 资源bundle

// 模型配置相关
@property (nonatomic, assign) NSTimeInterval validPeriod; //!< 信息文件缓存期限
@property (nonatomic, assign) NSInteger fileCount; //!< 信息文件数量
@property (nonatomic, assign) double fileSize; //!< 每个信息文件大小
@property (nonatomic, assign) BOOL cache; //!< 是否使用缓存

// 上传相关
@property (nonatomic, copy) NSString *zipFileName; //!< 压缩文件名
@property (nonatomic, copy) NSString *zipFilePath; //!< 压缩文件存放处
@property (nonatomic, copy) NSString *accessKey; //!< 七牛云ak
@property (nonatomic, copy) NSString *secretKey; //!< 七牛云sk
@property (nonatomic, copy) NSString *scope; //!< 七牛云文件夹
@property (nonatomic, strong) NSDateFormatter *formatter; //!< 时间格式

@end

@implementation ITCLogCollectionManager

#pragma mark - 构造
+ (instancetype)shareManager {
    static ITCLogCollectionManager *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[ITCLogCollectionManager alloc] init];
        NSSetUncaughtExceptionHandler(&captureException);
    });
    return _instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _formatter = [[NSDateFormatter alloc] init];
        _formatter.dateFormat = @"yyyy/MM/dd HH:mm:ss.SSS";
        // 参考
        // http://blog.xianqu.org/2015/08/pod-resources/
        // https://juejin.cn/post/6844903854245412877
        _bundle = [NSBundle bundleWithPath:[NSBundle.mainBundle pathForResource:@"LogCollection" ofType:@"bundle"]];
        
        [self configRoot]; // 配置根目录
        [self cleanZip]; // 清除旧压缩包
    }
    return self;
}

/// 默认配置需要处理, 使用默认值调用 - (void)configModel:(NSTimeInterval)validPeriod fileCount:(NSInteger)count fileSize:(double)size cache:(BOOL)cache;
- (void)defaultConfigModel {
    NSInteger validPeriod = 2 * 24 * 60 * 60; // 2天过期
    NSInteger fileCount = 20; // 文件数量
    NSInteger fileSize = 1 << 20; // 每个文件大小
    [self configModel:validPeriod fileCount:fileCount fileSize:fileSize cache:false];
}

/// 配置需要处理的信息模型
/// @param validPeriod 有效期
/// @param count 记录文件数量
/// @param size 每个记录文件大小, 单位字节
/// @param cache 是否使用cache, true: 使用 false: 不使用
- (void)configModel:(NSTimeInterval)validPeriod fileCount:(NSInteger)count fileSize:(double)size cache:(BOOL)cache {
    NSString *markFileName = @"mark.plist";
    _validPeriod = validPeriod;
    _fileCount = count;
    _fileSize = size;
    _cache = cache;
    
    _debugInfo = ({
        ITCInfoModel *model = [ITCInfoModel modelWithName:@"Debug" basePath:_rootPath markFileName:markFileName cache:cache validPeriod:validPeriod fileCount:count fileSize:size];
        [model checkFile];
        [model updateFile];
        model;
    });
    _networkInfo = ({
        ITCInfoModel *model = [ITCInfoModel modelWithName:@"Network" basePath:_rootPath markFileName:markFileName cache:cache validPeriod:validPeriod fileCount:count fileSize:size];
        [model checkFile];
        [model updateFile];
        model;
    });
    _deviceInfo = ({
        ITCInfoModel *model = [ITCInfoModel modelWithName:@"Device" basePath:_rootPath markFileName:markFileName cache:cache validPeriod:validPeriod fileCount:count fileSize:size];
        [model checkFile];
        [model updateFile];
        model;
    });
}

#pragma mark - 私有方法
/// 检测根目录创建
- (void)configRoot {
    NSString *documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES).firstObject;
    _rootName = @"LogInformation";
    _rootPath = [documentPath stringByAppendingPathComponent:_rootName];
    _fileManager = NSFileManager.defaultManager;
    
    if ([_fileManager fileExistsAtPath:_rootPath] == false) {
        [_fileManager createDirectoryAtPath:_rootPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
//    NSLog(@"信息保存地址: %@", _rootPath);
}

/// 关闭文件处理
- (void)closeFile {
    [_debugInfo closeFile];
    [_networkInfo closeFile];
    [_deviceInfo closeFile];
    
    _debugInfo = nil;
    _networkInfo = nil;
    _deviceInfo = nil;
}

#pragma mark --捕获异常
void captureException(NSException *exception){
    NSString *info = [NSString stringWithFormat:@"时间: %@\n*** Terminating app due to uncaught exception '%@', reason: '%@'\n*** First throw call stack:\n%@\n\n", ITCLogCollectionManager.timeString, exception.name, exception.reason, exception.callStackSymbols];
    [ITCLogCollectionManager.shareManager insertCrashInfo:info];
}

#pragma mark - 接口
/// 配置上传信息, 创建后需要配置
/// @param scope 上传文件名
/// @param accessKey 七牛云accessKey
/// @param secretKey 七牛云secretKey
- (void)configUploadInfo:(NSString *)scope ak:(NSString *)accessKey sk:(NSString *)secretKey {
    _zipFileName = @"info.zip"; // 压缩信息
    _zipFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:_zipFileName];
    
    _scope = scope; // 七牛云上传信息
    _accessKey = accessKey;
    _secretKey = secretKey;
}

/// 插入debug信息
/// @param info 需要插入的信息
- (void)insertDebugInfo:(NSString *)info {
    [_debugInfo insertInfo:info];
}

/// 插入网络信息
/// @param info 需要插入的信息
- (void)insertNetworkInfo:(NSString *)info {
    [_networkInfo insertInfo:info];
}

/// 插入设备信息
/// @param info 需要插入的信息
- (void)insertDeviceInfo:(NSString *)info {
    [_deviceInfo insertInfo:info];
}

/// 插入崩溃信息, 会断开文件操作
/// @param info 需要插入的信息
- (void)insertCrashInfo:(NSString *)info {
    [_deviceInfo insertInfo:info];
    [self closeFile];
}

/// 清除记录
- (void)cleanInfo {
    [self closeFile];
    if ([_fileManager fileExistsAtPath:_rootPath]) {
        [_fileManager removeItemAtPath:_rootPath error:nil];
    }
    [self configRoot];
    [self configModel:_validPeriod fileCount:_fileCount fileSize:_fileSize cache:_cache];
    [self cleanZip];
}

/// 插入设备信息
- (void)insertDeviceData {
    NSMutableString *info = [NSMutableString string];
    [info appendFormat:@"时   间: %@\n", ITCLogCollectionManager.timeString]; // 时间
    [info appendFormat:@"手机型号: %@\n", self.deviceName]; // 设备名
    [info appendFormat:@"系统版本: %@\n", self.systemVersion]; // 设备版本
    [info appendFormat:@"app版本: %@\n\n", self.applicationInfo]; // app信息
    [self insertDeviceInfo:info];
}

/// 资源bundle
- (NSBundle *)logCollectionBundle {
    return _bundle;
}

#pragma mark - 压缩、上传
/// 压缩并上传, 需要先调用 - (void)configUploadInfo:(NSString *)scope ak:(NSString *)accessKey sk:(NSString *)secretKey; 进行配置七牛云信息
- (void)uploadToServer:(void(^)(ITCUploadStatus status, double progress))block {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd HHmmss";
    NSString *uploadFileName = [NSString stringWithFormat:@"%@.zip", [formatter stringFromDate:NSDate.date]];
    
    // 进行压缩
    if (block) {
        block(ITCUploadStatusZip, 0);
    }
    [SSZipArchive createZipFileAtPath:_zipFilePath withContentsOfDirectory:_rootPath];
    
    // 上传功能
    if (block) {
        block(ITCUploadStatusBeginUpload, 0);
    }
    NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:_zipFilePath]];
    NSString *token = [self tokenWithFileName:uploadFileName];
    QNUploadManager *upManager = [[QNUploadManager alloc] init];
    QNUploadOption *option = [[QNUploadOption alloc] initWithProgressHandler:^(NSString *key, float percent) {
        if (block) {
            block(ITCUploadStatusUploading, percent);
        }
    }];
    [upManager putData:data
                   key:uploadFileName
                 token:token
              complete: ^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        if ([info.message isEqualToString:@"ok"]) {
            if (block) {
                block(ITCUploadStatusCompletion, 0);
            }
        } else {
            if (block) {
                block(ITCUploadStatusFailure, 0);
            }
        }
        [self cleanZip]; // 上传完成后清除
    }
                option:option];
}

/// 根据上传文件名获取token
- (NSString *)tokenWithFileName:(NSString *)fileName {
    NSMutableDictionary *policy = @{}.mutableCopy; // 构造policy
    policy[@"scope"] = [NSString stringWithFormat:@"%@:%@", _scope, fileName];
    policy[@"deadline"] = @((NSInteger)ITCLogCollectionManager.time + 60 * 60);
    policy[@"insertOnly"] = @(0);
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:policy options:NSJSONWritingPrettyPrinted error:nil]; // 策略转为json data
    NSString *base64PaddedPolicy = [QN_GTM_Base64 stringByWebSafeEncodingData:data padded:true]; // 转为 添加padded的base64字符串
    
    char digestStr[CC_SHA1_DIGEST_LENGTH]; // 用密钥加密策略
//    bzero(digestStr, 0);
    CCHmac(kCCHmacAlgSHA1,
           _secretKey.UTF8String,
           _secretKey.length,
           base64PaddedPolicy.UTF8String,
           base64PaddedPolicy.length,
           digestStr);
    NSString *base64SHA1 = [QN_GTM_Base64 stringByWebSafeEncodingBytes:digestStr length:CC_SHA1_DIGEST_LENGTH padded:true];
    NSString *token = [NSString stringWithFormat:@"%@:%@:%@",  _accessKey, base64SHA1, base64PaddedPolicy];
    return token;
}

/// 获取未压缩文件大小
- (NSInteger)uploadFileSize {
    if ([_fileManager fileExistsAtPath:_rootPath]) {
        NSArray <NSString *> *subPaths = [_fileManager subpathsAtPath:_rootPath];
        double fileSize = 0;
        for (NSString *subPath in subPaths) {
            NSString *path = [_rootPath stringByAppendingPathComponent:subPath];
            
            if ([_fileManager fileExistsAtPath:path]) {
                if ([subPath containsString:@".DS_Store"]) {
                    [_fileManager removeItemAtPath:path error:nil];
                } else {
                    NSDictionary<NSFileAttributeKey, id> *att = [_fileManager attributesOfItemAtPath:path error:nil];
                    if ([att.fileType isEqualToString:NSFileTypeRegular]) {
                        fileSize += att.fileSize;
                    }
                }
            }
        }
        return fileSize;
    } else {
        return 0;
    }
}

/// 文件大小转字符串
/// @param fileSize 文件大小
- (NSString *)fileSizeString:(NSInteger)fileSize {
    NSString *sizeString;
    if (fileSize < 1 << 10) { // B
        sizeString = [NSString stringWithFormat:@"%ldB", fileSize];
    } else if (fileSize < 1 << 20) { // KB
        sizeString = [NSString stringWithFormat:@"%.2lfKB", floor((double)fileSize / (double)(1 << 10) * 100) / 100];
    } else if (fileSize < 1 << 30) { // MB
        sizeString = [NSString stringWithFormat:@"%.2lfMB", floor((double)fileSize / (double)(1 << 20) * 100) / 100];
    } else { // GB
        sizeString = [NSString stringWithFormat:@"%.2lfMB", floor((double)fileSize / (double)(1 << 30) * 100) / 100];
    }
    return sizeString;
}

/// 清除压缩包
- (void)cleanZip {
    if ([_fileManager fileExistsAtPath:_zipFilePath]) {
        [_fileManager removeItemAtPath:_zipFilePath error:nil];
    }
}

#pragma mark - 信息获取
/// 获取当前设备名
- (NSString *)deviceName {
    // https://www.jianshu.com/p/d0382538049a
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSASCIIStringEncoding];
    return deviceString;
}

/// 获取系统版本
- (NSString *)systemVersion {
    return [NSString stringWithFormat:@"%@ %@", UIDevice.currentDevice.systemName, UIDevice.currentDevice.systemVersion];
}

/// 获取app版本
- (NSString *)applicationInfo {
    NSString *bundleName = NSBundle.mainBundle.infoDictionary[@"CFBundleName"];
    NSString *version = NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"];
    NSString *build = NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"];
    return [NSString stringWithFormat:@"bundleName: %@ version: %@ build: %@", bundleName, version, build];
}

/// 当前时间戳
+ (NSTimeInterval)time {
    return CFAbsoluteTimeGetCurrent() + 978307200;
}

/// 获取当前时间字符串
+ (NSString *)timeString {
    // 如果不需要精确到毫秒, 则使用strftime方法更快
//    time_t time = [self time];
//    char buffer[40];
//    strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", localtime(&time));
//    return [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
    
    // 需要毫秒则formatter更快
    return [ITCLogCollectionManager.shareManager.formatter stringFromDate:NSDate.date];
}

@end
