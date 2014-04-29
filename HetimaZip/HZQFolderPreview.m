//
//  HZQFolderPreview.m
//  HetimaZip
//
//  Created by hetima on 2014/04/28.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import "HZQFolderPreview.h"
#import "HZQZipItem.h"
#include <sys/xattr.h>

@implementation HZQFolderPreview


- (void)generatePreview:(QLPreviewRequestRef)preview
{
    NSString* htmlContent=[self hrmlBeginningPart];
    
    //general
    NSMutableArray* generalInfo=[[NSMutableArray alloc]initWithCapacity:8];
    [self setupGeneralFileSystemInfo:generalInfo];
    
    NSInteger imageCount=[self.zipItem numberOfImagesInDirectory];
    [generalInfo addObject:@{@"key": @"Number of Images:", @"val": [NSString stringWithFormat:@"%ld", (long)imageCount]}];

    NSString* generalSection=[NSString stringWithFormat:@"<h1>%@</h1>",[self.zipItem.path lastPathComponent]];
    generalSection=[generalSection stringByAppendingString:[self dlWithDictionaryArray:generalInfo]];
    generalSection=[self sectionElementWithInnerHtml:generalSection];
    htmlContent=[htmlContent stringByAppendingString:generalSection];

    //images
    NSString* imageSection=[self imageTilesSection];
    htmlContent=[htmlContent stringByAppendingString:imageSection];
 
    
    NSString* hrmlEndingPart=@"</body></html>";
    htmlContent=[htmlContent stringByAppendingString:hrmlEndingPart];
    
    NSData* data=[htmlContent dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {
        
        NSDictionary* option=@{
            (__bridge NSString*)kQLPreviewPropertyWidthKey : @800,
            (__bridge NSString*)kQLPreviewPropertyHeightKey : @530,
            (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
            (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html",
            (__bridge NSString *)kQLPreviewPropertyAttachmentsKey : self.attachments
        };
        
        QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)(data), kUTTypeHTML, (__bridge CFDictionaryRef)(option));
    }
    
}


@end
