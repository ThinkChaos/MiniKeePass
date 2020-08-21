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

#import <Foundation/Foundation.h>

#import "ImageSelectionViewController.h"
#import "KdbLib.h"
#import "KeePassTouchAppDelegate.h"
#import "PasswordFieldCell.h"
#import "PasswordGeneratorViewController.h"
#import "StringFieldViewController.h"
#import "TextFieldCell.h"
#import "TextViewCell.h"
#import "TitleFieldCell.h"
#import "UrlFieldCell.h"

@interface EntryViewController
    : UITableViewController <
          UIGestureRecognizerDelegate, ImageSelectionViewDelegate,
          PasswordGeneratorDelegate, TitleFieldCellDelegate,
          TextFieldCellDelegate, UIDocumentInteractionControllerDelegate>

@property(nonatomic, assign) NSUInteger selectedImageIndex;
@property(nonatomic, strong) KdbEntry *entry;
@property(nonatomic, strong) NSString *temporaryFileAttachmentPath;
@property(nonatomic) BOOL isNewEntry;
@property(nonatomic) NSString *searchKey;

@end
