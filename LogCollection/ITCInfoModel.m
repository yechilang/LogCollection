//
//  ITCInfoModel.m
//  日志采集
//
//  Created by itc on 2021/1/4.
//

#import "ITCInfoModel.h"
#import "ITCLogCollectionManager.h" // 使用api

@interface ITCInfoModel ()

// 外部赋值, 指定构造方法赋值
@property (nonatomic, copy) NSString *name; //!< 类型名
@property (nonatomic, copy) NSString *markFileName; //!< 记录的文件名
@property (nonatomic, assign) NSInteger validPeriod; //!< 有效期
@property (nonatomic, assign) NSInteger fileCount; //!< 文件最大数量
@property (nonatomic, assign) NSInteger maxFileSize; //!< 每个文件最大大小

// 内部使用
@property (nonatomic, weak) NSFileManager *fileManager; //!< 文件管理者
@property (nonatomic, copy) NSString *path; //!< 保存路径
@property (nonatomic, strong) NSMutableArray *mark; //!< 记录
@property (nonatomic, assign) NSInteger currentFileSize; //!< 当前写入的文件大小

@property (nonatomic, assign, getter=isCache) BOOL cache; //!< 是否使用缓存
// cache = true时使用
@property (nonatomic, strong) NSMutableData *insertData; //!< 插入数据
// cache = false时使用
@property (nonatomic, strong) NSFileHandle *fileHandle; //!< 当前写入的记录的fileHandle

@end

@implementation ITCInfoModel

/// 指定构造方法
/// @param name 类型名
/// @param basePath 根路径
/// @param markFileName 记录的文件名
/// @param cache 是否使用缓存
/// @param validPeriod 有效期
/// @param fileCount 文件最大数量
/// @param fileSize 每个文件最大大小
+ (instancetype)modelWithName:(NSString *)name basePath:(NSString *)basePath markFileName:(NSString *)markFileName cache:(BOOL)cache validPeriod:(NSInteger)validPeriod fileCount:(NSInteger)fileCount fileSize:(NSInteger)fileSize {
    ITCInfoModel *model = [[ITCInfoModel alloc] init];
    model.name = name;
    model.path = [basePath stringByAppendingPathComponent:name];
    model.markFileName = markFileName;
    model.cache = cache;
    model.validPeriod = validPeriod;
    model.fileCount = fileCount;
    model.maxFileSize = fileSize;
    return model;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _fileManager = NSFileManager.defaultManager;
    }
    return self;
}

/// 检测记录的文件夹
- (void)checkFile {
    NSString *markPath = [_path stringByAppendingPathComponent:_markFileName];
    _mark = [NSMutableArray array];
    if ([_fileManager fileExistsAtPath:markPath]) { // 已创建则读取
        NSArray *oldDate = [NSArray arrayWithContentsOfURL:[NSURL fileURLWithPath:markPath] error:nil];
        [_mark addObjectsFromArray:oldDate];
    } else { // 创建
        // 移除整个文件夹, 防止有人删除了记录文件但是没有删除其他旧记录导致bug
        if ([_fileManager fileExistsAtPath:_path]) {
            [_fileManager removeItemAtPath:_path error:nil];
        }
        [_fileManager createDirectoryAtPath:_path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

/// 更新debug文件
- (void)updateFile {
    // 限制个数
    while (_mark.count > _fileCount) {
        NSString *fileName = [NSString stringWithFormat:@"%@.txt", _mark.firstObject[@"id"]];
        NSString *path = [_path stringByAppendingPathComponent:fileName];
        if ([_fileManager fileExistsAtPath:path]) {
            [_fileManager removeItemAtPath:path error:nil];
        }
        [_mark removeObjectAtIndex:0];
    }
    
    // 移除旧的记录
    NSTimeInterval currentTime = ITCLogCollectionManager.time;
    NSTimeInterval preTime = currentTime - _validPeriod; // 过期时间
    NSMutableArray *removeArray = [NSMutableArray array];
    for (NSDictionary *info in _mark) {
        NSTimeInterval time = [info[@"time"] doubleValue]; // 记录时间
        if (preTime >= time) { // 删除之前的数据
            NSString *fileName = [NSString stringWithFormat:@"%@.txt", info[@"id"]];
            NSString *path = [_path stringByAppendingPathComponent:fileName];
            if ([_fileManager fileExistsAtPath:path]) {
                [_fileManager removeItemAtPath:path error:nil];
            }
            [removeArray addObject:info];
        }
    }
    [_mark removeObjectsInArray:removeArray];
    
    if (_mark.count == 0) { // 如果全部给移除了, 则创建一个新的
        NSDictionary *info = @{
            @"id" : @"1",
            @"time" : @(ITCLogCollectionManager.time),
        };
        [_mark addObject:info];
    }
    NSString *markPath = [_path stringByAppendingPathComponent:_markFileName];
    [_mark writeToFile:markPath atomically:true]; // 更新记录文件
    
    NSString *fileName = [NSString stringWithFormat:@"%@.txt", _mark.lastObject[@"id"]]; // 确立写入文件名
    NSString *writePath = [_path stringByAppendingPathComponent:fileName]; // 确立写入路径
    
    if ([_fileManager fileExistsAtPath:writePath] == false) { // 还没对应的文件 -> 需要新建 -> handle需要重定向
        [@"" writeToFile:writePath atomically:true encoding:NSUTF8StringEncoding error:nil];
        _currentFileSize = 0;
        [_fileHandle closeFile];
        _fileHandle = nil;
    } else {
        _currentFileSize = [_fileManager attributesOfItemAtPath:writePath error:nil].fileSize; // 字节
    }
    
    if (_cache) { // 使用缓存
        _insertData = [NSMutableData data];
    } else {
        // 因为只有_cache为false时, _fileHandle才会被赋值, 因此其他地方只会对着nil调用方法
        NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:writePath]; // 文件处理者
        [fileHandler seekToEndOfFile]; // 跳到文件末尾
        _fileHandle = fileHandler;
    }
}

/// 插入信息
/// @param info 需要插入的信息
- (void)insertInfo:(NSString *)info {
    if (NSThread.isMainThread) {
        [self handleInfo:info];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleInfo:info];
        });
    }
}

/// 处理信息
- (void)handleInfo:(NSString *)info {
    if (_currentFileSize >= _maxFileSize) { // 超过指定大小, 更新mark和写入路径
        if (_cache) {
            [self insertInfoData];
        }
        
        NSInteger idField = [_mark.lastObject[@"id"] integerValue] + 1;
        NSDictionary *mark = @{
            @"id" : [NSString stringWithFormat:@"%@", @(idField)],
            @"time" : @(ITCLogCollectionManager.time),
        };
        [_mark addObject:mark];
        [self updateFile]; // 这里会更新 _debugWritePath
    }
    
    NSData *data = [info dataUsingEncoding:NSUTF8StringEncoding];
    _currentFileSize += data.length;
    if (_cache) {
        [_insertData appendData:data];
    } else {
        [_fileHandle writeData:data];
    }
}

/// 关闭文件通道
- (void)closeFile {
    if (_cache) { // 使用缓存
        [self insertInfoData];
    } else {
        [_fileHandle closeFile];
        _fileHandle = nil;
    }
}

/// 把insertData的数据缓存起来
- (void)insertInfoData {
    NSString *fileName = [NSString stringWithFormat:@"%@.txt", _mark.lastObject[@"id"]]; // 确立写入文件名
    NSString *writePath = [_path stringByAppendingPathComponent:fileName]; // 确立写入路径
    if ([_fileManager fileExistsAtPath:writePath]) {
        NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:writePath]; // 文件处理者
        [fileHandler seekToEndOfFile]; // 跳到文件末尾
        [fileHandler writeData:_insertData]; // 写入
        _insertData = [NSMutableData data];
        [fileHandler closeFile]; // 关闭
    }
}

@end
