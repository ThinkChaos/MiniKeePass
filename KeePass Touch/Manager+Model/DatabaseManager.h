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
#import "FormViewController.h"

@class DatabaseDocument;

@interface DatabaseManager : NSObject

/// A string containing the name of the KeePass DatabaseDocument to be managed
@property (nonatomic, copy) NSString *selectedFilename;

/// Create a DatabaseManager instance
+ (DatabaseManager*)sharedInstance;

/*** Open the specified KeePass DatabaseDocument
 @param filePath the full filepath of the chosen KeePass DatabaseDocument
 @param success the success block, giving the document if needed
 @param failure the failure block, in case anything fails
*/
- (void)openDatabaseDocument:(NSString*)filePath
                     success:(void (^) (DatabaseDocument *doc))success
                     failure:(void (^) (NSError *error))failure;

@end
