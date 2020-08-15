//
//  FTPAddServerViewController.h
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 20.12.17.
//  Copyright © 2017 Self. All rights reserved.
//

#import "KPViewController.h"

@interface FTPAddServerViewController : KPViewController

@property(nonatomic, copy) void (^doneCompletion)(void);

@end
