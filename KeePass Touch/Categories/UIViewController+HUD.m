//
//  UIViewController+UIViewController_HUD.m
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 30.06.19.
//  Copyright © 2019 Self. All rights reserved.
//

#import "KPViewController.h"
#import <objc/runtime.h>


@implementation UIViewController(HUD)

#pragma mark - MBProgressHUD Class Extension Property

/// The accosicated object key
static char MINT_VIEWCONTROLLER_EXTENSION_HUD_PROPERTY;

/// Declare hud as dynamic variable
@dynamic hud;

/**
 @brief HUD setter
 */
-(void)setHud:(MBProgressHUD *)hud {
    objc_setAssociatedObject(self, &MINT_VIEWCONTROLLER_EXTENSION_HUD_PROPERTY, hud, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

/**
 @brief HUD getter
 */
-(MBProgressHUD *)hud {
    return (MBProgressHUD*)objc_getAssociatedObject(self, &MINT_VIEWCONTROLLER_EXTENSION_HUD_PROPERTY);
}

#pragma mark - Public APIs

-(void)showLoadingAnimation {
    [self showLoadingAnimation:nil subtitle:nil];
}

-(void)showLoadingAnimationWithGraceTime:(CGFloat)graceTime {
    [self showLoadingAnimation:nil subtitle:nil graceTime:graceTime];
}

-(void)showLoadingAnimation:(NSString *)title {
    [self showLoadingAnimation:title subtitle:nil];
}

-(void)showLoadingAnimation:(NSString *)title subtitle:(NSString *)subtitle {
    [self showLoadingAnimation:title subtitle:subtitle graceTime:0];
}

-(void)showLoadingAnimation:(NSString *)title subtitle:(NSString *)subtitle graceTime:(CGFloat)graceTime {
    // Initialize HUD
    MBProgressHUD *hud = [self getProgressHUD];
    // Set label
    hud.label.text = title;
    // Set detailsLabel
    hud.detailsLabel.text = subtitle;
    // Set graceTime
    hud.graceTime = graceTime;
    // Show HUD
    [hud showAnimated:YES];
}

-(void)showLoadingAnimationWithProgressAndTitle:(NSString *)title {
    // Initialize HUD
    MBProgressHUD *hud = [self getProgressHUD];
    // Set mode
    hud.mode = MBProgressHUDModeDeterminate;
    // Set label
    hud.label.text = title;
    // Show HUD
    [hud showAnimated:YES];
}

-(void)updateLoadingAnimationWithProgress:(float)progress {
    // Check if HUD is nil
    if(self.hud == nil) {
        // Return out of function
        return;
    }
    // Retrieve current HUD
    MBProgressHUD *hud = self.hud;
    // Check if mode is not Determinate
    if(hud.mode != MBProgressHUDModeDeterminate) {
        return;
    }
    // Set progress
    [hud setProgress:progress];
}

-(void)removeLoadingAnimation {
    // Check if hud is nil
    if (self.hud == nil) {
        // Return out of function
        return;
    }
    // Retrieve current HUD
    MBProgressHUD *hud = self.hud;
    // Hide HUD / Remove from SuperView automatically
    [hud hideAnimated:YES];
    // Clear HUD
    self.hud = nil;
}

#pragma mark - Public API Default implementation

-(UIView *)getViewForProgressHUD {
    return nil;
}

-(void)customizeHUD:(MBProgressHUD *)hud {}

#pragma mark - Private APIs

/**
 @brief Retrieve a MBProgressHUD object with base configurations
 */
-(MBProgressHUD *)getProgressHUD {
    // Check if an active HUD is loaded
    if (self.hud) {
        // Return loaded instance
        return self.hud;
    }
    // Initialize HUD View
    UIView *hudContainerView = [self getViewForProgressHUD] ? [self getViewForProgressHUD] : self.view;
    // Initialize MBProgressHUD with view
    self.hud = [[MBProgressHUD alloc] initWithView:hudContainerView];
    // Set Default GraceTime
    self.hud.graceTime = 0.5;
    // Set remove from superview on hide
    self.hud.removeFromSuperViewOnHide = YES;
    // Perform customization for hud
    [self customizeHUD:self.hud];
    // Add to hudContainerView
    [hudContainerView addSubview:self.hud];
    // Return HUD
    return self.hud;
}

@end
