//
//  KPBiometrics.h
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 30.06.19.
//  Copyright © 2019 Self. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KPBiometrics : NSObject

/// return YES, if TouchID / FaceID is present
+ (BOOL)hasBiometrics;

/** Authenticates the user via Touch ID or FaceID (whatever present)
 * success The success block called if the user is authenticated
 * failure The failure block with the error from authentication
 */
+ (void)authenticateViaBiometricsWithSuccess:(void (^) (void))success
                                     failure:(void (^) (NSError *error))failure;


/// returns if the device has FaceID
+(BOOL)supportFaceID;

@end

