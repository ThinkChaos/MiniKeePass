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

#import "FilesInfoView.h"
#import "FilesUploadDelegate.h"
#import "GCDWebUploader.h"
#import "NewKdbViewController.h"
#import "TextEntryController.h"
#import <Foundation/Foundation.h>
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>

@class KeePassTouchAppDelegate;

@interface FilesViewController
    : UITableViewController <GCDWebUploaderDelegate,
                             UIPopoverPresentationControllerDelegate>

- (void)updateFiles;
- (void)reloadTableViewData;
- (void)openDatabaseWithFilename:(NSString *)filename;
- (void)syncDropbox;

@property(nonatomic, strong) DBUserClient *userClient;
@property(nonatomic, strong) NSArray<DBFILESFileMetadata *> *collisionArray;
@property(nonatomic, strong) NSMutableArray *databaseFiles;
@property(nonatomic, readonly) void (^showError)(NSError *error);

@end
