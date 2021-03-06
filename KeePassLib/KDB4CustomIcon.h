//
//  KDB4CustomIcon.h
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 24.03.15.
//  Copyright (c) 2015 Self. All rights reserved.
//

#import "Kdb.h"
#import "UUID.h"
#import <Foundation/Foundation.h>

@interface KDB4CustomIcon : NSObject

@property(nonatomic, strong) KdbUUID *uuid;
@property(nonatomic, copy) NSString *data;

@end
