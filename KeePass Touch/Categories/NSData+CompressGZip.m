//
//  NSData+CompressGZip.m
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 26.08.18.
//  Copyright © 2018 Self. All rights reserved.
//

#import "NSData+CompressGZip.h"
#include <zlib.h>

@implementation NSData (Compression)


- (NSData *)decompressedData {
    if (self.length == 0) {
        return self;
    }
    
    z_stream strm;
    strm.next_in = (Bytef *)self.bytes;
    strm.avail_in = (uInt)self.length;
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if (inflateInit2(&strm, (15+32)) != Z_OK) {
        return nil;
    }
    
    NSUInteger full_length = self.length;
    NSUInteger half_length = self.length / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength:(full_length + half_length)];
    BOOL done = NO;
    int status;
    
    while(!done) {
        // Make sure we have enough room and reset the lengths.
        if (strm.total_out >= decompressed.length) {
            [decompressed increaseLengthBy: half_length];
        }
        
        strm.next_out = decompressed.mutableBytes + strm.total_out;
        strm.avail_out = (uInt)(decompressed.length - strm.total_out);
        
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) done = YES;
        else if (status != Z_OK) break;
    }
    
    if(inflateEnd (&strm) != Z_OK) {
        return nil;
    }
    
    // Set real length.
    if(done) {
        decompressed.length = strm.total_out;
        return [NSData dataWithData:decompressed];
    }
    else {
        return nil;
    }
}


- (NSData *)compressedData {
    if(self.length == 0) {
        return self;
    }
    
    z_stream strm;
    
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.total_out = 0;
    strm.next_in=(Bytef *)self.bytes;
    strm.avail_in = (uInt)self.length;
    
    // Compresssion Levels:
    //   Z_NO_COMPRESSION
    //   Z_BEST_SPEED
    //   Z_BEST_COMPRESSION
    //   Z_DEFAULT_COMPRESSION
    
    NSUInteger returnCode = deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY);
    if(returnCode != Z_OK) {
        return nil;
    }
    
    // 16K chunks for expansion
    NSMutableData *compressed = [NSMutableData dataWithLength:(16*1024)];
    
    do {
        
        if(strm.total_out >= compressed.length) {
            [compressed increaseLengthBy:(16*1024)];
        }
        
        strm.next_out = compressed.mutableBytes + strm.total_out;
        strm.avail_out = (uInt)(compressed.length - strm.total_out);
        
        deflate(&strm, Z_FINISH);
        
    } while(strm.avail_out == 0);
    
    deflateEnd(&strm);
    
    compressed.length = strm.total_out;
    return [NSData dataWithData:compressed];
}



@end
