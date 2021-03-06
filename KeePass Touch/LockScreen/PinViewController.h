/*
 * Copyright 2017-2019 Innervate UG & Co. KG. All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <UIKit/UIKit.h>

@protocol PinViewControllerDelegate;

@interface PinViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, copy) UILabel *textLabel;
@property (nonatomic, assign) id<PinViewControllerDelegate> delegate;

- (void)clearEntry;

@end

@protocol PinViewControllerDelegate <NSObject>
- (void)pinViewController:(PinViewController *)controller pinEntered:(NSString*)pin;
@optional
//- (void)pinViewController:(PinViewController *)controller touchIDEntered:(BOOL)success;
- (void)pinViewControllerDidShow:(PinViewController *)controller;
@end
