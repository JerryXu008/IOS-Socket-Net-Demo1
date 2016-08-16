/*
    File:       ReceiveServerController.m

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

#import "ReceiveServerController.h"

#import "AppDelegate.h"

#include <CFNetwork/CFNetwork.h>

#include <sys/socket.h>
#include <netinet/in.h>

@interface ReceiveServerController ()

// Properties that don't need to be seen by the outside world.

@property (nonatomic, readonly) BOOL                isStarted; //是否服务已经启动
@property (nonatomic, readonly) BOOL                isReceiving; //是否正在接收
@property (nonatomic, retain)   NSNetService *      netService;
@property (nonatomic, assign)   CFSocketRef         listeningSocket;
@property (nonatomic, retain)   NSInputStream *     networkStream;
@property (nonatomic, retain)   NSOutputStream *    fileStream;
@property (nonatomic, copy)     NSString *          filePath;

// Forward declarations

- (void)_stopServer:(NSString *)reason;

@end

@implementation ReceiveServerController

#pragma mark * Status management

// These methods are used by the core transfer code to update the UI.
//显示端口
- (void)_serverDidStartOnPort:(int)port
{
    assert( (port > 0) && (port < 65536) );
    self.statusLabel.text = [NSString stringWithFormat:@"Started on port %d", port];
    [self.startOrStopButton setTitle:@"Stop" forState:UIControlStateNormal];
    self.tabBarItem.image = [UIImage imageNamed:@"receiveserverOn.png"];
}

- (void)_serverDidStopWithReason:(NSString *)reason
{
    if (reason == nil) {
        reason = @"Stopped";
    }
    self.statusLabel.text = reason;
    [self.startOrStopButton setTitle:@"Start" forState:UIControlStateNormal];
    self.tabBarItem.image = [UIImage imageNamed:@"receiveserverOff.png"];
}

- (void)_receiveDidStart
{
    self.statusLabel.text = @"Receiving";
    self.imageView.image = [UIImage imageNamed:@"NoImage.png"];
    [self.activityIndicator startAnimating];
    [[AppDelegate sharedAppDelegate] didStartNetworking];
}

- (void)_updateStatus:(NSString *)statusString
{
    assert(statusString != nil);
    self.statusLabel.text = statusString;
}

- (void)_receiveDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        assert(self.filePath != nil);
        self.imageView.image = [UIImage imageWithContentsOfFile:self.filePath]; //加载图片
        statusString = @"Receive succeeded";
    }
    self.statusLabel.text = statusString;
    [self.activityIndicator stopAnimating];
    [[AppDelegate sharedAppDelegate] didStopNetworking];
}

#pragma mark * Core transfer code

// This is the code that actually does the networking.

@synthesize netService      = _netService;
@synthesize networkStream   = _networkStream;
@synthesize listeningSocket = _listeningSocket;
@synthesize fileStream      = _fileStream;
@synthesize filePath        = _filePath;

- (BOOL)isStarted //服务不为null就是启动了
{
    return (self.netService != nil);
}

- (BOOL)isReceiving //输入流不为空就是正在接收
{
    return (self.networkStream != nil);
}

// Have to write our own setter for listeningSocket because CF gets grumpy 
// if you message NULL.
//实现自己的socketset方法，具体原因我也不知道，不过可以参考和模仿
- (void)setListeningSocket:(CFSocketRef)newValue
{
    if (newValue != self->_listeningSocket) {
        if (self->_listeningSocket != NULL) {
            CFRelease(self->_listeningSocket);
        }
        self->_listeningSocket = newValue;
        if (self->_listeningSocket != NULL) {
            CFRetain(self->_listeningSocket);
        }
    }
}
//这个方法是在acceptConnection里面调用的，参数是socket 。根据参数，正式取得连接过来的数据信息
- (void)_startReceive:(int)fd
{
    CFReadStreamRef     readStream;
    
    assert(fd >= 0);

    assert(self.networkStream == nil);      // can't already be receiving
    assert(self.fileStream == nil);         // ditto
    assert(self.filePath == nil);           // ditto

    // Open a stream for the file we're going to receive into.
    //得到一个需要生成的新图像的路径，这个方法之后在AppController.cs中会说
    self.filePath = [[AppDelegate sharedAppDelegate] pathForTemporaryFileWithPrefix:@"Receive"];
    assert(self.filePath != nil);
   //关联这个路径的输出流，用这个流往里面写东西
    self.fileStream = [NSOutputStream outputStreamToFileAtPath:self.filePath append:NO];
    assert(self.fileStream != nil);
    //打开流
    [self.fileStream open];

    // Open a stream based on the existing socket file descriptor.  Then configure 
    // the stream for async operation.
  //打开一个现有socket的流，之后进行异步操作
//参数一：内存分配器（苹果管理优化内存的一种措施，更多信息可网上查询）
 //参数二：就是想用我们第三和第四个参数代表的输入输出流的socket 参数三，参数四：绑定到第二个参数表示的socket的输入输出流的地址
    CFStreamCreatePairWithSocket(NULL, fd, &readStream, NULL);
   //如果我们的CFStreamCreatePairWithSocket()方法操作成功的话，那么我们现在的writeStream应该指向有效的地址，而不是我们在刚申请时赋给的NULL了
    assert(readStream != NULL);
    //保存输入流
    self.networkStream = (NSInputStream *) readStream;
    
    CFRelease(readStream);
 //如果我们的流释放的话，我们这个流绑定的socket也要释放,实现同样效果的方法是   CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue); 详细请看ios简单局域网通信
    [self.networkStream setProperty:(id)kCFBooleanTrue forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket];
  //设置委托为本类
    self.networkStream.delegate = self;
 //加入到运行循环
    [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    //打开流
    [self.networkStream open];

    // Tell the UI we're receiving.
    
    [self _receiveDidStart];
}
//停止接收
- (void)_stopReceiveWithStatus:(NSString *)statusString
{    //关闭输入流
    if (self.networkStream != nil) {
        self.networkStream.delegate = nil;
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.networkStream close];
        self.networkStream = nil;
    }
   //关闭输出流
    if (self.fileStream != nil) {
        [self.fileStream close];
        self.fileStream = nil;
    }
    [self _receiveDidStopWithStatus:statusString];
    self.filePath = nil;
}
//流状态改变之后的回调函数调用
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
    // An NSStream delegate callback that's called when events happen on our 
    // network stream.
{
    #pragma unused(aStream)
    assert(aStream == self.networkStream);

    switch (eventCode) {
        case NSStreamEventOpenCompleted: {   //看看这个open方法和AcceptCallback谁先执行，当然是AcceptCallback先执行，执行之后才得到socket的输出流，然后加入运行循环，然后才有这个方法
            [self _updateStatus:@"Opened connection"];
        } break;
        case NSStreamEventHasBytesAvailable: {
            NSInteger       bytesRead;
            uint8_t         buffer[32768];

            [self _updateStatus:@"Receiving"];

            // Pull some data off the network.
            //读取的时候maxLength的值要小于等于buffer分配时候的容量
            bytesRead = [self.networkStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead == -1) {
                [self _stopReceiveWithStatus:@"Network read error"];
            } else if (bytesRead == 0) { //从输入流中去不读完了就走这个
                [self _stopReceiveWithStatus:nil];
            } else {
                NSInteger   bytesWritten;
                NSInteger   bytesWrittenSoFar;

                // Write to the file.
                
                bytesWrittenSoFar = 0;
                do {
                    bytesWritten = [self.fileStream write:&buffer[bytesWrittenSoFar] maxLength:bytesRead - bytesWrittenSoFar];
                    assert(bytesWritten != 0);
                    if (bytesWritten == -1) {
                        [self _stopReceiveWithStatus:@"File write error"]; //错误的话直接跳出
                        break;
                    } else {
                        bytesWrittenSoFar += bytesWritten;
                    }
                } while (bytesWrittenSoFar != bytesRead);
            }
        } break;
        case NSStreamEventHasSpaceAvailable: {
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventErrorOccurred: {
            [self _stopReceiveWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
        } break;
        default: {
            assert(NO);
        } break;
    }
}
//这个方法是在scoket的回调函数里面调用的，参数就是socket
- (void)_acceptConnection:(int)fd
{
    int     junk;

    // If we already have a connection, reject this new one.  This is one the 
    // big simplifying assumptions in this code.  A real server should handle 
    // multiple simultaneous connections.

    if ( self.isReceiving ) {
        junk = close(fd);
        assert(junk == 0);
    } else {
        [self _startReceive:fd];
    }
}
//收到连接请求之后，走的回调方法  在这个例子中是SendController的 [self.networkStream open];调用之后调用的，通过打开服务的流，表示已经连接好啦，或者也可以是发送数据过来之后在调用，不受影响（测试得到）
////参数类型： 参数一：触发了这个回调的socket本身  参数二：触发这个回调的事件类型  参数三：请求连接的远端设备的地址  参数四：它根据回调事件的不同，它代表的东西也不同，如果这个是连接失败回调事件，那它就代表一个错误代码的指针，
//如果是连接成功的回调事件，它就是一个Socket指针，如果是数据回调事件，这就是包含这些数据的指针，其它情况下它是NULL的 参数五：创建socket的时候用的那个CFSocketContext结构的info成员
static void AcceptCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
    // Called by CFSocket when someone connects to our listening socket.  
    // This implementation just bounces the request up to Objective-C.
{
    ReceiveServerController *  obj;
    
    #pragma unused(type)
    assert(type == kCFSocketAcceptCallBack); //测试是这个类型的回调函数
    #pragma unused(address)
    // assert(address == NULL);
    assert(data != NULL);
    
    obj = (ReceiveServerController *) info; //类本身
    assert(obj != nil);

    #pragma unused(s)
   //s为回调的socket本身
    assert(s == obj->_listeningSocket); //这个创建的端口
    
    [obj _acceptConnection:*(int *)data];  //成功回调的话就是一个socket指针，先转换成int* socket指针，然后去的其中的内容，代表这个socket
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
    // A NSNetService delegate callback that's called if our Bonjour registration 
    // fails.  We respond by shutting down the server.
    //
    // This is another of the big simplifying assumptions in this sample. 
    // A real server would use the real name of the device for registrations, 
    // and handle automatically renaming the service on conflicts.  A real 
    // client would allow the user to browse for services.  To simplify things 
    // we just hard-wire the service name in the client and, in the server, fail 
    // if there's a service name conflict.
{
    #pragma unused(sender)
    assert(sender == self.netService);
    #pragma unused(errorDict)
    
    [self _stopServer:@"Registration failed"];
}
//这是点击按钮后的第二个要走的方法，正式启动服务
- (void)_startServer
{
    BOOL        success;
    int         err; //错误的引用
    int         fd; //socket的引用
    int         junk;
    struct sockaddr_in addr;//地址结构体
    int         port; //端口
    
    // Create a listening socket and use CFSocket to integrate it into our 
    // runloop.  We bind to port 0, which causes the kernel to give us 
    // any free port, then use getsockname to find out what port number we 
    // actually got.

    port = 0; //端口设置为0 ，可以使内核分配给我们任意端口，能用就行
    //POSIX调用，这个方法将建立一个新的socket来完成网络通信 。参数一：AF_INET指出这要作为一个IPv4 socket而不是IPv6等 参数二：SOCK_STREAM指我们使用TCP协议，而SOCK_DGRAM表示用UDP协议
   //参数三：通常是IPPRPTO_UDP,0表示内核 会选择UDP协议
  fd = socket(AF_INET, SOCK_STREAM, 0);
    success = (fd != -1);
    
    if (success) { //如果创建成功，开始创建地址
      //清空分配的地址
        memset(&addr, 0, sizeof(addr));
        //地址长度
       addr.sin_len    = sizeof(addr);
        addr.sin_family = AF_INET;//地址协议 IPv4
        addr.sin_port   = 0; //端口号  一般是这么写htons(0) 那主机字节序转换成网络字节序 sin_port采用的是网络字节序
        addr.sin_addr.s_addr = INADDR_ANY; //任意地址，具体可以参照IOS局域网通信的案例
        err = bind(fd, (const struct sockaddr *) &addr, sizeof(addr));  //具体吧socket绑定到一个端口
        success = (err == 0);
    }
    if (success) {
        err = listen(fd, 5);  //当有多个客户端程序和服务端相连时,表示可以接受的排队长度(网上说的)
        success = (err == 0);
    }
    if (success) {
        socklen_t   addrLen;

        addrLen = sizeof(addr);
       //通过这个方法我们可以知道所监听的端口，因为之前设置的时候是任意端口
        err = getsockname(fd, (struct sockaddr *) &addr, &addrLen);
        success = (err == 0);
        
        if (success) {
            assert(addrLen == sizeof(addr));
            port = ntohs(addr.sin_port); //把网络字节序转换成主机字节序
        }
    }
    if (success) {
   //定义了一个CFSocketContext结构类型变量socketCtxt，并对这个结构进行初始化
     //该结构体有5个成员，第一个成员是这个结构的版本号，这个必需是0；第二个成员可以是一个你程序内定义的任何数据的指针，这里我们传入的是self，就是这们这个类本身了，
    //所以我们的TCPServerAcceptCallBack这个回调方法可以把它在转换回来，
    //并且这个参数会被传入在这个结构内定义的所有回调函数；第三、四、五这三个成员其实就是3个回调函数的指针，一般我们都设为NULL,就是不用它们。
        CFSocketContext context = { 0, self, NULL, NULL, NULL }; //
        //暂时不知道什么意思。只知道当请求方发送连接过来的时候，会调用回调函数kCFSocketAcceptCallBack
        self.listeningSocket = CFSocketCreateWithNative(
            NULL, 
            fd, 
            kCFSocketAcceptCallBack, 
            AcceptCallback, 
            &context
        );
        success = (self.listeningSocket != NULL);
        
        if (success) {
            CFRunLoopSourceRef  rls;
            
            CFRelease(self.listeningSocket);        // to balance the create

            fd = -1;        // listeningSocket is now responsible for closing fd
              //创建了一个RunLoop的输入源变量source    CFSocketCreateRunLoopSource有三个参数  参数一：内存分配器  参数二：我们想要做为输入源来监听的socket对象 参数三：代表在RunLoop中处理这些输入源事件时的优先级，数小的话优先级高

            rls = CFSocketCreateRunLoopSource(NULL, self.listeningSocket, 0);
            assert(rls != NULL);
            //把端口加入到运行循环
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
               //加入了输入源之后RunLoop就自动保持了这个输入源，我们现在就可以释放这个输入源了

            CFRelease(rls);
        }
    }

    // Now register our service with Bonjour.  See the comments in -netService:didNotPublish: 
    // for more info about this simplifying assumption.

    if (success) { //成功开始创造服务，服务的名字等都要和客户端SendCOntroller一致，这样sendcontroller才能正确的连接
        self.netService = [[[NSNetService alloc] initWithDomain:@"local." type:@"_x-SNSUpload._tcp." name:@"Test" port:port] autorelease];
        success = (self.netService != nil);
    }
    if (success) {
       //设置委托，这里用于netService:didNotPublish: 发布失败后的调用
        self.netService.delegate = self;
        //正式发布出去 参数二：指定网络服务不重命的冲突（苹果官方文档）
        [self.netService publishWithOptions:NSNetServiceNoAutoRename];
        
        // continues in -netServiceDidPublish: or -netService:didNotPublish: ...
    }
    
    // Clean up after failure.
    
    if ( success ) {
        assert(port != 0);
        [self _serverDidStartOnPort:port]; //显示端口号
    } else {
        [self _stopServer:@"Start failed"];
        if (fd != -1) {
            junk = close(fd);  //关闭端口
            assert(junk == 0);
        }
    }
}
//停止服务，看看停止服务需要做哪一些事情
- (void)_stopServer:(NSString *)reason
{
    if (self.isReceiving) { //正在接收的话，先停止接收，在这个方法里面也是做了不少东西，主要是关闭输入流和输出流
        [self _stopReceiveWithStatus:@"Cancelled"];
    }
    if (self.netService != nil) { //停止当前的服务
        [self.netService stop];
        self.netService = nil;
    }
    if (self.listeningSocket != NULL) { //把当前的端口设为无效，赋予null
        CFSocketInvalidate(self.listeningSocket);
        self.listeningSocket = NULL;
    }
    [self _serverDidStopWithReason:reason]; //更新UI接口
}


#pragma mark * Actions
//这是起始方法，点击按钮之后进行的逻辑，从这里开始看起
- (IBAction)startOrStopAction:(id)sender
{
    #pragma unused(sender)
    if (self.isStarted) {
        [self _stopServer:nil];
    } else {
        [self _startServer];
    }
}

#pragma mark * View controller boilerplate

@synthesize imageView         = _imageView;
@synthesize statusLabel       = _statusLabel;
@synthesize activityIndicator = _activityIndicator;
@synthesize startOrStopButton = _startOrStopButton;

- (void)dealloc
{
    [self _stopServer:nil];
    
    [self->_imageView release];
    self->_imageView = nil;
    [self->_statusLabel release];
    self->_statusLabel = nil;
    [self->_activityIndicator release];
    self->_activityIndicator = nil;
    [self->_startOrStopButton release];
    self->_startOrStopButton = nil;

    [super dealloc];
}

- (void)setView:(UIView *)newValue
{
    if (newValue == nil) {
        self.imageView = nil;
        self.statusLabel = nil;
        self.activityIndicator = nil;
        self.startOrStopButton = nil;
    }
    [super setView:newValue];
}
//第一个方法，不解释
- (void)viewDidLoad
{
    [super viewDidLoad];
    assert(self.imageView != nil);
    assert(self.statusLabel != nil);
    assert(self.activityIndicator != nil);
    assert(self.startOrStopButton != nil);
    
    self.activityIndicator.hidden = YES;
    self.statusLabel.text = @"Tap Start to start the server";
}

@end
