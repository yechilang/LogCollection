//
//  ITCInfoModel.h
//  日志采集
//
//  Created by itc on 2021/1/4.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ITCInfoModel : NSObject

/// 检测记录的文件夹
- (void)checkFile;

/// 更新debug文件
- (void)updateFile;

/// 插入信息
/// @param info 需要插入的信息
- (void)insertInfo:(NSString *)info;

/// 关闭文件通道
- (void)closeFile;

/// 指定构造方法
/// @param name 类型名
/// @param basePath 根路径
/// @param markFileName 记录的文件名
/// @param cache 是否使用缓存
/// @param validPeriod 有效期
/// @param fileCount 文件最大数量
/// @param fileSize 每个文件最大大小
+ (instancetype)modelWithName:(NSString *)name basePath:(NSString *)basePath markFileName:(NSString *)markFileName cache:(BOOL)cache validPeriod:(NSInteger)validPeriod fileCount:(NSInteger)fileCount fileSize:(NSInteger)fileSize;

@end

NS_ASSUME_NONNULL_END
