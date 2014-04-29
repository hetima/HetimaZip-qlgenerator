//
//  HZQZipItem.h
//  HetimaZip
//
//  Created by hetima on 2014/04/27.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>

@interface HZQZipItem : NSObject

@property (nonatomic, strong) NSString* path;
@property (nonatomic, strong) NSString* contentTypeUTI;
@property (nonatomic) BOOL isDirectory;

@property (nonatomic) BOOL zipSeemsContainApp;
@property (nonatomic, strong) NSString* appInfoPlistPath;

- (instancetype)initWithURLRef:(CFURLRef)url contentTypeUTI:(CFStringRef)uti;

// versatile
- (NSData*)anyImageData;
- (NSData*)dataForName:(NSString*)name;
- (NSArray*)imageDataArrayWithExpectation:(NSInteger)count;


// zip
- (NSDictionary*)zipInformationWithListDataLimit:(NSInteger)listLimit;
//.app in zip support
- (NSData*)appIconData;
- (NSDictionary*)appInfoPlist;

// directory
- (NSInteger)numberOfImagesInDirectory;


- (void)generatePreview:(QLPreviewRequestRef)preview;
- (void)generateThumbnail:(QLThumbnailRequestRef)thumbnail maxSize:(CGSize)maxSize;


@end
