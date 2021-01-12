//
//  ITCLogCollectionViewController.m
//  日志采集
//
//  Created by itc on 2020/12/10.
//

#import "ITCLogCollectionViewController.h"
#import "ITCLogCollectionManager.h"

@interface ITCLogCollectionViewController ()

@property (weak, nonatomic) IBOutlet UITextField *scopeTextField;
@property (weak, nonatomic) IBOutlet UITextField *AKTextField;
@property (weak, nonatomic) IBOutlet UITextField *SKTextField;

@property (weak, nonatomic) IBOutlet UILabel *fileSizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@property (weak, nonatomic) IBOutlet UIButton *uploadButton;
@property (weak, nonatomic) IBOutlet UIButton *cleanButton;
@property (weak, nonatomic) IBOutlet UIButton *backButton;

@property (nonatomic, strong) void(^clickBackButtonBlock)(ITCLogCollectionViewController *); // 点击返回按钮

@end

@implementation ITCLogCollectionViewController

- (instancetype)initWithClickCallBack:(void(^)(ITCLogCollectionViewController *vc))block {
    self = [super initWithNibName:[ITCLogCollectionViewController description] bundle:ITCLogCollectionManager.shareManager.logCollectionBundle];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        _clickBackButtonBlock = block;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    _fileSizeLabel.text = [NSString stringWithFormat:@"文件大小: %@", [ITCLogCollectionManager.shareManager fileSizeString:ITCLogCollectionManager.shareManager.uploadFileSize]];
    _statusLabel.text = @"状态: 等待上传";
    self.progressView.hidden = true;
}

- (IBAction)clickUploadButton:(UIButton *)sender {
    [self showButton:false];
    
    // 配置七牛云信息
    NSString *scope = _scopeTextField.text;
    NSString *accessKey = _AKTextField.text;
    NSString *secretKey = _SKTextField.text;
    [ITCLogCollectionManager.shareManager configUploadInfo:scope ak:accessKey sk:secretKey];
    
    [ITCLogCollectionManager.shareManager uploadToServer:^(ITCUploadStatus status, double progress) {
        if (status == ITCUploadStatusZip) {
            self.progressView.hidden = true;
            self.statusLabel.text = @"状态: 压缩中..";
        } else if (status == ITCUploadStatusBeginUpload) {
            self.progressView.hidden = false;
            self.progressView.progress = 0;
            self.statusLabel.text = @"状态: 开始上传..";
        } else if (status == ITCUploadStatusUploading) {
            self.progressView.progress = progress;
            self.statusLabel.text = @"状态: 上传中..";
        } else if (status == ITCUploadStatusCompletion) {
            self.progressView.hidden = true;
            self.statusLabel.text = @"状态: 上传成功";
            [self showButton:true];
        } else { // ITCUploadStatusFailure
            self.progressView.hidden = true;
            self.statusLabel.text = @"状态: 上传失败";
            [self showButton:true];
        }
    }];
}

- (IBAction)clickBackButton:(UIButton *)sender {
    if (_clickBackButtonBlock) {
        _clickBackButtonBlock(self);
    }
}

- (IBAction)clickCleanButton:(UIButton *)sender {
    [ITCLogCollectionManager.shareManager cleanInfo];
    _fileSizeLabel.text = [NSString stringWithFormat:@"文件大小: %@", [ITCLogCollectionManager.shareManager fileSizeString:ITCLogCollectionManager.shareManager.uploadFileSize]];
}

- (void)showButton:(BOOL)flag {
    _uploadButton.hidden = !flag;
    _cleanButton.hidden = !flag;
    _backButton.hidden = !flag;
}

@end
