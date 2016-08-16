/*
    File:       ReceiveServerController.h

    Contains:   Manages the receive server tab.

    Written by: DTS

    Copyright:  Copyright (c) 2009 Apple Inc. All Rights Reserved.

    Disclaimer: IMPORTANT: This Apple software is supplied to you by Apple Inc.
                ("Apple") in consideration of your agreement to the following
                terms, and your use, installation, modification or
                redistribution of this Apple software constitutes acceptance of
                these terms.  If you do not agree with these terms, please do
                not use, install, modify or redistribute this Apple software.

                In consideration of your agreement to abide by the following
                terms, and subject to these terms, Apple grants you a personal,
                non-exclusive license, under Apple's copyrights in this
                original Apple software (the "Apple Software"), to use,
                reproduce, modify and redistribute the Apple Software, with or
                without modifications, in source and/or binary forms; provided
                that if you redistribute the Apple Software in its entirety and
                without modifications, you must retain this notice and the
                following text and disclaimers in all such redistributions of
                the Apple Software. Neither the name, trademarks, service marks
                or logos of Apple Inc. may be used to endorse or promote
                products derived from the Apple Software without specific prior
                written permission from Apple.  Except as expressly stated in
                this notice, no other rights or licenses, express or implied,
                are granted by Apple herein, including but not limited to any
                patent rights that may be infringed by your derivative works or
                by other works in which the Apple Software may be incorporated.

                The Apple Software is provided by Apple on an "AS IS" basis. 
                APPLE MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
                WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
                MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING
                THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
                COMBINATION WITH YOUR PRODUCTS.

                IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT,
                INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
                TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
                DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY
                OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
                OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY
                OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
                OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF
                SUCH DAMAGE.

*/

#import <UIKit/UIKit.h>

@interface ReceiveServerController : UIViewController
{
    UIImageView *               _imageView; //承载远程加载过来的图片
    UILabel *                   _statusLabel; //状态标签
    UIActivityIndicatorView *   _activityIndicator;//加载视图
    UIButton *                  _startOrStopButton;//开始或者停止按钮
    
    NSNetService *              _netService;//需要发布的服务
    CFSocketRef                 _listeningSocket;//监听的socket
    
    NSInputStream *             _networkStream; //远程输入流（我是这样叫的，不知道对不对）
    NSOutputStream *            _fileStream; //本地输出流
    NSString *                  _filePath; //图片路径
}

@property (nonatomic, retain) IBOutlet UIImageView *               imageView;
@property (nonatomic, retain) IBOutlet UILabel *                   statusLabel;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *   activityIndicator;
@property (nonatomic, retain) IBOutlet UIButton *                  startOrStopButton;

- (IBAction)startOrStopAction:(id)sender;

@end
