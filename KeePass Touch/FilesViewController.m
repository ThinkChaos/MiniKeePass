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

#import "FilesViewController.h"
#import "AppSettings.h"
#import "DatabaseManager.h"
#import "DropboxFolderController.h"
#import "DropboxManager.h"
#import "HelpViewController.h"
#import "KPViewController.h"
#import "Kdb3Writer.h"
#import "Kdb4Writer.h"
#import "KeePassTouchAppDelegate.h"
#import "KeychainUtils.h"
#import "MBProgressHUD.h"
#import "NSArray+Additions.h"
#import "NewKdbViewController.h"

#import "constants.h"

enum { SECTION_DATABASE, SECTION_KEYFILE, SECTION_NUMBER };

@interface FilesViewController () <DropboxManagerDelegate,
                                   UIDocumentPickerDelegate> {
  unsigned long currentFile;
  unsigned long allFiles;

  NSMutableArray *keyFiles;
  NSArray *_localUniques;
  NSArray *_dropboxUniques;

  FilesInfoView *filesInfoView;
  KeePassTouchAppDelegate *appDelegate;
  GCDWebUploader *webUploader;
  UIBarButtonItem *syncButton;
  UIBarButtonItem *addButton;
  UILabel *footerLabel;
  BOOL isUploading;
  BOOL initialOpen;
}
@end

@implementation FilesViewController

#pragma mark - View and Init Methods

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
  appDelegate = [KeePassTouchAppDelegate appDelegate];

  if (![[NSUserDefaults standardUserDefaults] boolForKey:@"LaunchOne"]) {

    // This is the first launch ever

    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"LaunchOne"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    UIAlertController *alertCon = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"Welcome", nil)
                         message:NSLocalizedString(
                                     @"Thank you for using KeePass Touch! \n\n "
                                     @"If you like what we are doing with "
                                     @"KeePass on iOS, please consider "
                                     @"removing the ads in the app for a small "
                                     @"fee to support our cause to make a "
                                     @"great KeePass iOS Experience! \n Just "
                                     @"go to Settings -> Remove Ads.",
                                     nil)
                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction =
        [UIAlertAction actionWithTitle:@"OK"
                                 style:UIAlertActionStyleCancel
                               handler:nil];
    [alertCon addAction:cancelAction];
    [self presentViewController:alertCon animated:YES completion:nil];
  }

  self.title = NSLocalizedString(@"Files", nil);
  self.tableView.allowsSelectionDuringEditing = YES;
  self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
  initialOpen = YES;
  UIBarButtonItem *settingsButton =
      [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear"]
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(showSettingsView)];

  // Button for all syncing
  syncButton =
      [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"sync"]
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(syncPressed)];

  UIBarButtonItem *helpButton =
      [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"help"]
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(helpPressed)];

  addButton = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                           target:self
                           action:@selector(addPressed)];

  UIBarButtonItem *spacer = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                           target:nil
                           action:nil];
  NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];
  webUploader =
      [[GCDWebUploader alloc] initWithUploadDirectory:documentsDirectory];
  webUploader.delegate = self;
  webUploader.allowedFileExtensions =
      [NSArray arrayWithObjects:@"kdbx", @"kdb", @"key", nil];

  self.toolbarItems =
      [NSArray arrayWithObjects:settingsButton, spacer, syncButton, spacer,
                                helpButton, spacer, addButton, nil];
  self.navigationItem.rightBarButtonItem = self.editButtonItem;

  footerLabel = [[UILabel alloc] init];
  footerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  footerLabel.font = [UIFont systemFontOfSize:12.0f];
  footerLabel.backgroundColor = [UIColor clearColor];
  footerLabel.numberOfLines = 0;
  footerLabel.textAlignment = NSTextAlignmentCenter;
  footerLabel.textColor = [UIColor lightGrayColor];

  CGFloat bottomLabelSpace = 35.0f;
  if (@available(iOS 11.0, *)) {
    bottomLabelSpace += [[[UIApplication sharedApplication] delegate] window]
                            .safeAreaInsets.bottom;
  }

  footerLabel.frame =
      CGRectMake(0,
                 self.view.bounds.size.height -
                     self.navigationController.toolbar.frame.size.height -
                     self.navigationController.navigationBar.frame.size.height -
                     bottomLabelSpace,
                 self.tableView.bounds.size.width, 30.0f);

  if ([[NSUserDefaults standardUserDefaults] stringForKey:@"DropboxPath"] !=
      nil) {
    [self syncDropbox];
  } else {
    [self showAutoFillPopupInfo];
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self updateFiles];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(syncDropbox)
                                               name:@"DROPBOX_SYNC_NOTIFICATION"
                                             object:nil];

  NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

  [self.tableView reloadData];

  if (selectedIndexPath != nil) {
    [self.tableView selectRowAtIndexPath:selectedIndexPath
                                animated:NO
                          scrollPosition:UITableViewScrollPositionNone];
  }
  NSInteger databaseNum = [[AppSettings sharedInstance] defaultDatabase] - 1;
  BOOL pinEnabled = [[AppSettings sharedInstance] pinEnabled];
  if (databaseNum >= 0 && initialOpen && !pinEnabled) {
    initialOpen = NO;
    [self tableView:self.tableView
        didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:databaseNum
                                                   inSection:SECTION_DATABASE]];
  }
}

- (void)viewWillLayoutSubviews {
  [super viewWillLayoutSubviews];
  // Adjust the frame of the filesInfoView to make sure it fills the screen
  filesInfoView.frame = self.view.bounds;
}

#warning MOVE THIS TO BASIC TABLE VIEW CONTROLLER

/**
 @brief Block to be used when removing the loading animation and display an
 alert with this error<br>
 */
- (void (^)(NSError *error))showError {
  void (^_Nonnull ret)(NSError *_Nullable error) = ^(NSError *err) {
    if (!err)
      [self removeLoadingAnimation];
    else {
      [self showAlertFromError:err
                    completion:^{
                      NSIndexPath *selPath =
                          self.tableView.indexPathForSelectedRow;
                      if (selPath)
                        [self.tableView deselectRowAtIndexPath:selPath
                                                      animated:YES];
                    }];
    }
  };
  return ret;
}

- (void)showErrorOnHud:(NSError *)error {
  MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
  hud.mode = MBProgressHUDModeCustomView;
  hud.label.text = NSLocalizedString(@"Error", nil);
  hud.customView =
      [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"check_red"]];
  hud.detailsLabel.text = [error localizedDescription];
  [[NSUserDefaults standardUserDefaults] setObject:error.description
                                            forKey:@"LastError"];
  [[NSUserDefaults standardUserDefaults] setObject:@(error.code)
                                            forKey:@"LastErrorCode"];
  [hud hideAnimated:YES afterDelay:2.5f];
}

- (void)showErrorMessageOnHud:(NSString *)errorMsg {
  MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
  hud.mode = MBProgressHUDModeCustomView;
  hud.label.text = NSLocalizedString(@"Error", nil);
  hud.customView =
      [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"check_red"]];
  hud.detailsLabel.text = errorMsg;
  [hud hideAnimated:YES afterDelay:2.5f];
}

#pragma mark - Other methods

// Local, FTP Dropbox Syncing
- (void)syncPressed {
  UIAlertController *alertCon = [UIAlertController
      alertControllerWithTitle:NSLocalizedString(@"Synchronisation", nil)
                       message:NSLocalizedString(
                                   @"Choose one of the following options", nil)
                preferredStyle:UIAlertControllerStyleActionSheet];
  alertCon.modalPresentationStyle = UIModalPresentationPopover;
  alertCon.popoverPresentationController.barButtonItem = syncButton;
  UIAlertAction *firstAA =
      [UIAlertAction actionWithTitle:@"Local Sync"
                               style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction *action) {
                               [self localPressed];
                             }];
  [firstAA setValue:[UIImage imageNamed:@"local"] forKey:@"image"];
  [alertCon addAction:firstAA];

  UIAlertAction *dropboxAlertAction =
      [UIAlertAction actionWithTitle:@"Dropbox Sync"
                               style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction *action) {
                               [self dropboxPressed];
                             }];
  [dropboxAlertAction setValue:[UIImage imageNamed:@"dropbox"] forKey:@"image"];
  [alertCon addAction:dropboxAlertAction];

  UIAlertAction *cancelAlertAction =
      [UIAlertAction actionWithTitle:@"Cancel"
                               style:UIAlertActionStyleCancel
                             handler:nil];
  [alertCon addAction:cancelAlertAction];

  [self presentViewController:alertCon animated:YES completion:nil];
}

- (void)localPressed {
  if (isUploading) {
    isUploading = NO;
    [footerLabel removeFromSuperview];
  }
  if ([webUploader isRunning]) {
    UIImage *newImage = [UIImage imageNamed:@"sync"];
    [syncButton setImage:newImage];
    [webUploader stop];
    [footerLabel removeFromSuperview];
  } else {
    [webUploader start];
    if (webUploader.serverURL == nil) {
      UIAlertController *noWifiAlert = [UIAlertController
          alertControllerWithTitle:NSLocalizedString(@"No WiFi Available", nil)
                           message:NSLocalizedString(
                                       @"Local Syncing needs WiFi to work", nil)
                    preferredStyle:UIAlertControllerStyleAlert];
      UIAlertAction *okAction =
          [UIAlertAction actionWithTitle:@"OK"
                                   style:UIAlertActionStyleCancel
                                 handler:^(UIAlertAction *_Nonnull action) {
                                   [self->webUploader stop];
                                 }];
      [noWifiAlert addAction:okAction];
      [self presentViewController:noWifiAlert animated:YES completion:nil];
    } else {
      UIImage *newImage = [UIImage imageNamed:@"sync_selected"];
      [syncButton setImage:[newImage imageWithRenderingMode:
                                         UIImageRenderingModeAlwaysOriginal]];
      [self.view addSubview:footerLabel];
      footerLabel.text = [@"Local Syncing enabled: \n Connect via "
          stringByAppendingString:[webUploader.serverURL absoluteString]];
    }
  }
}

- (void)displayInfoPage {
  if (filesInfoView == nil) {
    filesInfoView = [[FilesInfoView alloc] initWithFrame:self.view.bounds];
    filesInfoView.viewController = self;
  }

  [self.view addSubview:filesInfoView];

  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
  self.tableView.scrollEnabled = NO;

  self.navigationItem.rightBarButtonItem = nil;
}

- (void)hideInfoPage {
  if (filesInfoView != nil) {
    [filesInfoView removeFromSuperview];
  }

  self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
  self.tableView.scrollEnabled = YES;

  self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)updateFiles {
  // Get the document's directory
  NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];

  // Get the contents of the documents directory
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *dirContents =
      [fileManager contentsOfDirectoryAtPath:documentsDirectory error:nil];

  // Strip out all the directories
  NSMutableArray *files = [[NSMutableArray alloc] init];
  for (NSString *file in dirContents) {
    NSString *path = [documentsDirectory stringByAppendingPathComponent:file];

    BOOL dir = NO;
    [fileManager fileExistsAtPath:path isDirectory:&dir];
    if (!dir) {
      [files addObject:file];
    }
  }

  // Sort the list of files
  [files sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

  // Filter the list of files into everything ending with .kdb or .kdbx
  NSArray *databaseFilenames = [files
      filteredArrayUsingPredicate:
          [NSPredicate
              predicateWithFormat:
                  @"(self ENDSWITH[c] '.kdb') OR (self ENDSWITH[c] '.kdbx')"]];

  // Filter the list of files into everything not ending with .kdb or .kdbx
  NSArray *keyFilenames = [files
      filteredArrayUsingPredicate:
          [NSPredicate predicateWithFormat:@"!((self ENDSWITH[c] '.kdb') OR "
                                           @"(self ENDSWITH[c] '.kdbx'))"]];

  _databaseFiles = [NSMutableArray arrayWithArray:databaseFilenames];
  keyFiles = [NSMutableArray arrayWithArray:keyFilenames];

  [self syncToExtension];
}

/// sync for auto fill extension
- (void)syncToExtension {

  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *allFiles = [_databaseFiles arrayByAddingObjectsFromArray:keyFiles];
  NSURL *groupURL = [fileManager
      containerURLForSecurityApplicationGroupIdentifier:@"group.keepass-touch"];
  for (NSString *file in [fileManager contentsOfDirectoryAtPath:groupURL.path
                                                          error:nil]) {
    // clear databases only
    if ([file containsString:@".kdb"] || [file containsString:@".key"]) {
      [fileManager removeItemAtURL:[groupURL URLByAppendingPathComponent:file]
                             error:nil];
    }
  }

  for (NSString *fileName in allFiles) {
    NSString *groupdocPath = groupURL.path;
    NSString *dbPath = [groupdocPath stringByAppendingPathComponent:fileName];
    BOOL exists = [fileManager fileExistsAtPath:dbPath];
    if (exists) {
      NSError *error;
      [fileManager removeItemAtPath:dbPath error:&error];
    }
    NSData *dbData = [NSData
        dataWithContentsOfFile:[[KeePassTouchAppDelegate documentsDirectory]
                                   stringByAppendingPathComponent:fileName]];
    [fileManager createFileAtPath:dbPath contents:dbData attributes:nil];
  }
}

- (void)renameDatabase:(TextEntryController *)textEntryController {
  NSString *newName = textEntryController.textField.text;
  if (newName == nil || [newName isEqualToString:@""]) {
    [textEntryController
        showErrorMessage:NSLocalizedString(@"Filename is invalid", nil)];
    return;
  }

  NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
  NSString *oldFilename = [_databaseFiles objectAtIndex:indexPath.row];
  NSString *newFilename =
      [newName stringByAppendingPathExtension:[oldFilename pathExtension]];

  // Get the full path of where we're going to move the file
  NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];

  NSString *oldPath =
      [documentsDirectory stringByAppendingPathComponent:oldFilename];
  NSString *newPath =
      [documentsDirectory stringByAppendingPathComponent:newFilename];

  // Check if the file already exists
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:newPath]) {
    [textEntryController
        showErrorMessage:NSLocalizedString(
                             @"A file already exists with this name", nil)];
    return;
  }

  // Move input file into documents directory
  [fileManager moveItemAtPath:oldPath toPath:newPath error:nil];

  // Update the filename in the files list
  [_databaseFiles replaceObjectAtIndex:indexPath.row withObject:newFilename];

  // Load the password and keyfile from the keychain under the old filename
  NSString *password = [KeychainUtils stringForKey:oldFilename
                                    andServiceName:KPT_PASSWORD_SERVICE];
  NSString *keyFile = [KeychainUtils stringForKey:oldFilename
                                   andServiceName:KPT_KEYFILES_SERVICE];

  // Store the password and keyfile into the keychain under the new filename
  [KeychainUtils setString:password
                    forKey:newFilename
            andServiceName:KPT_PASSWORD_SERVICE];
  [KeychainUtils setString:keyFile
                    forKey:newFilename
            andServiceName:KPT_KEYFILES_SERVICE];

  // Delete the keychain entries for the old filename
  [KeychainUtils deleteStringForKey:oldFilename
                     andServiceName:KPT_PASSWORD_SERVICE];
  [KeychainUtils deleteStringForKey:oldFilename
                     andServiceName:KPT_KEYFILES_SERVICE];

  // Reload the table row
  if (indexPath)
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                          withRowAnimation:UITableViewRowAnimationFade];

  [textEntryController dismissViewControllerAnimated:YES completion:nil];
}

- (void)addPressed {

  UIAlertController *alertCon = [UIAlertController
      alertControllerWithTitle:NSLocalizedString(@"New Database", nil)
                       message:NSLocalizedString(
                                   @"Choose one of the following options", nil)
                preferredStyle:UIAlertControllerStyleActionSheet];
  alertCon.modalPresentationStyle = UIModalPresentationPopover;
  alertCon.popoverPresentationController.barButtonItem = addButton;

  UIAlertAction *newAction = [UIAlertAction
      actionWithTitle:@"Create New Database"
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
                NewKdbViewController *newKdbViewController =
                    [[NewKdbViewController alloc] init];
                newKdbViewController.donePressed =
                    ^(FormViewController *formViewController) {
                      [self createNewDatabase:(NewKdbViewController *)
                                                  formViewController];
                    };

                UINavigationController *navigationController =
                    [[UINavigationController alloc]
                        initWithRootViewController:newKdbViewController];
                [self->appDelegate.window.rootViewController
                    presentViewController:navigationController
                                 animated:YES
                               completion:nil];
              }];
  [alertCon addAction:newAction];

  UIAlertAction *pickerAction = [UIAlertAction
      actionWithTitle:NSLocalizedString(@"Import", nil)
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
                UIDocumentPickerViewController *documentPickerViewCon =
                    [[UIDocumentPickerViewController alloc]
                        initWithDocumentTypes:@[
                          @"com.kptouch.kdbx", @"com.kptouch.kdb",
                          @"com.kptouch.key", @"com.apple.keynote.key"
                        ]
                                       inMode:UIDocumentPickerModeImport];
                documentPickerViewCon.modalPresentationStyle =
                    UIModalPresentationPopover;
                documentPickerViewCon.popoverPresentationController
                    .barButtonItem = self->addButton;
                documentPickerViewCon.delegate = self;
                [self presentViewController:documentPickerViewCon
                                   animated:YES
                                 completion:nil];
              }];

  [alertCon addAction:pickerAction];

  UIAlertAction *cancelAlertAction =
      [UIAlertAction actionWithTitle:@"Cancel"
                               style:UIAlertActionStyleCancel
                             handler:nil];
  [alertCon addAction:cancelAlertAction];

  [self presentViewController:alertCon animated:YES completion:nil];
}

#pragma mark - New Document Picker

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSError *error;
  for (NSURL *url in urls) {
    NSString *localFilePath = [[KeePassTouchAppDelegate documentsDirectory]
        stringByAppendingPathComponent:url.lastPathComponent];
    if ([fileManager fileExistsAtPath:localFilePath]) {
      [fileManager removeItemAtPath:localFilePath error:&error];
      if (error) {
        // remove file at path error
        [self showErrorMessageOnHud:error.localizedDescription];
      }
    }
    [fileManager copyItemAtPath:url.path toPath:localFilePath error:&error];
    if (error) {
      [self showErrorMessageOnHud:error.localizedDescription];
    } else
      [self reloadTableViewData];
  }
}

- (void)helpPressed {
  HelpViewController *helpViewController = [[HelpViewController alloc] init];
  UINavigationController *navigationController = [[UINavigationController alloc]
      initWithRootViewController:helpViewController];

  [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)createNewDatabase:(NewKdbViewController *)newKdbViewController {
  NSInteger selectedSegment =
      newKdbViewController.versionSegmentedControl.selectedSegmentIndex;
  NSString *name = newKdbViewController.nameTextField.text;
  if (name == nil || [name isEqualToString:@""]) {
    [newKdbViewController
        showErrorMessage:NSLocalizedString(@"Database name is required", nil)];
    return;
  }

  // Check the passwords
  NSString *password1 = newKdbViewController.passwordTextField1.text;
  NSString *password2 = newKdbViewController.passwordTextField2.text;
  if (![password1 isEqualToString:password2]) {
    [newKdbViewController
        showErrorMessage:NSLocalizedString(@"Passwords do not match", nil)];
    return;
  }
  if (password1 == nil || [password1 isEqualToString:@""]) {
    [newKdbViewController
        showErrorMessage:NSLocalizedString(@"Password is required", nil)];
    return;
  }

  // Append the correct file extension
  NSString *filename;
  if (selectedSegment == 0) {
    filename = [name stringByAppendingPathExtension:@"kdb"];
  } else {
    filename = [name stringByAppendingPathExtension:@"kdbx"];
  }
  NSString *filenameLowerCase = [filename lowercaseString];
  // Retrieve the Document directory
  NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];
  NSString *path = [documentsDirectory stringByAppendingPathComponent:filename];
  NSString *lowerCasePath =
      [documentsDirectory stringByAppendingPathComponent:filenameLowerCase];
  // Check if the file already exists
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:path] ||
      [fileManager fileExistsAtPath:lowerCasePath]) {
    [newKdbViewController
        showErrorMessage:NSLocalizedString(
                             @"A file already exists with this name", nil)];
    return;
  }

  // Create the KdbWriter for the requested version
  id<KdbWriter> writer;
  if (selectedSegment == 0) {
    writer = [[Kdb3Writer alloc] init];
  } else {
    writer = [[Kdb4Writer alloc] init];
  }

  // Create the KdbPassword
  KdbPassword *kdbPassword =
      [[KdbPassword alloc] initWithPassword:password1
                           passwordEncoding:NSUTF8StringEncoding
                                    keyFile:nil];

  // Create the new database
  if (selectedSegment <= 2)
    [writer newFile:path
         withPassword:kdbPassword
        withDBVersion:selectedSegment];
  else {
    [newKdbViewController
        showErrorMessage:NSLocalizedString(@"Wrong Database Type selected",
                                           nil)];
    return;
  }

  // Store the password in the keychain
  if ([[AppSettings sharedInstance] rememberPasswordsEnabled]) {
    [KeychainUtils setString:password1
                      forKey:filename
              andServiceName:KPT_PASSWORD_SERVICE];
  }

  // Add the file to the list of files
  NSUInteger index =
      [_databaseFiles indexOfObject:filename
                      inSortedRange:NSMakeRange(0, [_databaseFiles count])
                            options:NSBinarySearchingInsertionIndex
                    usingComparator:^(id string1, id string2) {
                      return [string1 localizedCaseInsensitiveCompare:string2];
                    }];
  [_databaseFiles insertObject:filename atIndex:index];

  // Notify the table of the new row
  NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index
                                              inSection:SECTION_DATABASE];
  if ([_databaseFiles count] == 1) {
    // Reload the section if it's the first item
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:SECTION_DATABASE];
    [self.tableView reloadSections:indexSet
                  withRowAnimation:UITableViewRowAnimationRight];
  } else {
    // Insert the new row
    [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                          withRowAnimation:UITableViewRowAnimationRight];
  }
  [appDelegate.window.rootViewController dismissViewControllerAnimated:YES
                                                            completion:nil];
}

- (void)openDatabaseWithFilename:(NSString *)filename {
  NSString *filePath = [[KeePassTouchAppDelegate documentsDirectory]
      stringByAppendingPathComponent:filename];
  [[DatabaseManager sharedInstance]
      openDatabaseDocument:filePath
                   success:^(DatabaseDocument *doc) {
                     self->appDelegate.databaseDocument = doc;
                   }
                   failure:self.showError];
}

- (void)showSettingsView {
  if ([webUploader isRunning]) {
    UIImage *newImage = [UIImage imageNamed:@"sync"];
    [syncButton setImage:newImage];
    [webUploader stop];
    [footerLabel removeFromSuperview];
  }
  [appDelegate showSettingsView];
}

#pragma mark - GCDWebUploaderDelegate

- (void)webUploader:(GCDWebUploader *)uploader
    didUploadFileAtPath:(NSString *)path {
  [self reloadTableViewData];
}

- (void)webUploader:(GCDWebUploader *)uploader
    didMoveItemFromPath:(NSString *)fromPath
                 toPath:(NSString *)toPath {
  [self reloadTableViewData];
}

- (void)webUploader:(GCDWebUploader *)uploader
    didDeleteItemAtPath:(NSString *)path {
  [self reloadTableViewData];
}

- (void)reloadTableViewData {
  [self updateFiles];

  [self showAutoFillPopupInfo];

  [self.tableView reloadData];
}

#pragma mark - Delegates

#pragma mark - UITableViewDataSource & UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return SECTION_NUMBER;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
  switch (section) {
  case SECTION_DATABASE:
    if ([_databaseFiles count] != 0) {
      return NSLocalizedString(@"Databases", nil);
    }
    break;
  case SECTION_KEYFILE:
    if ([keyFiles count] != 0) {
      return NSLocalizedString(@"Key Files", nil);
    }
    break;
  }

  return nil;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  NSUInteger databaseCount = [_databaseFiles count];
  NSUInteger keyCount = [keyFiles count];

  NSInteger n;
  switch (section) {
  case SECTION_DATABASE:
    n = databaseCount;
    break;
  case SECTION_KEYFILE:
    n = keyCount;
    break;
  default:
    n = 0;
    break;
  }

  // Show the help view if there are no files
  if (databaseCount == 0 && keyCount == 0) {
    [self displayInfoPage];
  } else {
    [self hideInfoPage];
  }

  return n;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"Cell";
  NSString *filename = @"";

  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                  reuseIdentifier:CellIdentifier];
  }

  // Configure the cell
  switch (indexPath.section) {
  case SECTION_DATABASE:
    filename = [_databaseFiles objectAtIndex:indexPath.row];
    cell.textLabel.text = filename;
    if (@available(iOS 13.0, *)) {
      cell.textLabel.textColor = UIColor.labelColor;
    } else {
      cell.textLabel.textColor = UIColor.blackColor;
    }
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    break;
  case SECTION_KEYFILE:
    filename = [keyFiles objectAtIndex:indexPath.row];
    cell.textLabel.text = filename;
    cell.textLabel.textColor = [UIColor grayColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    break;
  default:
    return nil;
  }

  // Retrieve the Document directory
  NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];
  NSString *path = [documentsDirectory stringByAppendingPathComponent:filename];

  // Get the file's modification date
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSDate *modificationDate =
      [[fileManager attributesOfItemAtPath:path
                                     error:nil] fileModificationDate];

  // Format the last modified time as the subtitle of the cell
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateStyle:NSDateFormatterShortStyle];
  [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
  cell.detailTextLabel.text = [NSString
      stringWithFormat:@"%@: %@", NSLocalizedString(@"Last Modified", nil),
                       [dateFormatter stringFromDate:modificationDate]];

  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (isUploading) {
    return;
  }
  if ([webUploader isRunning]) {
    UIImage *newImage = [UIImage imageNamed:@"sync"];
    [syncButton setImage:newImage];
    [webUploader stop];
    [footerLabel removeFromSuperview];
  }

  switch (indexPath.section) {
    // Database file section
  case SECTION_DATABASE:
    if (self.editing == NO) {
      // Load the database
      if (_databaseFiles != nil && indexPath.row < _databaseFiles.count) {
        NSString *documentsDir = [KeePassTouchAppDelegate documentsDirectory];
        NSString *filePath = [documentsDir
            stringByAppendingPathComponent:_databaseFiles[indexPath.row]];
        [[DatabaseManager sharedInstance]
            openDatabaseDocument:filePath
                         success:^(DatabaseDocument *doc) {
                           self->appDelegate.databaseDocument = doc;
                         }
                         failure:self.showError];
      } else
        [self showErrorMessageOnHud:NSLocalizedString(@"Invalid database row",
                                                      nil)];
    } else {
      TextEntryController *textEntryController =
          [[TextEntryController alloc] init];
      textEntryController.title = NSLocalizedString(@"Rename", nil);
      textEntryController.headerTitle =
          NSLocalizedString(@"Database Name", nil);
      textEntryController.footerTitle = NSLocalizedString(
          @"Enter a new name for the password database. The correct file "
          @"extension will automatically be appended.",
          nil);
      textEntryController.textField.placeholder =
          NSLocalizedString(@"Name", nil);
      textEntryController.donePressed =
          ^(FormViewController *formViewController) {
            [self renameDatabase:(TextEntryController *)formViewController];
          };

      NSString *filename = [_databaseFiles objectAtIndex:indexPath.row];
      textEntryController.textField.text =
          [filename stringByDeletingPathExtension];

      UINavigationController *navigationController =
          [[UINavigationController alloc]
              initWithRootViewController:textEntryController];

      [appDelegate.window.rootViewController
          presentViewController:navigationController
                       animated:YES
                     completion:nil];
    }
    break;
  default:
    break;
  }
  if (!self.editing)
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle != UITableViewCellEditingStyleDelete) {
    return;
  }

  NSString *filename;
  switch (indexPath.section) {
  case SECTION_DATABASE:
    filename = [[_databaseFiles objectAtIndex:indexPath.row] copy];
    [_databaseFiles removeObject:filename];

    // Delete the keychain entries for the old filename
    [KeychainUtils deleteStringForKey:filename
                       andServiceName:KPT_PASSWORD_SERVICE];
    [KeychainUtils deleteStringForKey:filename
                       andServiceName:KPT_KEYFILES_SERVICE];
    break;
  case SECTION_KEYFILE:
    filename = [[keyFiles objectAtIndex:indexPath.row] copy];
    [keyFiles removeObject:filename];
    break;
  default:
    return;
  }

  // Retrieve the Document directory
  NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];
  NSString *path = [documentsDirectory stringByAppendingPathComponent:filename];

  // Close the current database if we're deleting it's file
  if ([path isEqualToString:appDelegate.databaseDocument.filename]) {
    [appDelegate closeDatabase];
  }

  // Delete the file
  NSFileManager *fileManager = [NSFileManager defaultManager];
  [fileManager removeItemAtPath:path error:nil];

  // Update the table
  //#error swipe to delete fail here (iOS 11 vermutlich)
  [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                   withRowAnimation:UITableViewRowAnimationFade];
  [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
           withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - DROPBOX SYNC & DBRestClientDelegate

// Dropbox Syncing
- (void)dropboxPressed {

  if (![[DBClientsManager authorizedClient] isAuthorized]) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dropboxLinked)
                                                 name:@"dropboxLinked"
                                               object:nil];

    [DBClientsManager authorizeFromController:[UIApplication sharedApplication]
                                   controller:self
                                      openURL:^(NSURL *url) {
                                        [[UIApplication sharedApplication]
                                                      openURL:url
                                                      options:@{}
                                            completionHandler:nil];
                                      }];
  } else {
    DropboxFolderController *dfc =
        [[DropboxFolderController alloc] initWithStyle:UITableViewStyleGrouped];

    dfc.target = self;

    UINavigationController *nvc =
        [[UINavigationController alloc] initWithRootViewController:dfc];
    [self presentViewController:nvc animated:YES completion:nil];
  }
}

- (void)dropboxLinked {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self performSelector:@selector(dropboxPressed)
             withObject:nil
             afterDelay:1.0f];
}

- (void)syncDropbox {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *dropboxPath = [defaults stringForKey:@"DropboxPath"];

  MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
  if (!hud)
    hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
  hud.mode = MBProgressHUDModeIndeterminate;
  hud.label.text = @"Dropbox Sync Init";

  self.userClient = [DBClientsManager authorizedClient];
  self.collisionArray = [NSArray array];

  // Check for existing files
  [DropboxManager sharedInstance].delegate = self;
  [[DropboxManager sharedInstance] getAllFilesForClient:self.userClient
                                                 atPath:dropboxPath];
}

- (void)uploadFilesToDropbox {

  // if no local uniques are there, proceed to the next step
  if (_localUniques.count == 0) {
    [self downloadFilesFromDropbox];
    return;
  }

  NSString *localFileName = [_localUniques objectAtIndex:0];

  // if conflict call, convert
  if ([localFileName isKindOfClass:[DBFILESFileMetadata class]])
    localFileName = ((DBFILESFileMetadata *)localFileName).name;

  NSString *dropboxPath =
      [[NSUserDefaults standardUserDefaults] stringForKey:@"DropboxPath"];

  // For overriding on upload
  if (dropboxPath.length == 0)
    dropboxPath = @"/";
  DBFILESWriteMode *overwriteMode =
      [[DBFILESWriteMode alloc] initWithOverwrite];
  [[self.userClient.filesRoutes
           uploadUrl:[dropboxPath stringByAppendingString:localFileName]
                mode:overwriteMode
          autorename:@(YES)
      clientModified:nil
                mute:@(NO)
            inputUrl:[[KeePassTouchAppDelegate documentsDirectory]
                         stringByAppendingPathComponent:localFileName]]
      setResponseBlock:^(DBFILESFileMetadata *_Nullable result,
                         DBFILESUploadError *_Nullable routeError,
                         DBRequestError *_Nullable networkError) {
        if (result) {
          NSDictionary *attrs = [NSDictionary
              dictionaryWithObjectsAndKeys:result.serverModified,
                                           NSFileModificationDate, nil];
          NSError *errorFile;
          [[NSFileManager defaultManager]
              setAttributes:attrs
               ofItemAtPath:[[KeePassTouchAppDelegate documentsDirectory]
                                stringByAppendingPathComponent:localFileName]
                      error:&errorFile];
          if (self->_localUniques.count > 0)
            self->_localUniques = [self->_localUniques
                arrayByRemovingObject:[self->_localUniques objectAtIndex:0]];
          self->currentFile++;

          MBProgressHUD *currentHUD = [MBProgressHUD HUDForView:self.view];
          currentHUD.label.text =
              [NSString stringWithFormat:@"Sync %ld / %ld", self->currentFile,
                                         self->allFiles];
          currentHUD.progress = 0.0f;

          // Check if process is done
          if (self->_localUniques.count == 0)
            [self downloadFilesFromDropbox];
          else
            [self uploadFilesToDropbox];
        } else {
          if (networkError)
            [self showErrorOnHud:networkError.nsError];
          else if (routeError)
            [self showErrorMessageOnHud:[routeError description]];
        }
      }];
}

- (void)downloadFilesFromDropbox {
  if (_dropboxUniques.count == 0) {
    [self handleCollision];
    return;
  }

  DBFILESFileMetadata *fileMetadata = [_dropboxUniques objectAtIndex:0];

  NSString *dropboxPath =
      [[NSUserDefaults standardUserDefaults] stringForKey:@"DropboxPath"];
  if (dropboxPath.length == 0)
    dropboxPath = @"/";
  [[[self.userClient.filesRoutes
      downloadUrl:[dropboxPath stringByAppendingString:fileMetadata.name]
        overwrite:YES
      destination:
          [NSURL fileURLWithPath:[[KeePassTouchAppDelegate documentsDirectory]
                                     stringByAppendingPathComponent:fileMetadata
                                                                        .name]]]
      setResponseBlock:^(DBFILESFileMetadata *_Nullable result,
                         DBFILESDownloadError *_Nullable routeError,
                         DBRequestError *_Nullable networkError,
                         NSURL *_Nonnull destination) {
        if (result) {

          [self reloadTableViewData];
          NSDictionary *attrs = [NSDictionary
              dictionaryWithObjectsAndKeys:result.serverModified,
                                           NSFileModificationDate, nil];
          NSError *errorFile;
          [[NSFileManager defaultManager]
              setAttributes:attrs
               ofItemAtPath:[[KeePassTouchAppDelegate documentsDirectory]
                                stringByAppendingPathComponent:fileMetadata
                                                                   .name]
                      error:&errorFile];

          if (self->_dropboxUniques.count > 0)
            self->_dropboxUniques = [self->_dropboxUniques
                arrayByRemovingObject:[self->_dropboxUniques objectAtIndex:0]];
          self->currentFile++;

          MBProgressHUD *currentHUD = [MBProgressHUD HUDForView:self.view];
          currentHUD.label.text =
              [NSString stringWithFormat:@"Sync %ld / %ld", self->currentFile,
                                         self->allFiles];
          currentHUD.progress = 0.0f;

          // Check if process is done
          if (self->_dropboxUniques.count == 0)
            [self handleCollision];
          else
            [self downloadFilesFromDropbox];

        } else {
          if (networkError)
            [self showErrorOnHud:networkError.nsError];
          else if (routeError)
            [self showErrorMessageOnHud:[routeError description]];
        }
      }]
      setProgressBlock:^(int64_t bytesDownloaded, int64_t totalBytesDownloaded,
                         int64_t totalBytesExpectedToDownload) {
        float downloadPercentage =
            (float)totalBytesDownloaded / (float)totalBytesExpectedToDownload;
        [MBProgressHUD HUDForView:self.view].progress = downloadPercentage;
      }];
}

#pragma mark - DropboxManagerDelegate

- (void)didListFolderWithFiles:(NSArray<DBFILESFileMetadata *> *)keepassFiles {

  _localUniques = [NSArray arrayWithArray:_databaseFiles];
  _dropboxUniques = [NSArray array];

  // go through all 3 cases and add in 3 arrays
  for (DBFILESFileMetadata *fileMetadata in keepassFiles) {
    BOOL found = NO;
    for (NSString *fileName in _localUniques) {
      if ([fileName isEqualToString:fileMetadata.name]) {
        self.collisionArray =
            [self.collisionArray arrayByAddingObject:fileMetadata];
        _localUniques = [_localUniques arrayByRemovingObject:fileName];
        found = YES;
      }
    }
    if (!found) {
      _dropboxUniques = [_dropboxUniques arrayByAddingObject:fileMetadata];
    }
  }

  currentFile = 1;
  allFiles =
      (_localUniques.count + _dropboxUniques.count + self.collisionArray.count);

  MBProgressHUD *currentHUD = [MBProgressHUD HUDForView:self.view];
  currentHUD.label.text =
      [NSString stringWithFormat:@"Sync %ld / %ld", currentFile, allFiles];
  currentHUD.progress = 0.0f;

  [self uploadFilesToDropbox];
}

- (void)didFailToListFolderWithError:(DBRequestError *)error {
  [self showErrorOnHud:error.nsError];
}

- (void)didFailToListFolderWithFolderError:(NSObject *)error {
  if (error)
    [self showErrorMessageOnHud:[error description]];
}

- (void)handleCollision {
  if (self.collisionArray.count > 0) {
    DBFILESFileMetadata *file = [self.collisionArray objectAtIndex:0];
    NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];
    NSString *path =
        [documentsDirectory stringByAppendingPathComponent:file.name];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDate *localModificationDate =
        [[fileManager attributesOfItemAtPath:path
                                       error:nil] fileModificationDate];
    NSDate *remoteModificationDate = file.serverModified;

    UIAlertController *chooseVersionController = [UIAlertController
        alertControllerWithTitle:@"Update"
                         message:@""
                  preferredStyle:UIAlertControllerStyleAlert];

    // Dropbox Handler
    void (^dropboxHandler)(UIAlertAction *action) = ^void(
        UIAlertAction *action) {
      self->_dropboxUniques = [self->_dropboxUniques arrayByAddingObject:file];
      self.collisionArray = [self.collisionArray arrayByRemovingObject:file];
      [self downloadFilesFromDropbox];
    };

    // Local Handler
    void (^localHandler)(UIAlertAction *action) = ^void(UIAlertAction *action) {
      self->_localUniques = [self->_localUniques arrayByAddingObject:file];
      self.collisionArray = [self.collisionArray arrayByRemovingObject:file];
      [self uploadFilesToDropbox];
    };

    UIAlertAction *newerFileAction;
    UIAlertAction *olderFileAction;

    if ([localModificationDate compare:remoteModificationDate] ==
        NSOrderedDescending) {
      if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DBAutoSync"]) {
        localHandler(nil);
        return;
      }

      newerFileAction = [UIAlertAction
          actionWithTitle:NSLocalizedString(@"Newer Version", nil)
                    style:UIAlertActionStyleDefault
                  handler:localHandler];

      olderFileAction = [UIAlertAction
          actionWithTitle:NSLocalizedString(@"Older Version", nil)
                    style:UIAlertActionStyleDestructive
                  handler:dropboxHandler];

      chooseVersionController.message =
          NSLocalizedString(@"Your local file is newer than the dropbox "
                            @"file.\n Which one do you want to keep and use?",
                            nil);

      [chooseVersionController addAction:newerFileAction];
      [chooseVersionController addAction:olderFileAction];
      [chooseVersionController
          addAction:
              [UIAlertAction
                  actionWithTitle:NSLocalizedString(@"Cancel", nil)
                            style:UIAlertActionStyleCancel
                          handler:^(UIAlertAction *_Nonnull action) {
                            self.collisionArray = [self.collisionArray
                                arrayByRemovingObject:file];
                            self->currentFile++;
                            if (self->currentFile > self->allFiles) {
                              MBProgressHUD *hud =
                                  [MBProgressHUD HUDForView:self.view];
                              hud.mode = MBProgressHUDModeCustomView;
                              hud.customView = [[UIImageView alloc]
                                  initWithImage:[UIImage
                                                    imageNamed:@"check_green"]];
                              hud.label.text =
                                  NSLocalizedString(@"Dropbox Sync", nil);
                              [hud hideAnimated:YES afterDelay:1.2f];
                              [self checkForAutoSync];
                            } else {
                              MBProgressHUD *currentHUD =
                                  [MBProgressHUD HUDForView:self.view];
                              currentHUD.label.text =
                                  [NSString stringWithFormat:@"Sync %ld / %ld",
                                                             self->currentFile,
                                                             self->allFiles];
                              currentHUD.progress = 0.0f;
                            }
                            [self handleCollision];
                          }]];

      [self presentViewController:chooseVersionController
                         animated:YES
                       completion:nil];
    } else if ([localModificationDate compare:remoteModificationDate] ==
               NSOrderedAscending) {
      if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DBAutoSync"]) {
        dropboxHandler(nil);
        return;
      }
      newerFileAction = [UIAlertAction
          actionWithTitle:NSLocalizedString(@"Newer Version", nil)
                    style:UIAlertActionStyleDefault
                  handler:dropboxHandler];

      olderFileAction = [UIAlertAction
          actionWithTitle:NSLocalizedString(@"Older Version", nil)
                    style:UIAlertActionStyleDestructive
                  handler:localHandler];

      chooseVersionController.message =
          NSLocalizedString(@"Your dropbox file is newer than the local "
                            @"file.\n Which one do you want to keep and use?",
                            nil);

      [chooseVersionController addAction:newerFileAction];
      [chooseVersionController addAction:olderFileAction];
      [chooseVersionController
          addAction:
              [UIAlertAction
                  actionWithTitle:NSLocalizedString(@"Cancel", nil)
                            style:UIAlertActionStyleCancel
                          handler:^(UIAlertAction *_Nonnull action) {
                            self.collisionArray = [self.collisionArray
                                arrayByRemovingObject:file];
                            self->currentFile++;
                            if (self->currentFile > self->allFiles) {
                              MBProgressHUD *hud =
                                  [MBProgressHUD HUDForView:self.view];
                              hud.mode = MBProgressHUDModeCustomView;
                              hud.customView = [[UIImageView alloc]
                                  initWithImage:[UIImage
                                                    imageNamed:@"check_green"]];
                              hud.label.text =
                                  NSLocalizedString(@"Dropbox Sync", nil);
                              [hud hideAnimated:YES afterDelay:1.2f];
                              [self checkForAutoSync];
                            } else {
                              MBProgressHUD *currentHUD =
                                  [MBProgressHUD HUDForView:self.view];
                              currentHUD.label.text =
                                  [NSString stringWithFormat:@"Sync %ld / %ld",
                                                             self->currentFile,
                                                             self->allFiles];
                              currentHUD.progress = 0.0f;
                            }
                            [self handleCollision];
                          }]];

      [self presentViewController:chooseVersionController
                         animated:YES
                       completion:nil];
    }
    // if not ascending or descending, file is in sync
    else {
      self.collisionArray = [self.collisionArray arrayByRemovingObject:file];
      currentFile++;
      if (currentFile > allFiles) {
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        hud.mode = MBProgressHUDModeCustomView;
        hud.customView = [[UIImageView alloc]
            initWithImage:[UIImage imageNamed:@"check_green"]];
        hud.label.text = NSLocalizedString(@"Dropbox Sync", nil);
        [hud hideAnimated:YES afterDelay:1.2f];
        [self checkForAutoSync];
      } else {
        MBProgressHUD *currentHUD = [MBProgressHUD HUDForView:self.view];
        currentHUD.label.text = [NSString
            stringWithFormat:@"Sync %ld / %ld", currentFile, allFiles];
        currentHUD.progress = 0.0f;
      }
      [self handleCollision];
    }

  } else {
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    hud.mode = MBProgressHUDModeCustomView;
    hud.customView =
        [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"check_green"]];
    hud.label.text = NSLocalizedString(@"Dropbox Sync", nil);
    [hud hideAnimated:YES afterDelay:1.2f];
    [self reloadTableViewData];
  }

  return;
}

- (void)checkForAutoSync {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults boolForKey:@"DBAutoSync"])
    return;
  NSInteger askCount = [defaults integerForKey:@"DBAutoSyncCount"];
  if (askCount == 0 || askCount == 10) {
    UIAlertController *avc = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"Auto Sync", nil)
                         message:NSLocalizedString(
                                     @"If you choose Auto Sync the app will "
                                     @"sync with the chosen Dropbox folder on "
                                     @"each startup. Should auto-sync with the "
                                     @"chosen folder be enabled? You can reset "
                                     @"this in the settings.",
                                     nil)
                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *dontAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"Don't Auto Sync", nil)
                  style:UIAlertActionStyleCancel
                handler:nil];
    UIAlertAction *activateAction =
        [UIAlertAction actionWithTitle:NSLocalizedString(@"Auto Sync", nil)
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *_Nonnull action) {
                                 [defaults setBool:YES forKey:@"DBAutoSync"];
                               }];
    [avc addAction:activateAction];
    [avc addAction:dontAction];

    [self presentViewController:avc animated:YES completion:nil];
    [defaults setInteger:(askCount + 1) forKey:@"DBAutoSyncCount"];
  } else
    [defaults setInteger:(askCount + 1) forKey:@"DBAutoSyncCount"];
}

- (void)showAutoFillPopupInfo {
  if (![[NSUserDefaults standardUserDefaults] boolForKey:@"LaunchTwo"]) {
#warning remove this after some versions
    // This is any second launch
    BOOL purchased = [AppSettings sharedInstance].purchased;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"LaunchTwo"];
    NSString *alertMessage =
        @"Go ahead! Just open your database and you are good to go.\n\nYour "
        @"passwords will now be securely available in any app.\n\nBe aware "
        @"that the URL field is required to use it, so make use of it in as "
        @"many entries as you can.";
    if (!purchased)
      alertMessage =
          @"Go ahead into settings and purchase Remove Ads + Auto "
          @"Fill!\n\nAfter that, just open your database and you are good to "
          @"go. Your passwords will now be securely available in any "
          @"app.\n\nBe aware that the URL field is required to use it, so make "
          @"use of it in as many entries as you can.";
    UIAlertController *alertCon = [UIAlertController
        alertControllerWithTitle:@"Auto Fill is here!"
                         message:alertMessage
                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction =
        [UIAlertAction actionWithTitle:@"OK"
                                 style:UIAlertActionStyleCancel
                               handler:nil];
    [alertCon addAction:cancelAction];
    [self presentViewController:alertCon animated:YES completion:nil];
  }
}

@end
