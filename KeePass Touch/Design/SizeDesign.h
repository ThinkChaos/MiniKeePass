//
//  SizeDesign.h
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 21.12.17.
//  Copyright © 2017 Self. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SizeDesign : NSObject


#define IS_IPHONE        (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_IPHONE_X      (IS_IPHONE && \
( \
(int)[[UIScreen mainScreen] nativeBounds].size.height == 2436 || \
(int)[[UIScreen mainScreen] nativeBounds].size.height == 2688 || \
(int)[[UIScreen mainScreen] nativeBounds].size.height == 1792 \
) \
)


#define NAV_BAR_HEIGHT (IS_IPHONE_X ? 89.0f : 45.0f)

#define IPHONE_X_TOPSPACING (IS_IPHONE_X ? 33.0f : 0.f)

#define IPHONE_X_NAVBAR_DIFF (IS_IPHONE_X ? 44.0f : 0.f)

+(double)getTopSpace;
+(double)getElementSpace;
+(double)getEdgeSpace;


@end
