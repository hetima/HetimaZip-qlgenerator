//
//  HZQZipPreview.h
//  HetimaZip
//
//  Created by hetima on 2014/04/27.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>

@class HZQZipItem;

@interface HZQZipPreview : NSObject

@property (nonatomic, assign)HZQZipItem* zipItem;
@property (nonatomic, strong)NSMutableDictionary* attachments;
@property (nonatomic, strong)NSDictionary* zipInformation;

- (instancetype)initWithZipItem:(HZQZipItem*)zipItem;
- (void)generatePreview:(QLPreviewRequestRef)preview;


- (void)addAttachment:(NSDictionary*)dic forKey:(NSString*)key;
- (NSString*)dlWithDictionaryArray:(NSArray*)dic;
- (NSString*)sectionElementWithInnerHtml:(NSString*)innerHtml;
- (NSString*)imageTilesSection;
- (NSString*)hrmlBeginningPart;
- (void)setupGeneralFileSystemInfo:(NSMutableArray*)generalInfo;

@end
