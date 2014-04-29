//
//  HZQIpaPreview.h
//  HetimaZip
//
//  Created by hetima on 2014/04/27.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>

@class HZQZipItem;

@interface HZQIpaPreview : NSObject

@property (nonatomic, assign)HZQZipItem* zipItem;

- (instancetype)initWithZipItem:(HZQZipItem*)zipItem;

- (void)generatePreview:(QLPreviewRequestRef)preview;


@end
