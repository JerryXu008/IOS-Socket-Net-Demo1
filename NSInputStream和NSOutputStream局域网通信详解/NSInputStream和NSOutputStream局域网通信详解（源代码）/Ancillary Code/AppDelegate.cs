/*
    File:       AppDelegate.m

    Contains:   Main app controller.

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

#import "AppDelegate.h"

#import "InfoController.h"

@interface AppDelegate ()
@property (nonatomic, assign) NSInteger             networkingCount;
@end

@implementation AppDelegate

+ (AppDelegate *)sharedAppDelegate
{
    return (AppDelegate *) [UIApplication sharedApplication].delegate;
}

@synthesize window      = _window;
@synthesize tabs        = _tabs;

@synthesize networkingCount = _networkingCount;

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    #pragma unused(application)
    assert(self.window != nil);
    assert(self.tabs != nil);
    
    [self.window addSubview:self.tabs.view];
    
    self.tabs.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"currentTab"];
    
	[self.window makeKeyAndVisible];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    #pragma unused(application)
    [[NSUserDefaults standardUserDefaults] setInteger:self.tabs.selectedIndex forKey:@"currentTab"];
}

- (NSString *)pathForTestImage:(NSUInteger)imageNumber
    // In order to fully test the send and receive code paths, we need some really big 
    // files.  Rather than carry theshe files around in our binary, we synthesise them. 
    // Specifically, for each test image, we expand the image by an order of magnitude, 
    // based on its image number.  That is, image 1 is not expanded, image 2 
    // gets expanded 10 times, and so on.  We expand the image by simply copying it 
    // to the temporary directory, writing the same data to the file over and over 
    // again.
  //为了充分测试发送和接收代码路径,我们需要一些非常大
//文件。而不是把theshe文件大约在我们的二进制,我们合成他们。
//具体来说,每个测试的形象,我们扩大图像通过一个数量级,
//基于其形象号码。即,图1是不扩大,图2
//将会得到扩展10倍,等等。我们扩大图像通过简单地复制它
//到临时目录中,编写相同的数据文件反复
//再一次。

{
    NSUInteger          power;
    NSUInteger          expansionFactor;
    NSString *          originalFilePath;
    NSString *          bigFilePath;
    NSFileManager *     fileManager;
    NSDictionary *      attrs;
    unsigned long long  originalFileSize;   //64位，8个字节
    unsigned long long  bigFileSize;
    
    assert( (imageNumber >= 1) && (imageNumber <= 4) );

    // Argh, C has no built-in power operator, so I have to do 10 ** (imageNumber - 1)
    // in floating point and then cast back to integer.  Fortunately the range 
    // of values is small enough (1..1000) that floating point isn't going 
    // to cause me any problems.
    
    // On the simulator we expand by an extra order of magnitude; Macs are fast!
    
    power = imageNumber - 1;
    #if TARGET_IPHONE_SIMULATOR
        power += 1;
    #endif
    expansionFactor = (NSUInteger) pow(10, power);

    fileManager = [NSFileManager defaultManager];
    assert(fileManager != nil);
    
    // Calculate paths to both the original file and the expanded file.
    
    originalFilePath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"TestImage%zu", (size_t) imageNumber] ofType:@"png"];
    assert(originalFilePath != nil);
    
    bigFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"TestImage%zu.png", (size_t) imageNumber]];
    assert(bigFilePath != nil);
    
    // Get the sizes of each.
    //获取指定文件的相关属性
    attrs = [fileManager attributesOfItemAtPath:originalFilePath error:NULL];
    assert(attrs != nil);
    
    originalFileSize = [[attrs objectForKey:NSFileSize] unsignedLongLongValue]; //获取原始图片的大小

    attrs = [fileManager attributesOfItemAtPath:bigFilePath error:NULL];
    if (attrs == NULL) {
        bigFileSize = 0;
    } else {
        bigFileSize = [[attrs objectForKey:NSFileSize] unsignedLongLongValue];
    }
    
    // If the expanded file is missing, or the wrong size, create it from scratch.
    //创造一个新图像，扩大相应的倍数
    if (bigFileSize != (originalFileSize * expansionFactor)) {
        NSOutputStream *    bigFileStream;
        NSData *            data;
        const uint8_t *     dataBuffer;
        NSUInteger          dataLength;
        NSUInteger          dataOffset;
        NSUInteger          counter;

        NSLog(@"%5u - %@", (size_t) expansionFactor, bigFilePath);
         //创建并返回一个数据对象映射的文件所指定的路径。(ios5上被弃用)
    //API文档上说更安全的方法是dataWithContentsOfFile:
        data = [NSData dataWithContentsOfMappedFile:originalFilePath];
        assert(data != nil);
    //    返回一个指向接收者的内容。 原型为： - (const void *)bytes   若函数返回值类型为void *则可以匹配任何返回值类型
        dataBuffer = [data bytes];   
     //返回出字节数
        dataLength = [data length];
        //输出流关联到指定文件
        bigFileStream = [NSOutputStream outputStreamToFileAtPath:bigFilePath append:NO];
        assert(bigFileStream != NULL);
        //使用前要打开
        [bigFileStream open];
           //扩大倍数（其实就是连续重复的写）
        for (counter = 0; counter < expansionFactor; counter++) {
            dataOffset = 0;
            while (dataOffset != dataLength) { //这里比较的都是字节   while全部循环完之后会完全写入图片一次数据
                NSInteger       bytesWritten;
                //把指定大小的数据写入到数据缓冲区   参数一： 参数二：数据缓冲区的长度,以字节为单位
                bytesWritten = [bigFileStream write:&dataBuffer[dataOffset] maxLength:dataLength - dataOffset];
                assert(bytesWritten > 0);
                
                dataOffset += bytesWritten;
            }
        }
        //关闭输出流
        [bigFileStream close];
    }
    
    return bigFilePath;
}

- (NSString *)pathForTemporaryFileWithPrefix:(NSString *)prefix
{
    NSString *  result;
    CFUUIDRef   uuid;
    CFStringRef uuidStr;
    
    uuid = CFUUIDCreate(NULL);
    assert(uuid != NULL);
    
    uuidStr = CFUUIDCreateString(NULL, uuid);
    assert(uuidStr != NULL);
    
    result = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", prefix, uuidStr]];
    assert(result != nil);
    
    CFRelease(uuidStr);
    CFRelease(uuid);
    
    return result;
}

- (void)didStartNetworking
{
    self.networkingCount += 1;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)didStopNetworking
{
    assert(self.networkingCount > 0);
    self.networkingCount -= 1;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = (self.networkingCount != 0);
}

@end
