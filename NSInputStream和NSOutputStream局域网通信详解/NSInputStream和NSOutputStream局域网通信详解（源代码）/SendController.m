/*
    File:       SendController.m

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

#import "SendController.h"

#import "AppDelegate.h"

@interface SendController ()

// Properties that don't need to be seen by the outside world.
//为一些私有的变量定义属性，不需要对外公开
@property (nonatomic, readonly) BOOL              isSending;//是否正在发送
@property (nonatomic, retain)   NSNetService *    netService;
@property (nonatomic, retain)   NSOutputStream *  networkStream;
@property (nonatomic, retain)   NSInputStream *   fileStream;
@property (nonatomic, readonly) uint8_t *         buffer;     //  uint8_t   _buffer[kSendBufferSize]; 定义的时候是数组，定义属性的时候是  uint8_t *    buffer，记住这种用法，另外buffer定义的时候是个数组，所以要自己写get函数，返回的是数组首地址，下面会有介绍
@property (nonatomic, assign)   size_t            bufferOffset;
@property (nonatomic, assign)   size_t            bufferLimit;

@end

@implementation SendController

#pragma mark * Status management

// These methods are used by the core transfer code to update the UI.
//然后根据目前的情况更新用户界面
- (void)_sendDidStart
{
    self.statusLabel.text = @"Sending";
    self.cancelButton.enabled = YES;
    [self.activityIndicator startAnimating];
    [[AppDelegate sharedAppDelegate] didStartNetworking];
}
//更新状态标签
- (void)_updateStatus:(NSString *)statusString
{
    assert(statusString != nil);
    self.statusLabel.text = statusString;
}

- (void)_sendDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        statusString = @"Send succeeded";
    }
    self.statusLabel.text = statusString;
    self.cancelButton.enabled = NO;
    [self.activityIndicator stopAnimating];
    [[AppDelegate sharedAppDelegate] didStopNetworking];
}

#pragma mark * Core transfer code

// This is the code that actually does the networking.

@synthesize netService    = _netService;
@synthesize networkStream = _networkStream;
@synthesize fileStream    = _fileStream;
@synthesize bufferOffset  = _bufferOffset;
@synthesize bufferLimit   = _bufferLimit;

// Because buffer is declared as an array, you have to use a custom getter.  
// A synthesised getter doesn't compile.
//数组buffer的get函数，返回数组的首地址
- (uint8_t *)buffer
{
    return self->_buffer;
}
//是否正在发送，如果输出流不为空，那么就是正在发送
- (BOOL)isSending
{
    return (self.networkStream != nil);
}
//根据图片的路径把图片发送到服务端
- (void)_startSend:(NSString *)filePath
{
    NSOutputStream *    output;//输出流，关联服务端的服务
    BOOL                success;
    
    assert(filePath != nil);
    
    assert(self.networkStream == nil);      // don't tap send twice in a row!
    assert(self.fileStream == nil);         // ditto

    // Open a stream for the file we're going to send.
    //创建并返回一个初始化NSInputStream对象,在一个给定的路径中从文件读取数据
    self.fileStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    assert(self.fileStream != nil);
    //打开输入流
    [self.fileStream open];
    
    // Open a stream to the server, finding the server via Bonjour.  Then configure 
    // the stream for async operation.
    //初始化服务
   //在这里我要区分一下initWithDomain:type:name:port:和nitWithDomain:type:name:这两个函数的区别，后者多了一个参数
   //先解释第一个： 
    //这个函数的作用：返回接收机,初始化一个给定的类型的网络服务的并设置设置初始主机信息。
   //参数一：定义服务的作用域。本地域用local，
  //参数二：网络服务类型：
  //参数三：需要解析的服务的名字
 //说明：这个函数是对一个要解析的服务的初始化，如果你是想在本机发布一个服务，那么请用 initWithDomain:type:name:port:.这个函数
//如果你知道了要连接的这个服务的作用域，类型，名字，那么你就使用这个函数来初始化一个NSNetService，并用resolveWithTimeout: on the result.来解析他
//但是你不能使用这个初始化器发布一个服务。这个初始化器传递了无效的端口号来指定的初始化程序,他会导致服务注册被阻止。
 
   //再解释initWithDomain:type:name:port:
   //这个函数的作用：初始化一个接收器为一个服务，并且这个服务已经被套接字通过作用域，类型，名字详细说明了
   //参数一：定义服务的作用域。本地域用local，一般是首选使用NSNetServiceBrowser对象获得当地注册域来发布您的服务。使用这个默认域,只需传递一个空字符串(@ " ")。
//参数二：网络服务类型：
//参数三：通过这个name来识别这个服务，如果是'',那么系统会使用计算机名称作为服务名称来发布。
//参数四：服务在这个端口中发布，这个端口必须是端口必须是从应用程序中获得的。
//说明：你用这个方法来创建一个服务,并发布在网络上。虽然你也可以用这种方法来创建一个你想要解析的服务,但这时一般会用initWithDomain:类型:名称:这个方法来代替。
//当发布一个服务,你必须提供有效的参数,以便正确地为您的服务做广告。如果主机访问多个注册域名,您必须创建单独的对象NSNetService为每个域。如果你试图发布在一个领域,你没有登记机关,你的请求可以被拒绝。
//这是可接受的使用空字符串域参数在发布或浏览一个服务,但不依赖这个决议。
//这个方法是指定的初始化程序。
   //初始化一个NSNetService，前提是知道了服务端要发布的服务的域，类型，名字，这样服务端发送后，输出流在运行循环中会检测到
    self.netService = [[[NSNetService alloc] initWithDomain:@"local." type:@"_x-SNSUpload._tcp." name:@"Test"] autorelease];
    assert(self.netService != nil);
//通过引用获取接收者输入和输出流   并返回一个布尔值表明他们是否被成功的检索到。 需要知道这个服务是服务方发送过来的，所以在服务方没有发送服务的时候，也会返回yes，但是在[self.networkStream open]的时候会调用
//- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode,但这个时候会走错误的逻辑，也就是  case NSStreamEventErrorOccurred:流打开失败
   success = [self.netService getInputStream:NULL outputStream:&output];
    assert(success);
    
    self.networkStream = output; //引用输出流
    
    // -[NSNetService getInputStream:outputStream:] currently returns the stream 
    // with a reference that we have to release (something that's counter to the 
    // standard Cocoa memory management rules <rdar://problem/6868813>).
    //-[NSNetService getInputStream:outputStream:]目前返回流
    //一个引用,我们必须释放

    [output release];
    //设置本类为委托
    self.networkStream.delegate = self;
  //加入到运行循环中 ,这样流的发生事件才会调用
    [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    //打开输出流
//打开这个流之后，说明两个就连接了，此时会调用- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode的打开成功逻辑
//也有可能接着调用 case NSStreamEventHasSpaceAvailable，或者调用Receiveservercontrller里socket的回调方法（这个方法是在连接请求的时候调用，通过这个方法，可以获得新的socekt的输入输出流，通过这个两个流可以控制sendcontrooler的读写）
    [self.networkStream open]; 
    
    // Tell the UI we're sending.
    //回馈UI，比较简单
    [self _sendDidStart];
}
//停止发送，并且销毁相关的流（好好看看停止需要执行什么操作）
- (void)_stopSendWithStatus:(NSString *)statusString
{
    if (self.networkStream != nil) {
        self.networkStream.delegate = nil; //把输出流的委托设为nil
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];//移除运行循环
        [self.networkStream close];//输出流关闭
        self.networkStream = nil;//赋予nil，这样不管怎么销毁都不会报错
    }
    if (self.netService != nil) {
        [self.netService stop]; //停止这个服务
        self.netService = nil;
    }
    if (self.fileStream != nil) {
        [self.fileStream close]; //本地输入流关闭
        self.fileStream = nil;
    }
 //偏移量和最大值都设置为0
    self.bufferOffset = 0;
    self.bufferLimit  = 0;
//反馈用户界面
    [self _sendDidStopWithStatus:statusString];
}
//委托方接收这个消息只有theStream被安排在一个运行循环。消息被发送到流对象的线程。streamEvent代表应该检查以确定适当的行动应该采取。

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
    // An NSStream delegate callback that's called when events happen on our 
    // network stream.
{
    #pragma unused(aStream)
    assert(aStream == self.networkStream);   //断言 当前的流只是输出流

    switch (eventCode) {
      //  //当流事件是流打开完成的时候
        case NSStreamEventOpenCompleted: {
            [self _updateStatus:@"Opened connection"];
        } break;
    //当流事件是有可用数据的时候//收到数据在输出流中是不会发生的
        case NSStreamEventHasBytesAvailable: {   //有字节来读 ，我看过别的发送数据的时候，一般这个分支是不会写的，因为他找到服务后会自动发送数据而发送数据一般是需要我们手动控制的，自己发送数据可以看‘IOS局域网通信’的那个例子
            assert(NO);     // should never happen for the output stream
        } break;
         //在数据量不小的情况下，这个块里面的方法可能会和ReceiveServerController里的   case NSStreamEventHasBytesAvailable: {里的逻辑交替进行，你写一块，我读一块，直到两者都弄完就各自退出运行循环
       //************************************************************当流对象有空间可供数据写入（终于明白是啥意思了）。************************************************************
/*下面的引在于互联网：重要的是，一旦open the stream，只要delegate持续想流对象写入数据，流对象就是一直向其delegate发送stream:handleEvent:消息，
直到到达了流的末尾。这些消息中包含一个NSStreamEvent常量参数来指示事件的类型。对于一个NSOutputStream对象，
最常见的事件类型是NSStreamEventOpenCompleted，NSStreamEventHasSpaceAvailable，NSStreamEventEndEncountered，
delegate通常对NSStreamEventHasSpaceAvaliable事件最感兴趣。下面的代码就是处理NSStreamEventHasSpaceAvaliable事件的一种方法：
*/

 
      case NSStreamEventHasSpaceAvailable: { //当流对象有空间可供数据写入。 ，从ReceiveServerController里面找到了这个服务，但是注意此时服务并没有什么输出流（我现在才知道服务与流是没关系的感觉，输入和输出流是与socket有关的，通过服务可以
//获得输入输出流，但是这些都是socekt的，不是服务的），而且接收者的输出流是在socekt回调函数里面，与新生成的socket绑定的，所以与服务根本没有关系，不要弄混！但是如果是该函数先执行 case NSStreamEventOpenCompleted:
//之后就调用了socket的回调函数（AcceptCallback），也就是为新的socket绑定了输入流。但是这与接收者发布的服务没有关系。只要接收者，也就是服务器发布了一个服务，并且在发送方已经找到了（这里就是事先知道了），那么就会走着逻辑（我认为是这样，因为这个逻辑走的很少，一般都是手动发送数据）
//如果:kSendBufferSize比较小的话，而输出流又还在runloop中，那么这个方法
//会持续下去，我说的持续下去也不一定是光这个逻辑再走，在ReceiveServerController有输入流在接收数据，人家也在runloop中， 因为本类中有   bytesWritten = [self.networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
//这个方法，所以也有可能在写入到输出流一部数据后，ReceiveServerController会读取数据，之后又回到写入，导换几次，直到bytesRead == 0退出运行循环，写入停止。这些通过调试测出来的。
          
                 [self _updateStatus:@"Sending"];//更新状态
            
            // If we don't have any data buffered, go read the next chunk of data.
            //如果我们没有任何数据缓冲,去读下一块数据
            if (self.bufferOffset == self.bufferLimit) {
                NSInteger   bytesRead;
                //把指定的字节数读入到缓冲区中，这缓冲区必须足够大来容纳给定的字节数
               //返回值：
                 // 一个正数表明读取的字节数;
               //0表明缓冲区的末尾已经达到;（从流里面读完了，到底了）
                //一个负数意味着操作失败。
                 //把buffer，也就是缓冲区的数据写入到流空间中
                bytesRead = [self.fileStream read:self.buffer maxLength:kSendBufferSize];
                
                if (bytesRead == -1) {
                    [self _stopSendWithStatus:@"File read error"];
                } else if (bytesRead == 0) {   //fliestream读完之后会走这个方法，让输出流退出运行循环中，发送数据完毕
                    [self _stopSendWithStatus:nil];
                } else { 
                    self.bufferOffset = 0;
                    self.bufferLimit  = bytesRead;
                }
            }
            
            // If we're not out of data completely, send the next chunk.
            //如果没有超出范围，把读到缓冲区里的这块数据写入到输出流
            if (self.bufferOffset != self.bufferLimit) {   //这里没有像生成图片一样用循环，因为这个回调方法会不断循环（我的理解）
                NSInteger   bytesWritten;
                bytesWritten = [self.networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                assert(bytesWritten != 0);//不会等于0，以为之前有判断else if (bytesRead == 0)   [self _stopSendWithStatus:nil];
                if (bytesWritten == -1) {
                    [self _stopSendWithStatus:@"Network write error"];
                } else {
                    self.bufferOffset += bytesWritten;
                }
            }
        } break;
        case NSStreamEventErrorOccurred: {
            [self _stopSendWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: { //断开连接的逻辑
            // ignore
        } break;
        default: {
            assert(NO);
        } break;
    }
}

#pragma mark * Actions
//点击图片后执行的方法
- (IBAction)sendAction:(UIView *)sender
{
    assert( [sender isKindOfClass:[UIView class]] );
  //如果已经有图片正在发送，就不执行下面的方法
    if ( ! self.isSending ) {
        NSString *  filePath;
        
        // User the tag on the UIButton to determine which image to send.
        //返回新生成图片的路径，这个新图片生成到临时目录中，然后就是针对这个图片进行读取，输出到ReceiveServerController中然后对图片进行还原，生成图片的逻辑在viewcontroller中，到时候那里会说
        filePath = [[AppDelegate sharedAppDelegate] pathForTestImage:sender.tag];
        assert(filePath != nil);
        //正式开始发送图片
        [self _startSend:filePath];
    }
}
//取消方法
- (IBAction)cancelAction:(id)sender
{
    #pragma unused(sender)
    [self _stopSendWithStatus:@"Cancelled"];
}

#pragma mark * View controller boilerplate

@synthesize statusLabel       = _statusLabel;
@synthesize activityIndicator = _activityIndicator;
@synthesize cancelButton        = _stopButton;
//释放逻辑
- (void)dealloc
{
    [self _stopSendWithStatus:@"Stopped"];
    [self->_statusLabel release];
    self->_statusLabel = nil;
    [self->_activityIndicator release];
    self->_activityIndicator = nil;
    [self->_stopButton release];
    self->_stopButton = nil;

    [super dealloc];
}

- (void)setView:(UIView *)newValue
{
    if (newValue == nil) {
        self.statusLabel = nil;
        self.activityIndicator = nil;
        self.cancelButton = nil;
    }
    [super setView:newValue];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    assert(self.statusLabel != nil);
    assert(self.activityIndicator != nil);
    assert(self.cancelButton != nil);
    
    self.activityIndicator.hidden = YES;
    self.statusLabel.text = @"Tap a picture to start the send";
    self.cancelButton.enabled = NO;
}

@end
