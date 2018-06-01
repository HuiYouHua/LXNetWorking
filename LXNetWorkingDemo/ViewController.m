//
//  ViewController.m
//  LXNetWorkingDemo
//
//  Created by 华惠友 on 2018/3/19.
//  Copyright © 2018年 华惠友. All rights reserved.
//

#import "ViewController.h"

#import <LXNetWorkingSDK/LXNetWorkingSDK.h>
#define WeakSelf(type)  __weak typeof(type) weak##type = type;

static NSString *const downloadUrl = @"http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4";
//static NSString *const dataUrl = @"http://www.qinto.com/wap/index.php?ctl=article_cate&act=api_app_getarticle_cate&num=1&p=7";
static NSString *const dataUrl = @"http://vapi.yuike.com/1.0/product/quality.php?count=40&cursor=%@&mid=457465&sid=390d40f54ae019be401cb925242ec027&type=choice&yk_appid=1&yk_cbv=2.9.3.1&yk_pid=1&yk_user_id=5135288";
static NSString *const localUrl = @"http://localhost:8080/web2/demo1.java";


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *textView;

@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (nonatomic, strong) LXSocketManager *manager;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView;


@property (nonatomic, strong) LXURLSessionTask *task;
/** 是否开始下载*/
@property (nonatomic, assign, getter=isDownload) BOOL download;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _manager = [LXSocketManager shareInstance];
    _manager.urlString = @"ws://echo.websocket.org";
//    _manager.urlString = @"ws://m2.hijoy.org/platform/websocket/socketServer.do";
    _manager.heartTime = 10.0f;
    WeakSelf(self)
    _manager.didReceiveMessage = ^(id message) {
        weakself.textView.text = [NSString stringWithFormat:@"%@服务器对客户端说:   %@\r\n",weakself.textView.text, message];
    };

    _manager.socketStateBlock = ^(LXSRSocketState socketState) {
        NSLog(@"状态%ld",(long)socketState);
    };
    
//    [LXNetworkHelper startMonitoringNetwork];
//    //检查网络状态
//    [LXNetworkHelper checkNetworkStatusWithBlock:^(LXNetworkStatus status) {
//        switch (status) {
//            case LXNetworkStatusUnknown:
//            case LXNetworkStatusNotReachable: {
//
//                NSLog(@"无网络");
//                break;
//            }
//            case LXNetworkStatusReachableViaWWAN:
//            case LXNetworkStatusReachableViaWiFi: {
//                NSLog(@"有网络,请求网络数据");
//                break;
//            }
//        }
//    }];

}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.textField endEditing:YES];
}

- (IBAction)connect:(id)sender {
    [_manager connect];
}

- (IBAction)disconnect:(id)sender {
    [_manager close];
}

- (IBAction)sendBtn:(id)sender {
    NSString *str = self.textField.text;
    [_manager sendData:str];
    self.textView.text = [NSString stringWithFormat:@"%@客户端对服务器说:  %@\r\n",self.textView.text, str];
}

- (IBAction)add:(id)sender {
    [_manager networkReachabilityStartMonitoring];
}

- (IBAction)cancel:(id)sender {
    [_manager networkReachabilityStopMonitoring];
}

// post
- (IBAction)post:(id)sender {
}

// get
- (IBAction)get:(id)sender {
    NSString *url = [NSString stringWithFormat:dataUrl, @(0)];
    [LXNetworkHelper lx_requestWithType:0 withSubMethod:localUrl withParameters:nil showHUD:YES withSuccessBlock:^(id response) {
        NSLog(@"%@",response);
////        self.textView.text = response;
//        self.textView.text = [self jsonToString:response];
    } withFailureBlock:^(NSError *error) {
        NSLog(@"error = %@",error);
    }];
}

// 单个上传
- (IBAction)upload:(id)sender {
}

// 多上传
- (IBAction)uploads:(id)sender {
}

// 下载
- (IBAction)download:(id)sender {

        _task = [LXNetworkHelper lx_downloadWithURL:downloadUrl fileDir:@"myLoad" progress:^(NSProgress *progress) {
            CGFloat stauts = 100.f * progress.completedUnitCount/progress.totalUnitCount;
            
            //在主线程更新UI
            dispatch_async(dispatch_get_main_queue(), ^{
                self.progressView.progress = stauts/100.f;
            });
            
            NSLog(@"下载进度 :%.2f%%,,%@",stauts,[NSThread currentThread]);
        } success:^(id response) {
            NSLog(@"下载成功filePath = %@",response);
        } failure:^(NSError *error) {
            NSLog(@"error = %@",error);
        }];

}

// 取消下载
- (IBAction)cancelDownload:(id)sender {
    self.progressView.progress = 0;
    [LXNetworkHelper cancelCurrentRequest:downloadUrl];
}

// 取消所有网络请求
- (IBAction)cancelAllNet:(id)sender {
    [LXNetworkHelper cancelAllRequset];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 *  json转字符串
 */
- (NSString *)jsonToString:(NSDictionary *)dic
{
    if(!dic){
        return nil;
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}


@end
