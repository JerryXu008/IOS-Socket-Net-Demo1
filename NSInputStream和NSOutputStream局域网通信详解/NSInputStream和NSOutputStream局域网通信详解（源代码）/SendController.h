/*
    File:       SendController.h

    Contains:   Manages the Send tab.

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

enum {
    kSendBufferSize = 32768
};

@interface SendController : UIViewController
{
    UILabel *                   _statusLabel; //状态标签
    UIActivityIndicatorView *   _activityIndicator;//加载视图
    UIButton *                  _stopButton; //停止按钮
    
    NSNetService *              _netService;//初始化ReceiveServerController发布的服务
    NSOutputStream *            _networkStream;//与服务连接的输出流
    NSInputStream *             _fileStream;//与图片连接的输入流
    uint8_t                     _buffer[kSendBufferSize]; //缓冲数组，从fileStream读数据到该数组中，然后再从该数组中取数据写入到networkStream
    size_t                      _bufferOffset;   //在32位系统中size_t是4字节的，而在64位系统中，size_t是8字节的，缓冲区偏移量
    size_t                      _bufferLimit; //缓冲区大小
}

@property (nonatomic, retain) IBOutlet UILabel *                   statusLabel;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *   activityIndicator;
@property (nonatomic, retain) IBOutlet UIButton *                  cancelButton;

- (IBAction)sendAction:(UIView *)sender;//发送方法
- (IBAction)cancelAction:(id)sender;//取消方法

@end
