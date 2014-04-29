//
//  HZQZipItem.m
//  HetimaZip
//
//  Created by hetima on 2014/04/27.
//  Copyright (c) 2014 hetima. All rights reserved.
//

#import "HZQZipItem.h"
#import "HZQIpaPreview.h"
#import "HZQZipPreview.h"
#import "HZQFolderPreview.h"
#import "HZQImageAgent.h"

#import <fts.h>
#import <sys/stat.h>
#import "unzip.h"

#define kUnzipFileNameBuffer 512

enum {
    HTZQImageJpeg=1,
    HTZQImagePng=2,
    HTZQImageTiff=3,
    HTZQImageIcns=4,
    
    HTZQImageInvalid=0
};


int imageTypeWithFileName(const char* name)
{
    const char* pathStart=strrchr(name, '/');
    if (pathStart && *(pathStart+1)=='.') {
        return HTZQImageInvalid;
    }
    if (strstr(name, "__MACOSX/")) {
        return HTZQImageInvalid;
    }
    
    const char* ext=strrchr(name, '.');

    if(ext){
        if(strcmp(ext, ".jpg")==0||strcmp(ext, ".jpeg")==0||strcmp(ext, ".JPG")==0||strcmp(ext, ".JPEG")==0){
            return HTZQImageJpeg;
        }else if(strcmp(ext, ".png")==0||strcmp(ext, ".PNG")==0){
            return HTZQImagePng;
        }else if(strcmp(ext, ".icns")==0){
            return HTZQImageIcns;
        }
    }
    return HTZQImageInvalid;
}

/*
int imageTypeForData(CFDataRef data)
{
    int imgType=HTZQImageInvalid;
    if (data) {
        const UInt8* buf=CFDataGetBytePtr(data);
        if (*buf==(const UInt8)0xff && *(buf+1)==(const UInt8)0xd8) {
            imgType=HTZQImageJpeg;
        }else{
            imgType=HTZQImagePng;
        }
    }
    return imgType;
}
*/

@implementation HZQZipItem

- (instancetype)initWithURLRef:(CFURLRef)url contentTypeUTI:(CFStringRef)uti
{
    self = [super init];
    if (self) {
        CFStringRef pathstr=CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
        _path=CFBridgingRelease(pathstr);
        _contentTypeUTI=(__bridge NSString *)(uti);
        _appInfoPlistPath=nil;
        _zipSeemsContainApp=NO;
        [[NSFileManager defaultManager]fileExistsAtPath:_path isDirectory:&_isDirectory];
    }
    return self;
}

#pragma mark - versatile

- (NSData*)anyImageData
{
    NSArray* images=[self imageDataArrayWithExpectation:1];
    NSData* result=[images firstObject];
    return result;
}


- (NSData*)dataForName:(NSString*)name
{
    if (self.isDirectory) {
        return [self dataForNameInDirectory:name];
    }else{
        return [self dataForNameInZip:name];
    }
}


- (NSArray*)imageDataArrayWithExpectation:(NSInteger)count;
{
    if (self.isDirectory) {
        return [self imageDataArrayInDirectoryWithExpectation:count];
    }else{
        return [self imageDataArrayInZipWithExpectation:count];
    }
}

#pragma mark - directory specific

- (NSArray*)imageDataArrayInDirectoryWithExpectation:(NSUInteger)count
{
    NSMutableArray* result=[[NSMutableArray alloc]initWithCapacity:count];
    
    const char* pathcstr=[self.path fileSystemRepresentation];
    FTS* fts;
    FTSENT *entry;
    char* paths[] = { (char*)pathcstr, NULL };
    
    fts = fts_open(paths, FTS_XDEV+FTS_PHYSICAL, NULL);
    while ((entry = fts_read(fts))) {
        if (entry->fts_info == FTS_F) { //file
            int imgType=imageTypeWithFileName(entry->fts_name);
            if(imgType != HTZQImageInvalid){
                NSString* path=[NSString stringWithUTF8String:entry->fts_path];
                NSData* imageData=[[NSData alloc]initWithContentsOfFile:path];
                [result addObject:imageData];
                if ([result count]>=count) {
                    break;
                }
            }
        }
    }
    fts_close(fts);
    return result;
}


- (NSData*)dataForNameInDirectory:(NSString*)name
{
    NSData* result;
    NSString* dataPath=[self.path stringByAppendingPathComponent:name];
    if ([[NSFileManager defaultManager]fileExistsAtPath:dataPath]) {
        result=[[NSData alloc]initWithContentsOfFile:dataPath];
    }
    return result;
}


- (NSInteger)numberOfImagesInDirectory
{
    const char* pathcstr=[self.path fileSystemRepresentation];
    FTS* fts;
    FTSENT *entry;
    char* paths[] = { (char*)pathcstr, NULL };
    NSInteger count=0;
    
    fts = fts_open(paths, FTS_XDEV+FTS_PHYSICAL, NULL);
    while ((entry = fts_read(fts))) {
        if (entry->fts_info == FTS_F) { //file
            int imgType=imageTypeWithFileName(entry->fts_name);
            if(imgType != HTZQImageInvalid){
                ++count;
            }
        }
    }
    fts_close(fts);
    return count;
}

#pragma mark - zip specific


- (NSArray*)imageDataArrayInZipWithExpectation:(NSInteger)count
{
    NSMutableArray* result=[[NSMutableArray alloc]initWithCapacity:count];
    
    const char* pathcstr=[self.path fileSystemRepresentation];
    unzFile uf=unzOpen(pathcstr);
    if(uf){
        unz_global_info gi;
        int zerr;
        zerr = unzGetGlobalInfo(uf, &gi);
        if (zerr == UNZ_OK){
            char* filename_inzip=calloc(1, kUnzipFileNameBuffer);
            unz_file_info file_info;
            
            do {
                zerr = unzGetCurrentFileInfo(uf, &file_info, filename_inzip, kUnzipFileNameBuffer-1, NULL, 0, NULL, 0);
                if(zerr!=UNZ_OK || file_info.uncompressed_size==0){
                    continue;
                }
                if (!_zipSeemsContainApp && strstr(filename_inzip, ".app/Contents") ) {
                    _zipSeemsContainApp=YES;
                }
                if (_zipSeemsContainApp && strstr(filename_inzip, ".app/Contents/Info.plist") && !strstr(filename_inzip, ".framework/")) {
                    self.appInfoPlistPath=[NSString stringWithUTF8String:filename_inzip];
                }
                
                int imgType=imageTypeWithFileName(filename_inzip);
                if(imgType!=HTZQImageInvalid && ((file_info.flag & 1) == 0) && unzOpenCurrentFile(uf)==UNZ_OK){
                    
                    void* buf = malloc(file_info.uncompressed_size);
                    zerr = unzReadCurrentFile(uf, buf, (unsigned)file_info.uncompressed_size);
                    
                    if(zerr==file_info.uncompressed_size){
                        NSData* imageData=[[NSData alloc]initWithBytes:buf length:file_info.uncompressed_size];
                        [result addObject:imageData];
                    }
                    free(buf);
                    buf=NULL;
                    unzCloseCurrentFile(uf);
                    
                    if ([result count]>=count) {
                        break;
                    }
                }
            } while (unzGoToNextFile(uf)==UNZ_OK);
            
            free(filename_inzip);
        }
        unzClose(uf);
    }
    
    return result;
}


- (NSData*)dataForNameInZip:(NSString*)name
{
    NSData* result=NULL;
    const char* pathcstr=[self.path fileSystemRepresentation];
    const char* fileName=[name cStringUsingEncoding:NSUTF8StringEncoding];
    
    unzFile uf=unzOpen(pathcstr);
    if(uf){
        unz_global_info gi;
        int zerr;
        zerr = unzGetGlobalInfo(uf, &gi);
        if (zerr == UNZ_OK){
            char* filename_inzip=calloc(1, kUnzipFileNameBuffer);
            unz_file_info file_info;
            
            do {
                zerr = unzGetCurrentFileInfo(uf, &file_info, filename_inzip, kUnzipFileNameBuffer-1, NULL, 0, NULL, 0);
                if(zerr!=UNZ_OK || file_info.uncompressed_size==0){
                    continue;
                }
                
                if(strcmp(fileName, filename_inzip)!=0){
                    continue;
                }
                
                if( ((file_info.flag & 1) == 0) && unzOpenCurrentFile(uf)==UNZ_OK){
                    
                    void* buf = malloc(file_info.uncompressed_size);
                    zerr = unzReadCurrentFile(uf, buf, (unsigned)file_info.uncompressed_size);
                    if(zerr==file_info.uncompressed_size){
                        result=[[NSData alloc]initWithBytes:buf length:file_info.uncompressed_size];
                    }
                    free(buf);
                    buf=NULL;
                    unzCloseCurrentFile(uf);
                    break;
                }
            } while (unzGoToNextFile(uf)==UNZ_OK);
            
            free(filename_inzip);
        }
        unzClose(uf);
    }
    
    return result;
    
}


- (NSDictionary*)zipInformationWithListDataLimit:(NSInteger)listLimit
{
    if (self.isDirectory) {
        return nil;
    }
    
    NSDictionary* result=NULL;

    const char* pathcstr=[self.path fileSystemRepresentation];
    unzFile uf=unzOpen(pathcstr);
    
    NSInteger itemCount=0;
    NSInteger remainCount=0;
    NSInteger imageCount=0;
    NSInteger nonImageCount=0;

    //文字コードの問題があるので一旦 NSData に固める
    NSMutableData* listData=[[NSMutableData alloc]init];
    NSData* lf=[@"\n" dataUsingEncoding:NSUTF8StringEncoding];
    
    if(uf){
        unz_global_info gi;
        int zerr;
        zerr = unzGetGlobalInfo(uf, &gi);
        if (zerr == UNZ_OK){
            char* filename_inzip=calloc(1, kUnzipFileNameBuffer);
            unz_file_info file_info;
            do {
                zerr = unzGetCurrentFileInfo(uf, &file_info, filename_inzip, kUnzipFileNameBuffer-1, NULL, 0, NULL, 0);
                if(zerr!=UNZ_OK){
                    continue;
                }

                ++itemCount;
                int imgType=imageTypeWithFileName(filename_inzip);
                if(imgType != HTZQImageInvalid){
                    ++imageCount;
                }else{
                    ++nonImageCount;
                }
                
                if (!_zipSeemsContainApp && strstr(filename_inzip, ".app/Contents/Info.plist") && !strstr(filename_inzip, ".framework/")) {
                    _zipSeemsContainApp=YES;
                    self.appInfoPlistPath=[NSString stringWithUTF8String:filename_inzip];
                }

                if (itemCount<listLimit) {
                    [listData appendBytes:filename_inzip length:strlen(filename_inzip)];
                    [listData appendData:lf];
                }else{
                    ++remainCount;
                }

            } while (unzGoToNextFile(uf)==UNZ_OK);
            
            free(filename_inzip);

        }
        unzClose(uf);
    }
    
    if (remainCount>0) {
        NSString* remainString=[NSString stringWithFormat:@"\n... and more %lu items.\n", remainCount];
        NSData* remainStringData=[remainString dataUsingEncoding:NSUTF8StringEncoding];
        [listData appendData:remainStringData];
    }
    
    result=@{
        @"itemCount":@(itemCount),
        @"remainCount":@(remainCount),
        @"imageCount":@(imageCount),
        @"nonImageCount":@(nonImageCount),
        @"listData":listData,
    };
    
    return result;
}


- (NSData*)appIconData
{
    if (!self.zipSeemsContainApp) {
        return nil;
    }
    
    NSDictionary* appInfo=[self appInfoPlist];
    NSString* iconName=appInfo[@"CFBundleIconFile"];
    if ([iconName length]==0) {
        return nil;
    }
    
    if (![iconName hasSuffix:@".icns"]) {
        iconName=[iconName stringByAppendingString:@".icns"];
    }
    NSString* iconPath=[NSString stringWithFormat:@"Resources/%@", iconName];
    iconPath=[[self.appInfoPlistPath stringByDeletingLastPathComponent]stringByAppendingPathComponent:iconPath];
    NSData* iconData=[self dataForName:iconPath];
    
    return iconData;
}


- (NSDictionary*)appInfoPlist
{
    if (!self.zipSeemsContainApp) {
        return nil;
    }
    
    //初回のループで Info.plist まで到達していなかった
    if (!self.appInfoPlistPath) {
        _zipSeemsContainApp=NO;
        [self zipInformationWithListDataLimit:0];
    }
    
    if (!self.zipSeemsContainApp) {
        return nil;
    }
    
    NSData* plistData=[self dataForName:self.appInfoPlistPath];
    if (!plistData) {
        return nil;
    }
    NSDictionary* appInfo=[NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:nil error:nil];
    
    return appInfo;
}

#pragma mark -

// GeneratePreviewForURL()
- (void)generatePreview:(QLPreviewRequestRef)preview
{
    if ([self.contentTypeUTI isEqualToString:@"com.apple.itunes.ipa"]) {
        HZQIpaPreview* ipaPreview=[[HZQIpaPreview alloc]initWithZipItem:self];
        [ipaPreview generatePreview:preview];
    }else if ([self.contentTypeUTI isEqualToString:@"jp.hetima.zipquicklookgenerator.cvbdl"]) {
        HZQFolderPreview* folderPreview=[[HZQFolderPreview alloc]initWithZipItem:self];
        [folderPreview generatePreview:preview];
    }else{
        HZQZipPreview* zipPreview=[[HZQZipPreview alloc]initWithZipItem:self];
        [zipPreview generatePreview:preview];
    }
}


// GenerateThumbnailForURL()
- (void)generateThumbnail:(QLThumbnailRequestRef)thumbnail maxSize:(CGSize)maxSize;
{
    NSData* data;
    if ([self.contentTypeUTI isEqualToString:@"com.apple.itunes.ipa"]) {
        data=[self dataForName:@"iTunesArtwork"];
    }else if ([self.contentTypeUTI isEqualToString:@"jp.hetima.zipquicklookgenerator.cvbdl"]) {
        data=[self anyImageData];
    }else{
        data=[self anyImageData];
        if (self.zipSeemsContainApp) {
            NSData* appIcon=[self appIconData];
            if (appIcon)data=appIcon;
        }
    }
    
    if (data) {
        HZQImageAgent* imageAgent=[[HZQImageAgent alloc]initWithData:data];
        NSData* thumbnailData=[imageAgent thumbnailDataWithLabel:[self.path pathExtension] maxSize:maxSize];
        if (thumbnailData) {
            data=thumbnailData;
        }
        QLThumbnailRequestSetImageWithData(thumbnail, (__bridge CFDataRef)(data), NULL);
    }
    
}

@end
