//
//  HZQIpaPreview.m
//  HetimaZip
//
//  Created by hetima on 2014/04/27.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import "HZQIpaPreview.h"
#import "HZQZipItem.h"

@implementation HZQIpaPreview

- (instancetype)initWithZipItem:(HZQZipItem*)zipItem
{
    self = [super init];
    if (self) {
        _zipItem=zipItem;
    }
    return self;
}


- (void)generatePreview:(QLPreviewRequestRef)preview
{
    CFDataRef data=NULL;
    data=[self createPreviewData];
    if (data) {
        NSData* iconData=[self.zipItem dataForName:@"iTunesArtwork"];

        NSDictionary* option=@{
            (__bridge NSString*)kQLPreviewPropertyWidthKey:@600,
            (__bridge NSString*)kQLPreviewPropertyHeightKey:@180,
            (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey : @"UTF-8",
            (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"text/html",
            (__bridge NSString *)kQLPreviewPropertyAttachmentsKey : @{
                @"iTunesArtwork" : @{
                    (__bridge NSString *)kQLPreviewPropertyMIMETypeKey : @"image",
                    (__bridge NSString *)kQLPreviewPropertyAttachmentDataKey: iconData,
                },
            },
        };
        
        QLPreviewRequestSetDataRepresentation(preview, data, kUTTypeHTML, (__bridge CFDictionaryRef)(option));
        CFRelease(data);
    }
}


- (CFDataRef)createPreviewData
{
    
    //load template
    NSString* tmplPath=[[NSBundle bundleForClass:[self class]]pathForResource:@"ipa_tmpl" ofType:@"html"];
    NSMutableString* tmpl=[[NSMutableString alloc]initWithContentsOfFile:tmplPath encoding:NSUTF8StringEncoding error:nil];
    
    NSData* metaData=[self.zipItem dataForName:@"iTunesMetadata.plist"];
    if (metaData) {
        NSDictionary* metaInfo=[NSPropertyListSerialization propertyListWithData:metaData options:NSPropertyListImmutable format:nil error:nil];
        NSArray* keys=@[@"itemName", @"bundleVersion", @"artistName", @"softwareVersionBundleId", @"genre"];
        for (NSString* key in keys) {
            NSString* value=[metaInfo objectForKey:key];
            if (value) {
                [tmpl replaceOccurrencesOfString:[NSString stringWithFormat:@"<%@></%@>", key, key]
                                      withString:value options:0 range:NSMakeRange(0, [tmpl length])];
            }
        }
    }
    /*
     keys=@[@"releaseDate", @"purchaseDate"];
     for (NSString* key in keys) {
     NSDate* date=[metaInfo objectForKey:key];
     if ([date isKindOfClass:[NSString class]]) {
     date=[NSDate dateWithNaturalLanguageString:(NSString*)date];
     }
     if ([date isKindOfClass:[NSDate class]]) {
     NSString* dateStr=[date descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:[NSLocale currentLocale]];
     //descriptionWithLocale:[NSLocale currentLocale]];
     [tmpl replaceOccurrencesOfString:[NSString stringWithFormat:@"<%@></%@>", key, key]
     withString:dateStr options:0 range:NSMakeRange(0, [tmpl length])];
     }
     }
     */
    
    
    NSData* data=[tmpl dataUsingEncoding:NSUTF8StringEncoding];
    return CFBridgingRetain(data);
    
}

@end
