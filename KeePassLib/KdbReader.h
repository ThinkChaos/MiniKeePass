//
//  KdbReader.h
//  KeePass2
//
//  Created by Qiang Yu on 3/6/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import "InputStream.h"
#import "Kdb.h"
#import "KdbPassword.h"
#import <Foundation/Foundation.h>

@protocol KdbReader <NSObject>
- (KdbTree *)load:(InputStream *)inputStream
     withPassword:(KdbPassword *)kdbPassword;
@end
