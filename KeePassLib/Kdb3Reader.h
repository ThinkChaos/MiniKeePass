//
//   Kdb3.h
//   KeePass
//
//   Created by Qiang Yu on 11/22/09.
//   Copyright 2009 Qiang Yu. All rights reserved.
//

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>

#import "Kdb3Node.h"
#import "KdbReader.h"

@interface Kdb3Reader : NSObject <KdbReader> {
  NSData *masterSeed;
  NSData *encryptionIv;
  uint32_t numGroups;
  uint32_t numEntries;
  NSData *contentsHash;
  NSData *masterSeed2;
  uint32_t keyEncRounds;
  uint32_t headerFlags;
  NSData *headerHash;
  NSMutableArray *levels;
  NSMutableArray *groups;
  NSMutableArray *entries;
}

@end
