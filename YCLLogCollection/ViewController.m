//
//  ViewController.m
//  YCLLogCollection
//
//  Created by itc on 2021/1/12.
//

#import "ViewController.h"
#import "ITCLogCollectionManager.h"
#import "ITCLogCollectionViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    CGPoint center = self.view.center;
    
    UIButton *button = ({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.backgroundColor = [UIColor blueColor];
        button.layer.cornerRadius = 5;
        button.clipsToBounds = true;
        [button setTitle:@"点击跳转到上传界面" forState:UIControlStateNormal];
        button.titleLabel.textColor = [UIColor blackColor];
        button.titleLabel.font = [UIFont systemFontOfSize:15];
        [button addTarget:self action:@selector(clickButton:) forControlEvents:UIControlEventTouchUpInside];
        button;
    });
    [self.view addSubview:button];
    button.frame = CGRectMake(0, 0, 300, 44);
    button.center = CGPointMake(center.x, center.y - 50);
    
    UIButton *insertButton = ({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.backgroundColor = [UIColor blueColor];
        button.layer.cornerRadius = 5;
        button.clipsToBounds = true;
        [button setTitle:@"点击插入信息" forState:UIControlStateNormal];
        button.titleLabel.textColor = [UIColor blackColor];
        button.titleLabel.font = [UIFont systemFontOfSize:15];
        [button addTarget:self action:@selector(clickInsertButton:) forControlEvents:UIControlEventTouchUpInside];
        button;
    });
    [self.view addSubview:insertButton];
    insertButton.frame = CGRectMake(0, 0, 300, 44);
    insertButton.center = CGPointMake(center.x, center.y + 50);
}

- (void)clickButton:(UIButton *)button {
    ITCLogCollectionViewController *vc = [[ITCLogCollectionViewController alloc] initWithClickCallBack:^(ITCLogCollectionViewController * _Nonnull vc) {
        [vc dismissViewControllerAnimated:true completion:nil];
    }];
    [self presentViewController:vc animated:true completion:nil];
}

- (void)clickInsertButton:(UIButton *)button {
    [ITCLogCollectionManager.shareManager insertDebugInfo:@"插入debug信息\n\n"];
    [ITCLogCollectionManager.shareManager insertNetworkInfo:@"插入network信息\n\n"];
    [ITCLogCollectionManager.shareManager insertDeviceInfo:@"插入device信息\n\n"];
}

//- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    NSArray *array = @[@(1)];
//    array[2];
//}

@end
