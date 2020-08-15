//
//  UIViewController+Alert.m
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 30.07.19.
//  Copyright © 2019 Self. All rights reserved.
//

#import "KPViewController.h"

@implementation UIViewController(KPAlert)

-(void)showAlertWithTitle:(NSString*_Nullable)title message:(NSString*_Nullable)message {
    [self showAlertWithTitle:title message:message completion:nil];
}

-(void)showAlertWithTitle:(NSString*_Nullable)title message:(NSString*_Nullable)message completion:(void (^_Nullable) (void))completion {
    [self removeLoadingAnimation];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (completion) {
                completion();
            }
        }];
        [alertController addAction:confirmAction];
        [self presentViewController:alertController animated:YES completion:nil];
    });
}

-(void)showAlertFromError:(NSError* _Nonnull )error completion:(void (^_Nullable) (void))completion {
    [self showAlertWithTitle:error.errorTitle message:error.errorMessage completion:completion];
}

-(void)showAlertFromError:(NSError* _Nonnull )error {
    [self showAlertFromError:error completion:nil];
}

@end
