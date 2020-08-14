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

#import "KeePassTouchAppDelegate.h"
#import "AppSettings.h"
#import "EntryViewController.h"
#import "GroupViewController.h"
#import "KeychainUtils.h"
#import "LockScreenController.h"
#import "SettingsViewController.h"
#import "UIView+Layout.h"
#import "WebViewController.h"
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>

#define APP_KEY @"35en533x9e3johe"
#define APP_SECRET @"tnakqwsic649thr"

#import "constants.h"

@import Firebase;
@import Crashlytics;

@interface KeePassTouchAppDelegate () {
  AppSettings *appSettings;
}
@end

@implementation KeePassTouchAppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

  // initialize firebase
  [FIRApp configure];

  _databaseDocument = nil;

  // Create the files view
  self.filesViewController =
      [[FilesViewController alloc] initWithStyle:UITableViewStylePlain];

  // initialize appsettings
  appSettings = [AppSettings sharedInstance];

  self.navigationController = [[UINavigationController alloc]
      initWithRootViewController:self.filesViewController];
  self.navigationController.toolbarHidden = NO;

  BOOL willPerformMigration = [DBClientsManager
      checkAndPerformV1TokenMigration:^(
          BOOL shouldRetry, BOOL invalidAppKeyOrSecret,
          NSArray<NSArray<NSString *> *> *unsuccessfullyMigratedTokenData) {
        if (invalidAppKeyOrSecret) {
          // Developers should ensure that the appropriate app key and secret
          // are being supplied. If your app has multiple app keys / secrets,
          // then run this migration method for each app key / secret
          // combination, and ignore this boolean.
        }

        if (shouldRetry) {
          // Store this BOOL somewhere to retry when network connection has
          // returned
        }

        if ([unsuccessfullyMigratedTokenData count] != 0) {
          NSLog(@"The following tokens were unsucessfully migrated:");
          for (NSArray<NSString *>
                   *tokenData in unsuccessfullyMigratedTokenData) {
            NSLog(@"DropboxUserID: %@, AccessToken: %@, AccessTokenSecret: %@, "
                  @"StoredAppKey: %@",
                  tokenData[0], tokenData[1], tokenData[2], tokenData[3]);
          }
        }

        if (!invalidAppKeyOrSecret && !shouldRetry &&
            [unsuccessfullyMigratedTokenData count] == 0) {
          [DBClientsManager setupWithAppKey:APP_KEY];
        }
      }
                                queue:nil
                               appKey:APP_KEY
                            appSecret:APP_SECRET];

  if (!willPerformMigration) {
    [DBClientsManager setupWithAppKey:APP_KEY];
  }

  // Create the window
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  self.window.rootViewController = self.navigationController;
  [self.window makeKeyAndVisible];

  // Add a pasteboard notification listener to support clearing the clipboard
  NSNotificationCenter *notificationCenter =
      [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self
                         selector:@selector(handlePasteboardNotification:)
                             name:UIPasteboardChangedNotification
                           object:nil];

  // Check file protection
  [self checkFileProtection];

  [LockScreenController present];

  return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  if (!self.locked) {
    [LockScreenController present];
    NSDate *currentTime = [NSDate date];
    [appSettings setExitTime:currentTime];
  }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  NSLog(@"ApplicationWillEnterForeGround");
  // Check file protection
  [self checkFileProtection];
  // Get the time when the application last exited
  NSDate *exitTime = [appSettings exitTime];

  // Check if closing the database is enabled
  if ([appSettings closeEnabled] && exitTime != nil) {
    // Get the lock timeout (in seconds)
    NSInteger closeTimeout = [appSettings closeTimeout];

    // Check if it's been longer then lock timeout
    NSTimeInterval timeInterval = [exitTime timeIntervalSinceNow];
    if (timeInterval < -closeTimeout) {
      [self closeDatabase];
    }
  }

#warning FIND correct way to show popup after lockscreen etc.
  if ([self.navigationController.topViewController
          isKindOfClass:[FilesViewController class]] &&
      [[NSUserDefaults standardUserDefaults] stringForKey:@"DropboxPath"] !=
          nil)
    [(FilesViewController *)
            self.navigationController.topViewController syncDropbox];
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:
                (NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
  if ([[url description] hasPrefix:@"kptouch://"]) {
    NSString *checkFor = [url host];
    if (checkFor != nil) {
      NSInteger num =
          [self.filesViewController.tableView numberOfRowsInSection:0];
      for (int i = 0; i < num; i++) {
        NSUInteger indexes[] = {0, i};
        NSIndexPath *ip = [NSIndexPath indexPathWithIndexes:indexes length:2];
        NSString *cellText =
            [self.filesViewController.tableView cellForRowAtIndexPath:ip]
                .textLabel.text;
        cellText = (NSString *)[[cellText componentsSeparatedByString:@"."]
            objectAtIndex:0];
        checkFor = (NSString *)[[checkFor componentsSeparatedByString:@"."]
            objectAtIndex:0];
        if ([cellText compare:checkFor
                      options:NSCaseInsensitiveSearch] == NSOrderedSame) {
          [self.filesViewController openDatabaseWithFilename:cellText];
        }
      }
    }

  } else if ([[url description] hasPrefix:@"file://"]) {
    // Get the filename
    NSString *filename = [url lastPathComponent];

    // Get the full path of where we're going to move the file
    NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];
    NSString *path =
        [documentsDirectory stringByAppendingPathComponent:filename];

    // Move input file into documents directory
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
      if (isDirectory) {
        // Should not have been passed a directory
        return NO;
      } else {
        [fileManager removeItemAtPath:path error:nil];
      }
    }
    // copy item to local url
    [fileManager copyItemAtURL:url
                         toURL:[NSURL fileURLWithPath:path]
                         error:nil];

    // Set file protection on the new file
    [fileManager setAttributes:@{NSFileProtectionKey : NSFileProtectionComplete}
                  ofItemAtPath:path
                         error:nil];

    // Delete the Inbox folder if it exists
    [fileManager removeItemAtPath:[documentsDirectory
                                      stringByAppendingPathComponent:@"Inbox"]
                            error:nil];

    [self.filesViewController updateFiles];
    [self.filesViewController.tableView reloadData];
  }

  DBOAuthResult *authResult = [DBClientsManager handleRedirectURL:url];
  if (authResult != nil) {
    if ([authResult isSuccess]) {
      NSLog(@"Success! User is logged into Dropbox.");
      [[NSNotificationCenter defaultCenter]
          postNotificationName:@"dropboxLinked"
                        object:nil];
    } else if ([authResult isCancel]) {
      // ignore, user cancelled manually
    } else if ([authResult isError]) {
#warning self.filesviewcontroller showerror needed here (show AlertController) not showErrorMessage (TWMessageBar)
      UIAlertController *errorAlert = [UIAlertController
          alertControllerWithTitle:NSLocalizedString(@"Error", nil)
                           message:[NSString
                                       stringWithFormat:@"Dropbox Error: %@",
                                                        authResult
                                                            .errorDescription]
                    preferredStyle:IS_IPAD ? UIAlertControllerStyleAlert
                                           : UIAlertControllerStyleActionSheet];

      [self.filesViewController presentViewController:errorAlert
                                             animated:YES
                                           completion:nil];
    }
    return YES;
  }
  return YES;
}

+ (KeePassTouchAppDelegate *)appDelegate {
  return (KeePassTouchAppDelegate *)[[UIApplication sharedApplication]
      delegate];
}

+ (NSString *)documentsDirectory {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                       NSUserDomainMask, YES);
  return [paths objectAtIndex:0];
}

- (void)setDatabaseDocument:(DatabaseDocument *)newDatabaseDocument {
  if (_databaseDocument != nil) {
    [self closeDatabase];
  }

  _databaseDocument = newDatabaseDocument;

  // Create and push on the root group view controller
  GroupViewController *groupViewController = [[GroupViewController alloc]
      initWithGroup:_databaseDocument.kdbTree.root];
  groupViewController.title = [[_databaseDocument.filename lastPathComponent]
      stringByDeletingPathExtension];

  [self.navigationController pushViewController:groupViewController
                                       animated:YES];
}

- (UINavigationController *)currentNavigationController {
  return self.navigationController;
}

- (void)closeDatabase {
  // Close any open database views
  [self.navigationController popToRootViewControllerAnimated:NO];
  _databaseDocument = nil;
}

- (void)deleteKeychainData {
  // Reset some settings
  [appSettings setPinFailedAttempts:0];
  [appSettings setPinEnabled:NO];
  [appSettings setTouchIDEnabled:NO];

  // Delete the PIN from the keychain
  [KeychainUtils deleteStringForKey:KPT_PIN_KEY andServiceName:KPT_PIN_SERVICE];

  // Delete all database passwords, keyfiles and ftp login data from the
  // keychain
  [KeychainUtils deleteAllForServiceName:KPT_PASSWORD_SERVICE];
  [KeychainUtils deleteAllForServiceName:KPT_KEYFILES_SERVICE];
  [KeychainUtils deleteAllForServiceName:KPT_FTP_SERVICE];
}

- (void)deleteAllData {
  // Close the current database
  [self closeDatabase];

  // Delete data stored in system keychain
  [self deleteKeychainData];

  // Get the files in the Documents directory
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];

  NSArray *files = [fileManager contentsOfDirectoryAtPath:documentsDirectory
                                                    error:nil];

  // Delete all the files in the Documents directory
  for (NSString *file in files) {
    [fileManager removeItemAtPath:[documentsDirectory
                                      stringByAppendingPathComponent:file]
                            error:nil];
  }

  // Clear Group Directory
  NSURL *groupURL = [fileManager
      containerURLForSecurityApplicationGroupIdentifier:@"group.keepass-touch"];
  NSArray *grpfiles =
      [fileManager contentsOfDirectoryAtPath:groupURL.absoluteString error:nil];
  for (NSString *file in grpfiles) {
    [fileManager removeItemAtPath:[groupURL.absoluteString
                                      stringByAppendingPathComponent:file]
                            error:nil];
  }
}

- (void)checkFileProtection {
  // Get the document's directory
  NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];

  // Get the contents of the documents directory
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *dirContents =
      [fileManager contentsOfDirectoryAtPath:documentsDirectory error:nil];

  // Check all files to see if protection is enabled
  for (NSString *file in dirContents) {
    if (![file hasPrefix:@"."]) {
      NSString *path = [documentsDirectory stringByAppendingPathComponent:file];

      BOOL dir = NO;
      [fileManager fileExistsAtPath:path isDirectory:&dir];
      if (!dir) {
        // Make sure file protecten is turned on
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:path
                                                                 error:nil];
        NSString *fileProtection = [attributes valueForKey:NSFileProtectionKey];
        if (![fileProtection isEqualToString:NSFileProtectionComplete]) {
          [fileManager
              setAttributes:@{NSFileProtectionKey : NSFileProtectionComplete}
               ofItemAtPath:path
                      error:nil];
        }
      }
    }
  }
}

- (void)handlePasteboardNotification:(NSNotification *)notification {
  // Check if the clipboard has any contents
  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  if (pasteboard.string == nil || [pasteboard.string isEqualToString:@""]) {
    return;
  }

  // Check if the clearing the clipboard is enabled
  if ([appSettings clearClipboardEnabled]) {
    // Get the "version" of the pasteboard contents
    NSInteger pasteboardVersion = pasteboard.changeCount;

    // Get the clear clipboard timeout (in seconds)
    NSInteger clearClipboardTimeout = [appSettings clearClipboardTimeout];

    UIApplication *application = [UIApplication sharedApplication];

    // Initiate a background task
    __block UIBackgroundTaskIdentifier bgTask;
    bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
      // End the background task
      [application endBackgroundTask:bgTask];
    }];

    // Start the long-running task and return immediately.
    dispatch_async(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          // Sleep until it's time to clean the clipboard
          [NSThread sleepForTimeInterval:clearClipboardTimeout];
          UIPasteboard *pasteBoardRefeteched = [UIPasteboard generalPasteboard];
          // Clear the clipboard if it hasn't changed
          if (pasteboardVersion == pasteBoardRefeteched.changeCount) {
            pasteBoardRefeteched.string = @"";
          }

          // End the background task
          [application endBackgroundTask:bgTask];
        });
  }
}

- (void)showSettingsView {
  SettingsViewController *settingsViewController =
      [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];

  UIBarButtonItem *doneButton = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                           target:self
                           action:@selector(dismissSettingsView)];
  settingsViewController.navigationItem.rightBarButtonItem = doneButton;

  UINavigationController *settingsNavController =
      [[UINavigationController alloc]
          initWithRootViewController:settingsViewController];

  [self.window.rootViewController presentViewController:settingsNavController
                                               animated:YES
                                             completion:nil];
}

- (void)dismissSettingsView {
  [self.window.rootViewController dismissViewControllerAnimated:YES
                                                     completion:nil];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
}

@end
