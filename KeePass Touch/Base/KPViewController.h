//
//  KPViewController.h
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 20.12.17.
//  Copyright © 2017 Self. All rights reserved.
//

#import "SizeDesign.h"
#import "UIView+Layout.h"
#import "MBProgressHUD.h"

#pragma mark - HUD

@interface UIViewController(HUD)

@property (nonatomic, retain) MBProgressHUD *hud;

/**
 @brief Return custom view to present HUD
 */
-(UIView *)getViewForProgressHUD;

/**
 @brief Customize HUD
 */
-(void)customizeHUD:(MBProgressHUD *)hud;

/**
 *Shows a HUD without a title.
 */
-(void)showLoadingAnimation;

/**
 * Shows a HUD with a title.
 *@param graceTime Grace period is the time (in seconds) that the invoked method may be run without showing the HUD.
 */
-(void)showLoadingAnimationWithGraceTime:(CGFloat)graceTime;

/**
 *Shows a HUD with a title.
 *@param title  The HUD will show this title.
 */
-(void)showLoadingAnimation:(NSString *)title;

/**
 *Shows a HUD with a title and a subtitle.
 *@param title The HUD will show this title.
 *@param subtitle The HUD will show this subtitle.
 */
-(void)showLoadingAnimation:(NSString *)title subtitle:(NSString *)subtitle;

/**
 *Shows a HUD with a title and a subtitle.
 *@param title The HUD will show this title.
 *@param subtitle The HUD will show this subtitle.
 *@param graceTime Grace period is the time (in seconds) that the invoked method may be run without showing the HUD.
 */
-(void)showLoadingAnimation:(NSString *)title subtitle:(NSString *)subtitle graceTime:(CGFloat)graceTime;

/**
 *Shows a HUD with a title and a subtitle.
 *@param title The HUD will show this title.
 */
-(void)showLoadingAnimationWithProgressAndTitle:(NSString *)title;

/**
 * Updates the loading animation progress. If hud internally is nil, nothing happens.
 *@param progress The progress as a float from 0.0 to 1.0
 */
- (void)updateLoadingAnimationWithProgress:(float)progress;

/**
 * @brief Removes the HUD from the screen.
 */
-(void)removeLoadingAnimation;

@end



@interface KPViewController : UIViewController

#pragma mark - MessageBar

/**
 *Shows a message that shows an error. This error information contains a title and a description.
 *@param title The message will contain this title.
 *@param description The message will contain this description.
 */
-(void)showErrorMessage:(NSString *)title description:(NSString *)description;

/**
 *Shows a message that shows an error. This error information contains a title and a description.
 *@param title The message will contain this title.
 *@param description The message will contain this description.
 *@param duration The duration the ErrorMessage will be shown
 */
-(void)showErrorMessage:(NSString *)title description:(NSString *)description duration:(double)duration;

/**
 *Shows a message with a success information containing a title and a description.
 *@param title The message will contain this title.
 *@param description The message will contain this description.
 */
-(void)showSuccessMessage:(NSString *)title description:(NSString *)description;

/**
 *Shows a message with a success information containing a title and a description.
 *@param title The message will contain this title.
 *@param description The message will contain this description.
 *@param duration The duration the message will be shown
 */
-(void)showSuccessMessage:(NSString *)title description:(NSString *)description duration:(double)duration;

/**
 *Shows a message containing a title and a description.
 *@param title The message will contain this title.
 *@param description The message will contain this description.
 */
-(void)showInfoMessage:(NSString *)title description:(NSString *)description;

/**
 *Shows a message containing a title and a description.
 *@param title The message will contain this title.
 *@param description The message will contain this description.
 *@param duration The duration the InfoMessage will be shown
 */
-(void)showInfoMessage:(NSString *)title description:(NSString *)description duration:(double)duration;


@end

#pragma mark - KPAlert

@interface UIViewController(KPAlert)

-(void)showAlertWithTitle:(NSString*)title message:(NSString*)message;

-(void)showAlertWithTitle:(NSString*)title message:(NSString*)message completion:(void (^) (void))completion;

-(void)showAlertFromError:(NSError*)error completion:(void (^) (void))completion;

-(void)showAlertFromError:(NSError*)error;

@end
