//
//  ITCLogCollectionViewController.h
//  日志采集
//
//  Created by itc on 2020/12/10.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ITCLogCollectionViewController : UIViewController

/// 指定构造方法
/// @param block 点击返回的回调
- (instancetype)initWithClickCallBack:(void(^)(ITCLogCollectionViewController *vc))block;

@end

NS_ASSUME_NONNULL_END
