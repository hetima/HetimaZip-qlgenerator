//
//  HZQImageAgent.h
//  HetimaZip
//
//  Created by hetima on 2014/04/29.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HZQImageAgent : NSObject

- (instancetype)initWithData:(NSData*)data;
- (NSData*)thumbnailDataWithLabel:(NSString*)label maxSize:(CGSize)maxSize;

@end
