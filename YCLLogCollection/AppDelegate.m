//
//  AppDelegate.m
//  YCLLogCollection
//
//  Created by itc on 2021/1/12.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "ITCLogCollectionManager.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    ITCLogCollectionManager *manager = ITCLogCollectionManager.shareManager;
//    [manager defaultConfigModel]; // 必须构建模型, 或使用 - (void)configModel:(NSTimeInterval)validPeriod fileCount:(NSInteger)count fileSize:(double)size cache:(BOOL)cache; 配置
    [manager configModel:24 * 60 * 60 fileCount:20 fileSize:1 << 6 cache:false];
    
    // 可选配置七牛云信息, 但在上传前必须配置
//    NSString *scope = @"infocollection";
//    NSString *accessKey = @"mBFowxvZuNg7j88ADUR3mh37S2kyRRD35zee6Am5";
//    NSString *secretKey = @"6UIbw1zXCZX3yvPxRx4CU9hMyRc0TpbeqsKmRMAT";
//    [manager configUploadInfo:scope ak:accessKey sk:secretKey];
    
    _window = ({
        UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        [window makeKeyAndVisible];
        window.rootViewController = [ViewController new];
        window;
    });
    
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{}];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [ITCLogCollectionManager.shareManager closeFile];
}

@end
