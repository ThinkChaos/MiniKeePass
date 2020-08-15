//
//  NSData+CompressGZip.h
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 26.08.18.
//  Copyright © 2018 Self. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Compression)

/**
 The data as a Gzip decompressed copy of the receivers contents.
 */
@property (nonatomic, readonly, copy) NSData *decompressedData;
/**
 The data as a Gzip compressed copy of the receivers contents.
 */
@property (nonatomic, readonly, copy) NSData *compressedData;

@end
