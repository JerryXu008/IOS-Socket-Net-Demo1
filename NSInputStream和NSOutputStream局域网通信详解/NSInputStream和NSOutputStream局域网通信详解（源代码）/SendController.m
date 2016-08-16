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
//ΪһЩ˽�еı����������ԣ�����Ҫ���⹫��
@property (nonatomic, readonly) BOOL              isSending;//�Ƿ����ڷ���
@property (nonatomic, retain)   NSNetService *    netService;
@property (nonatomic, retain)   NSOutputStream *  networkStream;
@property (nonatomic, retain)   NSInputStream *   fileStream;
@property (nonatomic, readonly) uint8_t *         buffer;     //  uint8_t   _buffer[kSendBufferSize]; �����ʱ�������飬�������Ե�ʱ����  uint8_t *    buffer����ס�����÷�������buffer�����ʱ���Ǹ����飬����Ҫ�Լ�дget���������ص��������׵�ַ��������н���
@property (nonatomic, assign)   size_t            bufferOffset;
@property (nonatomic, assign)   size_t            bufferLimit;

@end

@implementation SendController

#pragma mark * Status management

// These methods are used by the core transfer code to update the UI.
//Ȼ�����Ŀǰ����������û�����
- (void)_sendDidStart
{
    self.statusLabel.text = @"Sending";
    self.cancelButton.enabled = YES;
    [self.activityIndicator startAnimating];
    [[AppDelegate sharedAppDelegate] didStartNetworking];
}
//����״̬��ǩ
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
//����buffer��get����������������׵�ַ
- (uint8_t *)buffer
{
    return self->_buffer;
}
//�Ƿ����ڷ��ͣ�����������Ϊ�գ���ô�������ڷ���
- (BOOL)isSending
{
    return (self.networkStream != nil);
}
//����ͼƬ��·����ͼƬ���͵������
- (void)_startSend:(NSString *)filePath
{
    NSOutputStream *    output;//���������������˵ķ���
    BOOL                success;
    
    assert(filePath != nil);
    
    assert(self.networkStream == nil);      // don't tap send twice in a row!
    assert(self.fileStream == nil);         // ditto

    // Open a stream for the file we're going to send.
    //����������һ����ʼ��NSInputStream����,��һ��������·���д��ļ���ȡ����
    self.fileStream = [NSInputStream inputStreamWithFileAtPath:filePath];
    assert(self.fileStream != nil);
    //��������
    [self.fileStream open];
    
    // Open a stream to the server, finding the server via Bonjour.  Then configure 
    // the stream for async operation.
    //��ʼ������
   //��������Ҫ����һ��initWithDomain:type:name:port:��nitWithDomain:type:name:���������������𣬺��߶���һ������
   //�Ƚ��͵�һ���� 
    //������������ã����ؽ��ջ�,��ʼ��һ�����������͵��������Ĳ��������ó�ʼ������Ϣ��
   //����һ���������������򡣱�������local��
  //������������������ͣ�
  //����������Ҫ�����ķ��������
 //˵������������Ƕ�һ��Ҫ�����ķ���ĳ�ʼ��������������ڱ�������һ��������ô���� initWithDomain:type:name:port:.�������
//�����֪����Ҫ���ӵ������������������ͣ����֣���ô���ʹ�������������ʼ��һ��NSNetService������resolveWithTimeout: on the result.��������
//�����㲻��ʹ�������ʼ��������һ�����������ʼ������������Ч�Ķ˿ں���ָ���ĳ�ʼ������,���ᵼ�·���ע�ᱻ��ֹ��
 
   //�ٽ���initWithDomain:type:name:port:
   //������������ã���ʼ��һ��������Ϊһ�����񣬲�����������Ѿ����׽���ͨ�����������ͣ�������ϸ˵����
   //����һ���������������򡣱�������local��һ������ѡʹ��NSNetServiceBrowser�����õ���ע�������������ķ���ʹ�����Ĭ����,ֻ�贫��һ�����ַ���(@ " ")��
//������������������ͣ�
//��������ͨ�����name��ʶ��������������'',��ôϵͳ��ʹ�ü����������Ϊ����������������
//�����ģ�����������˿��з���������˿ڱ����Ƕ˿ڱ����Ǵ�Ӧ�ó����л�õġ�
//˵���������������������һ������,�������������ϡ���Ȼ��Ҳ���������ַ���������һ������Ҫ�����ķ���,����ʱһ�����initWithDomain:����:����:������������档
//������һ������,������ṩ��Ч�Ĳ���,�Ա���ȷ��Ϊ���ķ�������档����������ʶ��ע������,�����봴�������Ķ���NSNetServiceΪÿ�����������ͼ������һ������,��û�еǼǻ���,���������Ա��ܾ���
//���ǿɽ��ܵ�ʹ�ÿ��ַ���������ڷ��������һ������,��������������顣
//���������ָ���ĳ�ʼ������
   //��ʼ��һ��NSNetService��ǰ����֪���˷����Ҫ�����ķ���������ͣ����֣���������˷��ͺ������������ѭ���л��⵽
    self.netService = [[[NSNetService alloc] initWithDomain:@"local." type:@"_x-SNSUpload._tcp." name:@"Test"] autorelease];
    assert(self.netService != nil);
//ͨ�����û�ȡ����������������   ������һ������ֵ���������Ƿ񱻳ɹ��ļ������� ��Ҫ֪����������Ƿ��񷽷��͹����ģ������ڷ���û�з��ͷ����ʱ��Ҳ�᷵��yes��������[self.networkStream open]��ʱ������
//- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode,�����ʱ����ߴ�����߼���Ҳ����  case NSStreamEventErrorOccurred:����ʧ��
   success = [self.netService getInputStream:NULL outputStream:&output];
    assert(success);
    
    self.networkStream = output; //���������
    
    // -[NSNetService getInputStream:outputStream:] currently returns the stream 
    // with a reference that we have to release (something that's counter to the 
    // standard Cocoa memory management rules <rdar://problem/6868813>).
    //-[NSNetService getInputStream:outputStream:]Ŀǰ������
    //һ������,���Ǳ����ͷ�

    [output release];
    //���ñ���Ϊί��
    self.networkStream.delegate = self;
  //���뵽����ѭ���� ,�������ķ����¼��Ż����
    [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    //�������
//�������֮��˵�������������ˣ���ʱ�����- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode�Ĵ򿪳ɹ��߼�
//Ҳ�п��ܽ��ŵ��� case NSStreamEventHasSpaceAvailable�����ߵ���Receiveservercontrller��socket�Ļص���������������������������ʱ����ã�ͨ��������������Ի���µ�socekt�������������ͨ��������������Կ���sendcontrooler�Ķ�д��
    [self.networkStream open]; 
    
    // Tell the UI we're sending.
    //����UI���Ƚϼ�
    [self _sendDidStart];
}
//ֹͣ���ͣ�����������ص������úÿ���ֹͣ��Ҫִ��ʲô������
- (void)_stopSendWithStatus:(NSString *)statusString
{
    if (self.networkStream != nil) {
        self.networkStream.delegate = nil; //���������ί����Ϊnil
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];//�Ƴ�����ѭ��
        [self.networkStream close];//������ر�
        self.networkStream = nil;//����nil������������ô���ٶ����ᱨ��
    }
    if (self.netService != nil) {
        [self.netService stop]; //ֹͣ�������
        self.netService = nil;
    }
    if (self.fileStream != nil) {
        [self.fileStream close]; //�����������ر�
        self.fileStream = nil;
    }
 //ƫ���������ֵ������Ϊ0
    self.bufferOffset = 0;
    self.bufferLimit  = 0;
//�����û�����
    [self _sendDidStopWithStatus:statusString];
}
//ί�з����������Ϣֻ��theStream��������һ������ѭ������Ϣ�����͵���������̡߳�streamEvent����Ӧ�ü����ȷ���ʵ����ж�Ӧ�ò�ȡ��

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
    // An NSStream delegate callback that's called when events happen on our 
    // network stream.
{
    #pragma unused(aStream)
    assert(aStream == self.networkStream);   //���� ��ǰ����ֻ�������

    switch (eventCode) {
      //  //�����¼���������ɵ�ʱ��
        case NSStreamEventOpenCompleted: {
            [self _updateStatus:@"Opened connection"];
        } break;
    //�����¼����п������ݵ�ʱ��//�յ���������������ǲ��ᷢ����
        case NSStreamEventHasBytesAvailable: {   //���ֽ����� ���ҿ�����ķ������ݵ�ʱ��һ�������֧�ǲ���д�ģ���Ϊ���ҵ��������Զ��������ݶ���������һ������Ҫ�����ֶ����Ƶģ��Լ��������ݿ��Կ���IOS������ͨ�š����Ǹ�����
            assert(NO);     // should never happen for the output stream
        } break;
         //����������С������£����������ķ������ܻ��ReceiveServerController���   case NSStreamEventHasBytesAvailable: {����߼�������У���дһ�飬�Ҷ�һ�飬ֱ�����߶�Ū��͸����˳�����ѭ��
       //************************************************************���������пռ�ɹ�����д�루����������ɶ��˼�ˣ���************************************************************
/*����������ڻ���������Ҫ���ǣ�һ��open the stream��ֻҪdelegate������������д�����ݣ����������һֱ����delegate����stream:handleEvent:��Ϣ��
ֱ������������ĩβ����Щ��Ϣ�а���һ��NSStreamEvent����������ָʾ�¼������͡�����һ��NSOutputStream����
������¼�������NSStreamEventOpenCompleted��NSStreamEventHasSpaceAvailable��NSStreamEventEndEncountered��
delegateͨ����NSStreamEventHasSpaceAvaliable�¼������Ȥ������Ĵ�����Ǵ���NSStreamEventHasSpaceAvaliable�¼���һ�ַ�����
*/

 
      case NSStreamEventHasSpaceAvailable: { //���������пռ�ɹ�����д�롣 ����ReceiveServerController�����ҵ���������񣬵���ע���ʱ����û��ʲô������������ڲ�֪������������û��ϵ�ĸо�����������������socket�йصģ�ͨ���������
//��������������������Щ����socekt�ģ����Ƿ���ģ������ҽ����ߵ����������socekt�ص��������棬�������ɵ�socket�󶨵ģ�������������û�й�ϵ����ҪŪ�죡��������Ǹú�����ִ�� case NSStreamEventOpenCompleted:
//֮��͵�����socket�Ļص�������AcceptCallback����Ҳ����Ϊ�µ�socket������������������������߷����ķ���û�й�ϵ��ֻҪ�����ߣ�Ҳ���Ƿ�����������һ�����񣬲����ڷ��ͷ��Ѿ��ҵ��ˣ������������֪���ˣ�����ô�ͻ������߼�������Ϊ����������Ϊ����߼��ߵĺ��٣�һ�㶼���ֶ��������ݣ�
//���:kSendBufferSize�Ƚ�С�Ļ�����������ֻ���runloop�У���ô�������
//�������ȥ����˵�ĳ�����ȥҲ��һ���ǹ�����߼����ߣ���ReceiveServerController���������ڽ������ݣ��˼�Ҳ��runloop�У� ��Ϊ��������   bytesWritten = [self.networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
//�������������Ҳ�п�����д�뵽�����һ�����ݺ�ReceiveServerController���ȡ���ݣ�֮���ֻص�д�룬�������Σ�ֱ��bytesRead == 0�˳�����ѭ����д��ֹͣ����Щͨ�����Բ�����ġ�
          
                 [self _updateStatus:@"Sending"];//����״̬
            
            // If we don't have any data buffered, go read the next chunk of data.
            //�������û���κ����ݻ���,ȥ����һ������
            if (self.bufferOffset == self.bufferLimit) {
                NSInteger   bytesRead;
                //��ָ�����ֽ������뵽�������У��⻺���������㹻�������ɸ������ֽ���
               //����ֵ��
                 // һ������������ȡ���ֽ���;
               //0������������ĩβ�Ѿ��ﵽ;��������������ˣ������ˣ�
                //һ��������ζ�Ų���ʧ�ܡ�
                 //��buffer��Ҳ���ǻ�����������д�뵽���ռ���
                bytesRead = [self.fileStream read:self.buffer maxLength:kSendBufferSize];
                
                if (bytesRead == -1) {
                    [self _stopSendWithStatus:@"File read error"];
                } else if (bytesRead == 0) {   //fliestream����֮����������������������˳�����ѭ���У������������
                    [self _stopSendWithStatus:nil];
                } else { 
                    self.bufferOffset = 0;
                    self.bufferLimit  = bytesRead;
                }
            }
            
            // If we're not out of data completely, send the next chunk.
            //���û�г�����Χ���Ѷ�������������������д�뵽�����
            if (self.bufferOffset != self.bufferLimit) {   //����û��������ͼƬһ����ѭ������Ϊ����ص������᲻��ѭ�����ҵ���⣩
                NSInteger   bytesWritten;
                bytesWritten = [self.networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                assert(bytesWritten != 0);//�������0����Ϊ֮ǰ���ж�else if (bytesRead == 0)   [self _stopSendWithStatus:nil];
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
        case NSStreamEventEndEncountered: { //�Ͽ����ӵ��߼�
            // ignore
        } break;
        default: {
            assert(NO);
        } break;
    }
}

#pragma mark * Actions
//���ͼƬ��ִ�еķ���
- (IBAction)sendAction:(UIView *)sender
{
    assert( [sender isKindOfClass:[UIView class]] );
  //����Ѿ���ͼƬ���ڷ��ͣ��Ͳ�ִ������ķ���
    if ( ! self.isSending ) {
        NSString *  filePath;
        
        // User the tag on the UIButton to determine which image to send.
        //����������ͼƬ��·���������ͼƬ���ɵ���ʱĿ¼�У�Ȼ�����������ͼƬ���ж�ȡ�������ReceiveServerController��Ȼ���ͼƬ���л�ԭ������ͼƬ���߼���viewcontroller�У���ʱ�������˵
        filePath = [[AppDelegate sharedAppDelegate] pathForTestImage:sender.tag];
        assert(filePath != nil);
        //��ʽ��ʼ����ͼƬ
        [self _startSend:filePath];
    }
}
//ȡ������
- (IBAction)cancelAction:(id)sender
{
    #pragma unused(sender)
    [self _stopSendWithStatus:@"Cancelled"];
}

#pragma mark * View controller boilerplate

@synthesize statusLabel       = _statusLabel;
@synthesize activityIndicator = _activityIndicator;
@synthesize cancelButton        = _stopButton;
//�ͷ��߼�
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
