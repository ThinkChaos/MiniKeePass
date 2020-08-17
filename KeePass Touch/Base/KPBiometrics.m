//
//  KPBiometrics.m
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 30.06.19.
//  Copyright © 2019 Self. All rights reserved.
//

#import "KPBiometrics.h"
#import <LocalAuthentication/LocalAuthentication.h>
@implementation KPBiometrics

+ (BOOL)hasBiometrics {
    NSError *error = nil;
    LAContext *context = [[LAContext alloc] init];
    return [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error];    
}

+ (void)authenticateViaBiometricsWithSuccess:(void (^) (void))success
                                     failure:(void (^) (NSError *error))failure {
    NSError *error = nil;
    LAContext *context = [[LAContext alloc] init];
    if([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                localizedReason:NSLocalizedString(@"Decrypt Database", nil)
                          reply:^(BOOL successful, NSError * _Nullable error) {
                              if(successful)
                              {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      if(success)
                                          success();
                                  });
                              }
                              else if(error)
                              {
                                  if(error.code == kLAErrorBiometryLockout) {
                                      [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
                                              localizedReason:NSLocalizedString(@"Biometry is currently locked out, enter passcode to unlock", nil) reply:^(BOOL successful, NSError * _Nullable error) {
                                                  if(success) {
                                                      [self authenticateViaBiometricsWithSuccess:success failure:failure];
                                                  }
                                                  else {
                                                      // Ignore user cancel
                                                      if(error.code != LAErrorUserCancel) {
                                                          dispatch_async(dispatch_get_main_queue(), ^{
                                                              failure(error);
                                                          });
                                                      }
                                                  }
                                              }];
                                  }
                                  else if(error.code != LAErrorUserCancel) {
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          if(failure)
                                              failure(error);
                                      });
                                  }
                              }
                              else
                              {
                                  NSError *error = [NSError errorWithTitle:@"Unknown Touch ID Error" errorMessage:@"An Unknown error occured"];
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      if(failure)
                                          failure(error);
                                  });
                              }
                          }];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if(failure)
                failure(error);
        });
    }

}

+(BOOL)supportFaceID
{
    if (@available(iOS 11.0, *)) {
        LAContext *myContext = [[LAContext alloc] init];
        NSError *authError = nil;
        // call this method only to get the biometryType and we don't care about the result!
        [myContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&authError];
        return myContext.biometryType == LABiometryTypeFaceID;
    } else {
        // Device is running on older iOS version and OFC doesn't have FaceID
        return NO;
    }
}

@end
