//
//  Kdb3Persist.h
//  KeePass2
//
//  Created by Qiang Yu on 2/16/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import "Kdb3Node.h"
#import "KdbWriter.h"
#import <Foundation/Foundation.h>

@interface Kdb3Writer : NSObject <KdbWriter> {
  NSData *masterSeed;
  NSData *encryptionIv;
  NSData *transformSeed;
  kdb3_header_t header;
  BOOL firstGroup;
}

@end
