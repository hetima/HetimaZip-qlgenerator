//
//  HZQImageAgent.m
//  HetimaZip
//
//  Created by hetima on 2014/04/29.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import "HZQImageAgent.h"

@implementation HZQImageAgent{
    NSData* _data;
    NSImage* _image;
}


- (instancetype)initWithData:(NSData*)data
{
    self = [super init];
    if (self) {
        _data=data;
        _image=[[NSImage alloc]initWithData:data];
    }
    return self;
}


- (NSImage*)bannerImageWithLabel:(NSString*)label width:(CGFloat)bannerWidth
{
    label=[label uppercaseString];
    
    CGFloat bannerHeight;
    //適当に大きさ調節
    if (bannerWidth<33) {
        bannerHeight=bannerWidth*(CGFloat)0.4;
    }else if (bannerWidth<55) {
        bannerHeight=bannerWidth*(CGFloat)0.3;
    }else{
        bannerHeight=bannerWidth*(CGFloat)0.23;
    }
    
    NSSize bannerSize=NSMakeSize(bannerWidth, bannerHeight);
    NSImage* canvas=[[NSImage alloc]initWithSize:bannerSize];
    
    
    [canvas lockFocus];
    [[NSColor whiteColor]set];
    NSRectFill(NSMakeRect(0, 0, bannerWidth, bannerHeight));
    
    //フォントサイズ適当
    NSDictionary* attr=@{
        NSFontAttributeName: [NSFont systemFontOfSize:bannerHeight*(CGFloat)0.92],
        NSForegroundColorAttributeName: [NSColor blackColor],
    };
    NSSize labelSize=[label sizeWithAttributes:attr];
    CGFloat x=(bannerSize.width - labelSize.width)*(CGFloat)0.5;
    CGFloat y=0-(bannerHeight*(CGFloat)0.06);
    [label drawAtPoint:NSMakePoint(x, y) withAttributes:attr];
    
    [canvas unlockFocus];
    
    
    return canvas;
}


- (NSData*)thumbnailDataWithLabel:(NSString*)label maxSize:(CGSize)maxSize
{
    if (!_image) {
        return _data;
    }
    
    //make square
    maxSize.width=maxSize.height=MAX(maxSize.width, maxSize.height);
    
    NSImage* canvas=[[NSImage alloc]initWithSize:maxSize];
    [canvas lockFocus];
    
    //crop
    NSSize imageSize=[_image size];
    CGFloat shortSide=MIN(imageSize.width, imageSize.height);
    CGFloat longSide=MAX(imageSize.width, imageSize.height);
    CGFloat baseSide;
    if (longSide/shortSide>(CGFloat)1.8) {
        baseSide=longSide/(CGFloat)1.8;
    }else{
        baseSide=shortSide;
    }
    NSRect cropRect=NSMakeRect(0, 0, baseSide, baseSide);
    cropRect.origin.x=(imageSize.width*(CGFloat)0.5)-NSMidX(cropRect);
    cropRect.origin.y=(imageSize.height*(CGFloat)0.5)-NSMidY(cropRect);
    
    [_image drawInRect:NSMakeRect(0, 0, maxSize.width, maxSize.height) fromRect:cropRect operation:NSCompositeCopy fraction:1.0];
    
    
    //banner
    if (maxSize.width>(CGFloat)22) {
        NSImage* bannerImage=[self bannerImageWithLabel:label  width:maxSize.width];
        cropRect=NSMakeRect(0, 0, bannerImage.size.width, bannerImage.size.height);
        NSRect inRect=NSMakeRect(0, 0, maxSize.width, maxSize.height);
        inRect.size.height=(maxSize.width/bannerImage.size.width)*bannerImage.size.height;
        [bannerImage drawInRect:inRect fromRect:cropRect operation:NSCompositeSourceOver fraction:0.70];
    }
    
    [canvas unlockFocus];
    NSData* result=[canvas TIFFRepresentation];
    
    return result;
}

@end
