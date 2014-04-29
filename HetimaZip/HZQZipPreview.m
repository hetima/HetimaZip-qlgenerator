//
//  HZQZipPreview.m
//  HetimaZip
//
//  Created by hetima on 2014/04/27.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import "HZQZipPreview.h"
#import "HZQZipItem.h"
#include <sys/xattr.h>

#define kItemListLimit 500
#define kImageTileCount 8
#define kMDItemWhereFromsBufferSize 2048

@implementation HZQZipPreview


- (instancetype)initWithZipItem:(HZQZipItem*)zipItem
{
    self = [super init];
    if (self) {
        _zipItem=zipItem;
        _attachments=[[NSMutableDictionary alloc]initWithCapacity:kImageTileCount];
        _zipInformation=[zipItem zipInformationWithListDataLimit:kItemListLimit];
    }
    return self;
}


- (void)addAttachment:(NSDictionary*)dic forKey:(NSString*)key
{
    [_attachments setObject:dic forKey:key];
}


- (NSString*)imageTilesSection
{
    //images
    BOOL handleImage=NO;
    NSDictionary* info=self.zipInformation;
    NSArray* images=nil;
    NSString* divClass=@"tile";
    
    if (info) {
        NSInteger imageCount=[info[@"imageCount"] integerValue];
        NSInteger nonImageCount=[info[@"nonImageCount"] integerValue];
        if (imageCount>7 || imageCount>nonImageCount) {
            handleImage=YES;
        }else{
            handleImage=NO;
        }

        if ([self.zipItem zipSeemsContainApp]) {
            NSData* iconData=[self.zipItem appIconData];
            if (iconData) {
                images=@[iconData];
                divClass=@"appicon";
                handleImage=NO;
                
            }
        }
    
    }else{ // cvbdl
        handleImage=YES;
    }
    if (handleImage) {
        images=[self.zipItem imageDataArrayWithExpectation:kImageTileCount];
    }
    
    if ([images count]) {
        __block NSString* imageSection=@"";
        [images enumerateObjectsUsingBlock:^(NSData* imageData, NSUInteger idx, BOOL *stop){
            NSString* name=[NSString stringWithFormat:@"image%lu", (unsigned long)idx];
            NSDictionary* attachment=@{
                                       (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"image",
                                       (__bridge NSString *)kQLPreviewPropertyAttachmentDataKey : imageData,
                                       };
            NSString* htmlTag=[NSString stringWithFormat:@"<div class=\"%@\" style=\"background-image:url('cid:%@')\"></div>", divClass, name];
            imageSection=[imageSection stringByAppendingString:htmlTag];
            [self addAttachment:attachment forKey:name];
        }];
        if ([imageSection length]) {
            imageSection=[self sectionElementWithInnerHtml:imageSection];
        }
        return imageSection;
        
    }
    
    return @"";
}


- (NSString*)whereFromSection
{
    //com.apple.metadata:kMDItemWhereFroms
    NSString* whereSection=@"";
    const char* pathcstr=[self.zipItem.path fileSystemRepresentation];
    void *buf=malloc(kMDItemWhereFromsBufferSize);
    ssize_t size=getxattr(pathcstr, "com.apple.metadata:kMDItemWhereFroms", buf, kMDItemWhereFromsBufferSize, 0, 0);
    if (size>0) {
        NSData *data=[NSData dataWithBytes:buf length:size];
        NSArray* ary=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
        if ([ary count]) {
            whereSection=[ary componentsJoinedByString:@"<br>"];
            whereSection=[NSString stringWithFormat:@"<h2>kMDItemWhereFroms:</h2><pre>%@</pre>", whereSection];
            whereSection=[self sectionElementWithInnerHtml:whereSection];
        }
    }
    free(buf);
    
    return whereSection;
}


- (NSString*)contentListSection:(NSStringEncoding*)outEncoding
{
    NSDictionary* info=self.zipInformation;

    NSStringEncoding encoding;
    
    //list
    NSData* listData=info[@"listData"];
    if (listData) {
        NSString* listSection=[[NSString alloc]initWithData:listData encoding:NSUTF8StringEncoding];
        encoding=NSUTF8StringEncoding;
        if ([listSection length]<=0) {
            listSection=[[NSString alloc]initWithData:listData encoding:NSShiftJISStringEncoding];
            encoding=NSShiftJISStringEncoding;
        }
        
        if ([listSection length]) {
            if (outEncoding) *outEncoding=encoding;
            listSection=[[@"<h2>Contents:</h2><pre class=\"list\">" stringByAppendingString:listSection]stringByAppendingString:@"</pre>"];
            listSection=[self sectionElementWithInnerHtml:listSection];
            return listSection;
        }
    }
    
    return @"";
}


- (void)setupGeneralFileSystemInfo:(NSMutableArray*)generalInfo
{
    //generalInfo[@"Path:"]=self.zipItem.path;
    [generalInfo addObject:@{@"key": @"Path:", @"val": self.zipItem.path}];
    
    NSDictionary* dict=[[NSFileManager defaultManager]attributesOfItemAtPath:self.zipItem.path error:nil];
    NSDate* modDate=[dict fileModificationDate];
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc]init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *modDateString = [dateFormatter stringFromDate:modDate];
    if (modDateString) {
        //generalInfo[@"Modification:"]=modDateString;
        [generalInfo addObject:@{@"key": @"Modification Date:", @"val": modDateString}];
    }
    
    if (!self.zipItem.isDirectory) {
        NSNumber* fileSize=dict[NSFileSize];
        NSNumberFormatter *sizeFormatter = [[NSNumberFormatter alloc]init];
        [sizeFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [sizeFormatter setGroupingSeparator:@","];
        [sizeFormatter setGroupingSize:3];
        
        NSString* fileSizeString=[sizeFormatter stringForObjectValue:fileSize];
        if (fileSizeString) {
            //generalInfo[@"File Size:"]=[fileSizeString stringByAppendingString:@" bytes"];
            [generalInfo addObject:@{@"key": @"File Size:", @"val": [fileSizeString stringByAppendingString:@" bytes"]}];
        }
    }
}


- (void)generatePreview:(QLPreviewRequestRef)preview
{

    NSString* htmlContent=[self hrmlBeginningPart];
    //NSDictionary* info=self.zipInformation;
    
    //list pre
    NSStringEncoding encoding;
    NSString* listSection=[self contentListSection:&encoding];
    
    //general
    //NSMutableDictionary* generalInfo=[[NSMutableDictionary alloc]initWithCapacity:20];
    NSMutableArray* generalInfo=[[NSMutableArray alloc]initWithCapacity:8];
    [self setupGeneralFileSystemInfo:generalInfo];
    
    NSNumber* itemCount=self.zipInformation[@"itemCount"];
    NSInteger imageCount=[self.zipInformation[@"imageCount"] integerValue];
    NSString* itemCountString=[NSString stringWithFormat:@"%@", itemCount];
    if (imageCount>0) {
        itemCountString=[itemCountString stringByAppendingFormat:@" (%ld images)", imageCount];
    }
    [generalInfo addObject:@{@"key": @"Number of Contents:", @"val": itemCountString}];
    
    if (encoding==NSUTF8StringEncoding) {
        [generalInfo addObject:@{@"key": @"Encoding:", @"val": @"UTF-8"}];
    }else if (encoding==NSShiftJISStringEncoding) {
        [generalInfo addObject:@{@"key": @"Encoding:", @"val": @"Shift-JIS"}];
    }
    
    
    NSString* generalSection=[NSString stringWithFormat:@"<h1>%@</h1>",[self.zipItem.path lastPathComponent]];
    generalSection=[generalSection stringByAppendingString:[self dlWithDictionaryArray:generalInfo]];
    generalSection=[self sectionElementWithInnerHtml:generalSection];
    htmlContent=[htmlContent stringByAppendingString:generalSection];

    //images
    NSString* imageSection=[self imageTilesSection];
    htmlContent=[htmlContent stringByAppendingString:imageSection];

    
    //com.apple.metadata:kMDItemWhereFroms
    NSString* whereSection=[self whereFromSection];
    htmlContent=[htmlContent stringByAppendingString:whereSection];


    htmlContent=[htmlContent stringByAppendingString:listSection];

    
    NSString* hrmlEndingPart=@"</body></html>";
    htmlContent=[htmlContent stringByAppendingString:hrmlEndingPart];
    
    
    NSData* data=[htmlContent dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {

        NSDictionary* option=@{
            (__bridge NSString*)kQLPreviewPropertyWidthKey:@800,
            (__bridge NSString*)kQLPreviewPropertyHeightKey:@560,
            (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
            (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html",
            (__bridge NSString *)kQLPreviewPropertyAttachmentsKey : self.attachments
        };
        
        QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)(data), kUTTypeHTML, (__bridge CFDictionaryRef)(option));
    }

}


- (NSString*)hrmlBeginningPart
{
    //load template
    NSString* tmplPath=[[NSBundle bundleForClass:[self class]]pathForResource:@"zip_tmpl" ofType:@"html"];
    NSString* tmpl=[[NSMutableString alloc]initWithContentsOfFile:tmplPath encoding:NSUTF8StringEncoding error:nil];
    
    return tmpl;
}


- (NSString*)dlWithDictionaryArray:(NSArray*)ary
{
    __block NSString* result=@"<dl>";
    
    for (NSDictionary* dic in ary) {
        NSString* key=dic[@"key"];
        NSString* val=dic[@"val"];
        NSString* dtdd=[NSString stringWithFormat:@"<dt>%@</dt><dd>%@</dd>", key, val];
        result=[result stringByAppendingString:dtdd];
    }
    
    result=[result stringByAppendingString:@"</dl>"];
    
    return result;
}


- (NSString*)sectionElementWithInnerHtml:(NSString*)innerHtml
{
    return [[@"<div class=\"section\">" stringByAppendingString:innerHtml]stringByAppendingString:@"</div>"];
}

@end
