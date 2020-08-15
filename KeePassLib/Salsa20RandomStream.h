//
//  Salsa20RandomStream.h
//  KeePass2
//
//  Created by Qiang Yu on 2/28/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import "BlockCipher.h"
#import "RandomStream.h"
#import <Foundation/Foundation.h>

@interface Salsa20RandomStream : RandomStream {
  BlockCipher *cipher;
}

- (id)init;
- (id)init:(NSData *)key;

@end
