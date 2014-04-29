//
//  HZQFolderPreview.h
//  HetimaZip
//
//  Created by hetima on 2014/04/28.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>
#import "HZQZipPreview.h"

@class HZQZipItem;

@interface HZQFolderPreview : HZQZipPreview

- (void)generatePreview:(QLPreviewRequestRef)preview;

@end
