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

#import "EntryViewController.h"
#import "AppSettings.h"
#import "ImageFactory.h"
#import "Kdb4Node.h"
#import "WebViewController.h"

#import "MBProgressHUD.h"

#import "Base64.h"
#import "NSData+CompressGZip.h"

#import "TWMessageBarManager.h"

#define SECTION_HEADER_HEIGHT 46.0f

enum {
  SECTION_DEFAULT_FIELDS,
  SECTION_CUSTOM_FIELDS,
  SECTION_FILES,
  SECTION_COMMENTS,
  NUM_SECTIONS
};

@interface EntryViewController () {
  TitleFieldCell *titleCell;
  TextFieldCell *usernameCell;
  TextFieldCell *expireCell;
  PasswordFieldCell *passwordCell;
  UrlFieldCell *urlCell;
  TextViewCell *commentsCell;

  UIDocumentInteractionController *docu;
}

@property(nonatomic) BOOL isKdb4;
@property(nonatomic, readonly) NSMutableArray *editingStringFields;
@property(nonatomic, readonly) NSArray *entryStringFields;
@property(nonatomic, readonly) NSArray *currentStringFields;

@property(nonatomic, strong) NSMutableArray *filledCells;
@property(nonatomic, readonly) NSArray *defaultCells;

@property(nonatomic, readonly) NSArray *cells;

@end

@implementation EntryViewController

- (id)initWithStyle:(UITableViewStyle)style {
  self = [super initWithStyle:style];
  if (self) {
    self.tableView.allowsSelectionDuringEditing = YES;
    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;

    self.navigationItem.rightBarButtonItem = self.editButtonItem;

    UIBarButtonItem *backBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Entry", nil)
                                         style:UIBarButtonItemStylePlain
                                        target:nil
                                        action:nil];
    self.navigationItem.backBarButtonItem = backBarButtonItem;

    titleCell = [[TitleFieldCell alloc] initWithStyle:UITableViewCellStyleValue2
                                      reuseIdentifier:nil];
    titleCell.delegate = self;
    titleCell.textLabel.text = NSLocalizedString(@"Title", nil);
    titleCell.textField.placeholder = NSLocalizedString(@"Title", nil);
    titleCell.textField.enabled = NO;
    titleCell.textFieldCellDelegate = self;
    titleCell.imageButton.adjustsImageWhenHighlighted = NO;
    [titleCell.imageButton addTarget:self
                              action:@selector(imageButtonPressed)
                    forControlEvents:UIControlEventTouchUpInside];

    usernameCell =
        [[TextFieldCell alloc] initWithStyle:UITableViewCellStyleValue2
                             reuseIdentifier:nil];
    usernameCell.textLabel.text = NSLocalizedString(@"Username", nil);
    usernameCell.textField.placeholder = NSLocalizedString(@"Username", nil);
    usernameCell.textField.enabled = NO;
    usernameCell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    usernameCell.textField.autocapitalizationType =
        UITextAutocapitalizationTypeNone;
    usernameCell.textFieldCellDelegate = self;

    expireCell = [[TextFieldCell alloc] initWithStyle:UITableViewCellStyleValue2
                                      reuseIdentifier:nil];
    expireCell.textLabel.text = NSLocalizedString(@"Expiration Date", nil);
    expireCell.textField.placeholder =
        NSLocalizedString(@"Expiration Date", nil);
    expireCell.textField.enabled = NO;
    expireCell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    expireCell.textField.autocapitalizationType =
        UITextAutocapitalizationTypeNone;
    expireCell.textFieldCellDelegate = self;
    expireCell.textField.allowsEditingTextAttributes = NO;
    expireCell.userInteractionEnabled = NO;
    expireCell.textLabel.font = [UIFont systemFontOfSize:11.0f];

    passwordCell =
        [[PasswordFieldCell alloc] initWithStyle:UITableViewCellStyleValue2
                                 reuseIdentifier:nil];
    passwordCell.textLabel.text = NSLocalizedString(@"Password", nil);
    passwordCell.textField.placeholder = NSLocalizedString(@"Password", nil);
    passwordCell.textField.enabled = NO;
    passwordCell.textFieldCellDelegate = self;
    [passwordCell.accessoryButton addTarget:self
                                     action:@selector(showPasswordPressed)
                           forControlEvents:UIControlEventTouchUpInside];
    [passwordCell.editAccessoryButton
               addTarget:self
                  action:@selector(generatePasswordPressed)
        forControlEvents:UIControlEventTouchUpInside];

    urlCell = [[UrlFieldCell alloc] initWithStyle:UITableViewCellStyleValue2
                                  reuseIdentifier:nil];
    urlCell.textLabel.text = NSLocalizedString(@"URL", nil);
    urlCell.textField.placeholder = NSLocalizedString(@"URL", nil);
    urlCell.textField.enabled = NO;
    urlCell.textFieldCellDelegate = self;
    urlCell.textField.returnKeyType = UIReturnKeyDone;
    [urlCell.accessoryButton addTarget:self
                                action:@selector(openUrlPressed)
                      forControlEvents:UIControlEventTouchUpInside];

    commentsCell = [[TextViewCell alloc] init];
    commentsCell.textView.editable = NO;

    _defaultCells =
        @[ titleCell, usernameCell, passwordCell, expireCell, urlCell ];
    _filledCells = [[NSMutableArray alloc] initWithCapacity:5];

    _editingStringFields = [NSMutableArray array];
  }
  return self;
}

- (void)viewDidLoad {
  self.tableView.sectionFooterHeight = 0.0f;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  // Add listeners to the keyboard
  NSNotificationCenter *notificationCenter =
      [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self
                         selector:@selector(applicationWillResignActive:)
                             name:UIApplicationWillResignActiveNotification
                           object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  if (self.isNewEntry) {
    [self setEditing:YES animated:NO];
    [titleCell.textField becomeFirstResponder];
    self.isNewEntry = NO;
  }
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];

  // Hide the password HUD if it's visible
  [MBProgressHUD hideHUDForView:self.view animated:NO];

  // Remove listeners from the keyboard
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationWillResignActive:(id)sender {
  // Resign first responder to prevent password being in sight and UI glitchs
  [titleCell.textField resignFirstResponder];
  [usernameCell.textField resignFirstResponder];
  [passwordCell.textField resignFirstResponder];
  [urlCell.textField resignFirstResponder];
  [commentsCell.textView resignFirstResponder];
}

- (void)setEntry:(KdbEntry *)e {
  _entry = e;
  self.isKdb4 = [self.entry isKindOfClass:[Kdb4Entry class]];

  if (self.isKdb4) {
    Kdb4Entry *ent4 = ((Kdb4Entry *)e);
    if (ent4.customIconUuid != nil) {
      self.searchKey =
          [[NSString alloc] initWithData:ent4.customIconUuid.getData
                                encoding:NSASCIIStringEncoding];
    }
  }
  // Update the fields
  self.title = self.entry.title;
  titleCell.textField.text = self.entry.title;
  [self setSelectedImageIndex:self.entry.image];
  usernameCell.textField.text = self.entry.username;
  passwordCell.textField.text = self.entry.password;
  urlCell.textField.text = self.entry.url;
  if (self.isKdb4 && [(Kdb4Entry *)self.entry expires]) {
    NSDateFormatter *df_utc = [[NSDateFormatter alloc] init];
    [df_utc setTimeZone:[NSTimeZone defaultTimeZone]];
    [df_utc setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

    expireCell.textField.text = [df_utc stringFromDate:self.entry.expiryTime];
  }
  if (!self.isKdb4) {
    NSMutableArray *mutable = (NSMutableArray *)[self.defaultCells mutableCopy];
    [mutable removeObject:expireCell];
    _defaultCells = mutable;
    _filledCells = [NSMutableArray arrayWithCapacity:4];
  }
  commentsCell.textView.text = self.entry.notes;

  // Track what cells are filled out
  [self updateFilledCells];
}

- (NSArray *)cells {
  return self.editing ? self.defaultCells : self.filledCells;
}

- (void)updateFilledCells {
  [self.filledCells removeAllObjects];
  for (TextFieldCell *cell in self.defaultCells) {
    if (cell.textField.text.length > 0) {
      [self.filledCells addObject:cell];
    }
  }
}

- (NSArray *)currentStringFields {
  if (!self.isKdb4) {
    return nil;
  }

  if (self.editing) {
    return self.editingStringFields;
  } else {
    return ((Kdb4Entry *)self.entry).stringFields;
  }
}

- (NSArray *)entryStringFields {
  if (self.isKdb4) {
    Kdb4Entry *entry = (Kdb4Entry *)self.entry;
    return entry.stringFields;
  } else {
    return nil;
  }
}

- (void)cancelPressed {
  [self setEditing:NO animated:YES canceled:YES];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
  [self setEditing:editing animated:animated canceled:NO];
}

- (void)setEditing:(BOOL)editing
          animated:(BOOL)animated
          canceled:(BOOL)canceled {
  [super setEditing:editing animated:animated];

  // Ensure that all updates happen at once
  [self.tableView beginUpdates];

  if (editing == NO) {
    if (canceled) {
      [self setEntry:self.entry];
    } else {
      self.entry.title = titleCell.textField.text;
      self.entry.image = self.selectedImageIndex;
      self.entry.username = usernameCell.textField.text;
      self.entry.password = passwordCell.textField.text;
      self.entry.url = urlCell.textField.text;

      self.entry.notes = commentsCell.textView.text;
      self.entry.lastModificationTime = [NSDate date];
      [self updateFilledCells];

      if (self.isKdb4) {
        // Ensure any textfield currently being edited is saved
        NSInteger count =
            [self.tableView numberOfRowsInSection:SECTION_CUSTOM_FIELDS] - 1;
        for (NSInteger i = 0; i < count; i++) {
          TextFieldCell *cell = (TextFieldCell *)[self.tableView
              cellForRowAtIndexPath:[NSIndexPath
                                        indexPathForRow:i
                                              inSection:SECTION_CUSTOM_FIELDS]];
          [cell.textField resignFirstResponder];
        }

        Kdb4Entry *kdb4Entry = (Kdb4Entry *)self.entry;
        [kdb4Entry.stringFields removeAllObjects];
        [kdb4Entry.stringFields addObjectsFromArray:self.editingStringFields];
      }

      // Save the database document
      [[KeePassTouchAppDelegate appDelegate].databaseDocument save];
      for (UIViewController *con in self.navigationController.viewControllers) {
        if ([NSStringFromClass(con.class)
                isEqualToString:@"GroupViewController"]) {
          if ([con respondsToSelector:@selector(updateCredentialStore)])
            [con performSelector:@selector(updateCredentialStore)];
#warning replace this with singleton
        }
      }
    }
  }

  // Index paths for cells to be added or removed
  NSMutableArray *paths = [NSMutableArray array];

  // Manage default cells
  for (TextFieldCell *cell in self.defaultCells) {
    cell.textField.enabled = editing;

    // Add empty cells to the list of cells that need to be added/deleted when
    // changing between editing
    if (cell.textField.text.length == 0) {
      [paths addObject:[NSIndexPath indexPathForRow:[self.defaultCells
                                                        indexOfObject:cell]
                                          inSection:0]];
    }
  }

  [self.editingStringFields removeAllObjects];
  [self.editingStringFields addObjectsFromArray:[self.entryStringFields copy]];
  [self.tableView
        reloadSections:[NSIndexSet indexSetWithIndex:SECTION_CUSTOM_FIELDS]
      withRowAnimation:UITableViewRowAnimationFade];

  if (editing) {
    UIBarButtonItem *cancelButton =
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", nil)
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(cancelPressed)];
    self.navigationItem.leftBarButtonItem = cancelButton;

    titleCell.imageButton.adjustsImageWhenHighlighted = YES;
    commentsCell.textView.editable = YES;

    [self.tableView insertRowsAtIndexPaths:paths
                          withRowAnimation:UITableViewRowAnimationFade];
  } else {
    self.navigationItem.leftBarButtonItem = nil;

    titleCell.imageButton.adjustsImageWhenHighlighted = NO;
    commentsCell.textView.editable = NO;

    [self.tableView deleteRowsAtIndexPaths:paths
                          withRowAnimation:UITableViewRowAnimationFade];
  }

  // Commit all updates
  [self.tableView endUpdates];
}

- (void)titleFieldCell:(TitleFieldCell *)cell updatedTitle:(NSString *)title {
  self.title = title;
}

#pragma mark - TextFieldCell delegate

- (void)textFieldCellDidEndEditing:(TextFieldCell *)textFieldCell {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:textFieldCell];

  switch (indexPath.section) {
  case SECTION_CUSTOM_FIELDS: {
    StringField *stringField =
        [self.editingStringFields objectAtIndex:indexPath.row];
    stringField.value = textFieldCell.textField.text;
    textFieldCell.textField.secureTextEntry = stringField.protected;
    break;
  }
  default:
    break;
  }
}

- (void)textFieldCellWillReturn:(TextFieldCell *)textFieldCell {
  NSIndexPath *indexPath = [self.tableView indexPathForCell:textFieldCell];

  switch (indexPath.section) {
  case SECTION_DEFAULT_FIELDS: {
    NSInteger nextIndex = indexPath.row + 1;
    if (nextIndex < [self.defaultCells count]) {
      TextFieldCell *nextCell = [self.defaultCells objectAtIndex:nextIndex];
      [nextCell.textField becomeFirstResponder];
    } else {
      [self setEditing:NO animated:YES];
    }
    break;
  }
  case SECTION_CUSTOM_FIELDS: {
    [textFieldCell.textField resignFirstResponder];
  }
  default:
    break;
  }
}

#pragma mark - UIDocumentInteractionController stuff for Attachments

- (UIDocumentInteractionController *)documentInteractionControllerForURL:
    (NSURL *)fileURL {
  UIDocumentInteractionController *docController =
      [UIDocumentInteractionController interactionControllerWithURL:fileURL];
  docController.delegate = self;
  return docController;
}

- (UIViewController *)documentInteractionControllerViewControllerForPreview:
    (UIDocumentInteractionController *)controller {
  return self;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return NUM_SECTIONS;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
  switch (section) {
  case SECTION_DEFAULT_FIELDS:
    return nil;
  case SECTION_CUSTOM_FIELDS:
    if (self.isKdb4) {
      if ([self tableView:tableView numberOfRowsInSection:1] > 0) {
        return NSLocalizedString(@"Custom Fields", nil);
      } else {
        return nil;
      }
    } else {
      return nil;
    }
  case SECTION_FILES:
    if (self.isKdb4 && (((Kdb4Entry *)self.entry).binaries.count > 0))
      return NSLocalizedString(@"Files", nil);
    else
      return nil;
  case SECTION_COMMENTS:
    return NSLocalizedString(@"Comments", nil);
  }

  return nil;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  switch (section) {
  case SECTION_DEFAULT_FIELDS:
    return [self.cells count];
  case SECTION_CUSTOM_FIELDS:
    if (self.isKdb4) {
      NSUInteger numCells = self.currentStringFields.count;
      // Additional cell for Add cell
      return self.editing ? numCells + 1 : numCells;
    } else {
      return 0;
    }
  case SECTION_COMMENTS:
    return 1;
  case SECTION_FILES:
    if (self.isKdb4)
      return ((Kdb4Entry *)self.entry).binaries.count;
    else
      return 0;
  }

  return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *TextFieldCellIdentifier = @"TextFieldCell";
  static NSString *AddFieldCellIdentifier = @"AddFieldCell";

  switch (indexPath.section) {
  case SECTION_DEFAULT_FIELDS: {
    return [self.cells objectAtIndex:indexPath.row];
  }
  case SECTION_CUSTOM_FIELDS: {
    if (indexPath.row == self.currentStringFields.count) {
      // Return "Add new..." cell
      UITableViewCell *cell =
          [tableView dequeueReusableCellWithIdentifier:AddFieldCellIdentifier];
      if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2
                                      reuseIdentifier:AddFieldCellIdentifier];
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.textLabel.text = NSLocalizedString(@"Add new…", nil);

        // Add new cell when this cell is tapped
        [cell addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                       initWithTarget:self
                                               action:@selector(addPressed)]];
      }

      return cell;
    } else {
      TextFieldCell *cell =
          [tableView dequeueReusableCellWithIdentifier:TextFieldCellIdentifier];
      if (cell == nil) {
        cell = [[TextFieldCell alloc] initWithStyle:UITableViewCellStyleValue2
                                    reuseIdentifier:TextFieldCellIdentifier];
        cell.textFieldCellDelegate = self;
        cell.textField.returnKeyType = UIReturnKeyDone;
      }

      StringField *stringField =
          [self.currentStringFields objectAtIndex:indexPath.row];
      [cell setShowGrayBar:self.editing];

      cell.textLabel.text = stringField.key;
      cell.textField.text = stringField.value;
      cell.textField.enabled = self.editing;
      cell.textField.secureTextEntry = stringField.protected;

      if (stringField.protected && !self.editing) {
        UIImage *accessoryImage = [UIImage imageNamed:@"eye"];
        UIButton *accessoryButton =
            [UIButton buttonWithType:UIButtonTypeCustom];
        accessoryButton.frame = CGRectMake(0.0, 0.0, 40, 40);
        [accessoryButton setImage:accessoryImage forState:UIControlStateNormal];
        [accessoryButton addTarget:self
                            action:@selector(accessoryButtonTapped:withEvent:)
                  forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = accessoryButton;
      } else {
        cell.accessoryView = nil;
      }

      return cell;
    }
  }
  case SECTION_COMMENTS: {
    return commentsCell;
  }
  case SECTION_FILES: {
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"fileCell"];
    if (cell == nil) {
      cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                    reuseIdentifier:@"fileCell"];
    }
    Kdb4Entry *kdb4Entry = (Kdb4Entry *)self.entry;
    BinaryRef *ref = kdb4Entry.binaries[indexPath.row];
    cell.textLabel.text = ref.key;

    // picture check
    if ([ref.key hasSuffix:@".png"] || [ref.key hasSuffix:@".jpg"] ||
        [ref.key hasSuffix:@".jpeg"] || [ref.key hasSuffix:@".gif"]) {
      cell.imageView.image = [UIImage imageNamed:@"file-picture"];
    } else if ([ref.key hasSuffix:@".pdf"]) {
      cell.imageView.image = [UIImage imageNamed:@"file-pdf"];
    } else {
      cell.imageView.image = [UIImage imageNamed:@"file"];
    }
    return cell;
  }
  }

  return nil;
}

- (void)accessoryButtonTapped:(UIControl *)button withEvent:(UIEvent *)event {
  NSIndexPath *indexPath = [self.tableView
      indexPathForRowAtPoint:[[[event touchesForView:button] anyObject]
                                 locationInView:self.tableView]];
  if (indexPath == nil)
    return;

  [self.tableView.delegate tableView:self.tableView
      accessoryButtonTappedForRowWithIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView
    accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == SECTION_CUSTOM_FIELDS) {
    StringField *stringField =
        [self.currentStringFields objectAtIndex:indexPath.row];
    [self showStringOnHud:stringField.value];
  }
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
  switch (indexPath.section) {
  case SECTION_DEFAULT_FIELDS:
    break;
  case SECTION_CUSTOM_FIELDS: {
    switch (editingStyle) {
    case UITableViewCellEditingStyleInsert: {
      [self addPressed];
      break;
    }
    case UITableViewCellEditingStyleDelete: {
      TextFieldCell *cell =
          (TextFieldCell *)[tableView cellForRowAtIndexPath:indexPath];
      [cell.textField resignFirstResponder];

      [self.editingStringFields removeObjectAtIndex:indexPath.row];
      [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                       withRowAnimation:UITableViewRowAnimationBottom];
      break;
    }
    default:
      break;
    }
    break;
  }
  case SECTION_COMMENTS:
  case SECTION_FILES:
    break;
  }
}

- (BOOL)tableView:(UITableView *)tableView
    canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  NSIndexPath *expirePath = [self.tableView indexPathForCell:expireCell];
  if (indexPath == expirePath || indexPath.section == SECTION_FILES)
    return NO;
  return YES;
}

- (void)addPressed {
  StringField *stringField = [StringField stringFieldWithKey:@"" andValue:@""];

  StringFieldViewController *stringFieldViewController =
      [[StringFieldViewController alloc] initWithStringField:stringField];
  stringFieldViewController.donePressed = ^(
      FormViewController *formViewController) {
    [self updateStringField:(StringFieldViewController *)formViewController];
  };

  UINavigationController *navController = [[UINavigationController alloc]
      initWithRootViewController:stringFieldViewController];

  [self.navigationController presentViewController:navController
                                          animated:YES
                                        completion:nil];
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView
    heightForHeaderInSection:(NSInteger)section {
  // Special case for top section with no section title
  if (section == 0) {
    return 10.0f;
  }

  return [self tableView:tableView titleForHeaderInSection:section] == nil
             ? 0.0f
             : SECTION_HEADER_HEIGHT;
  ;
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  switch (indexPath.section) {
  case SECTION_DEFAULT_FIELDS:
  case SECTION_CUSTOM_FIELDS:
  case SECTION_FILES:
    return 40.0f;
  case SECTION_COMMENTS:
    return 228.0f;
  }

  return 40.0f;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
  switch (indexPath.section) {
  case SECTION_DEFAULT_FIELDS:
    return UITableViewCellEditingStyleNone;
  case SECTION_CUSTOM_FIELDS:
    if (self.isKdb4 && self.editing) {
      if (indexPath.row < self.currentStringFields.count) {
        return UITableViewCellEditingStyleDelete;
      } else {
        return UITableViewCellEditingStyleInsert;
      }
    }
    return UITableViewCellEditingStyleNone;
  case SECTION_COMMENTS:
  case SECTION_FILES:
    return UITableViewCellEditingStyleNone;
  }
  return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView
    shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
  return indexPath.section == SECTION_CUSTOM_FIELDS;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
    willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.editing && indexPath.section == SECTION_DEFAULT_FIELDS) {
    return nil;
  }
  return indexPath;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.editing) {
    if (indexPath.section != SECTION_CUSTOM_FIELDS) {
      [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
      return;
    }

    [self editStringField:indexPath];
  } else {
    if (indexPath.section == SECTION_FILES) {
      Kdb4Entry *kdb4Entry = (Kdb4Entry *)self.entry;
      BinaryRef *binaryReference = kdb4Entry.binaries[indexPath.row];

      Kdb4Tree *theTree = (Kdb4Tree *)[KeePassTouchAppDelegate appDelegate]
                              .databaseDocument.kdbTree;
      NSMutableArray *headerbins = theTree.dbVersion >= KDBX40_VERSION
                                       ? theTree.headerBinaries
                                       : theTree.binaries;

      // decoded Data Variable to write to File later
      NSData *base64DecodedData;

      if (theTree.dbVersion < KDBX40_VERSION) {
        // KDBX 3 (base64 encoded data in binary)
        Binary *attachment;

        // search in binary
        for (Binary *b in headerbins) {
          if (b.binaryId == binaryReference.ref) {
            attachment = b;
          }
        }

        if (attachment == nil) {
          [[TWMessageBarManager sharedInstance]
              showMessageWithTitle:@"Error"
                       description:@"failed to open document"
                              type:TWMessageBarMessageTypeError
                          duration:3.0
                   statusBarHidden:NO
                          callback:nil];
          [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
          return;
        }
        // decode base64 string to raw data
        base64DecodedData = [[NSData alloc]
            initWithBase64EncodedString:attachment.data
                                options:
                                    NSDataBase64DecodingIgnoreUnknownCharacters];

        // if compressed, decompress
        if (attachment.compressed) {
          base64DecodedData = base64DecodedData.decompressedData;
        }
      } else {
        // KDBX 4 (NSData in headerbinaries)
        if (binaryReference.ref < headerbins.count)
          base64DecodedData = headerbins[binaryReference.ref];
      }

      // Save it into file system
      NSString *tempDirectory = NSTemporaryDirectory();
      NSString *filePath =
          [tempDirectory stringByAppendingPathComponent:binaryReference.key];
      BOOL worked = [base64DecodedData writeToFile:filePath atomically:YES];

      // if it worked, show file
      if (worked) {
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        docu = [self documentInteractionControllerForURL:fileURL];
        [docu presentPreviewAnimated:YES];
      } else {
        [[TWMessageBarManager sharedInstance]
            showMessageWithTitle:@"Error"
                     description:@"failed to open document"
                            type:TWMessageBarMessageTypeError
                        duration:3.0
                 statusBarHidden:NO
                        callback:nil];
      }
      [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
      return;
    }
    if (![indexPath isEqual:[tableView indexPathForCell:expireCell]])
      [self copyCellContents:indexPath];
    else {

      // TODO: Einfügen von Date Picker
      [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
  }
}

- (void)copyCellContents:(NSIndexPath *)indexPath {
  self.tableView.allowsSelection = NO;

  UITableViewCell *rawCell = [self.tableView cellForRowAtIndexPath:indexPath];
  if (![rawCell isKindOfClass:[TextFieldCell class]])
    return;
  TextFieldCell *cell = (TextFieldCell *)rawCell;
  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  pasteboard.string = cell.textField.text;

  // Figure out frame for copied label
  NSString *copiedString = NSLocalizedString(@"Copied", nil);
  UIFont *font = [UIFont boldSystemFontOfSize:18];
  CGSize size = [copiedString
      sizeWithAttributes:[NSDictionary
                             dictionaryWithObjectsAndKeys:font,
                                                          NSFontAttributeName,
                                                          nil]];
  CGFloat x = (cell.frame.size.width - size.width) / 2.0;
  CGFloat y = (cell.frame.size.height - size.height) / 2.0;

  // Contruct label
  UILabel *copiedLabel =
      [[UILabel alloc] initWithFrame:CGRectMake(x, y, size.width, size.height)];
  copiedLabel.text = copiedString;
  copiedLabel.font = font;
  copiedLabel.textAlignment = NSTextAlignmentCenter;
  copiedLabel.textColor = [UIColor whiteColor];
  copiedLabel.backgroundColor = [UIColor clearColor];

  // Put cell into "Copied" state
  [cell addSubview:copiedLabel];
  cell.textField.alpha = 0;
  cell.textLabel.alpha = 0;
  cell.accessoryView.hidden = YES;

  int64_t delayInSeconds = 1.0;
  dispatch_time_t popTime =
      dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
    [UIView animateWithDuration:0.5
        animations:^{
          // Return to normal state
          copiedLabel.alpha = 0;
          cell.textField.alpha = 1;
          cell.textLabel.alpha = 1;
          [cell setSelected:NO animated:YES];
        }
        completion:^(BOOL finished) {
          cell.accessoryView.hidden = NO;
          [copiedLabel removeFromSuperview];
          self.tableView.allowsSelection = YES;
        }];
  });
}

#pragma mark - StringField related

- (void)editStringField:(NSIndexPath *)indexPath {
  // stop on invalid row here
  if (indexPath.row >= self.editingStringFields.count)
    return;
  StringField *stringField =
      [self.editingStringFields objectAtIndex:indexPath.row];

  StringFieldViewController *stringFieldViewController =
      [[StringFieldViewController alloc] initWithStringField:stringField];
  stringFieldViewController.object = indexPath;
  stringFieldViewController.donePressed = ^(
      FormViewController *formViewController) {
    [self updateStringField:(StringFieldViewController *)formViewController];
  };

  UINavigationController *navController = [[UINavigationController alloc]
      initWithRootViewController:stringFieldViewController];

  [self.navigationController presentViewController:navController
                                          animated:YES
                                        completion:nil];
}

- (void)updateStringField:(StringFieldViewController *)stringFieldController {
  if (stringFieldController.object == nil) {
    NSIndexPath *indexPath =
        [NSIndexPath indexPathForRow:self.editingStringFields.count
                           inSection:1];
    [self.editingStringFields addObject:stringFieldController.stringField];
    [self.tableView insertRowsAtIndexPaths:@[ indexPath ]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
  } else {
    NSIndexPath *indexPath = (NSIndexPath *)stringFieldController.object;
    [self.tableView reloadRowsAtIndexPaths:@[ indexPath ]
                          withRowAnimation:UITableViewRowAnimationAutomatic];
  }

  [stringFieldController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Image related / ImageSelectionViewDelegate

- (void)setSelectedImageIndex:(NSUInteger)index {
  _selectedImageIndex = index;
  UIImage *image = nil;
  if (self.isKdb4 && (((Kdb4Entry *)self.entry).customIconUuid != nil)) {
    image = [[ImageFactory sharedInstance] imageForEntry:self.entry];
  } else {
    image = [[ImageFactory sharedInstance] imageForIndex:index];
  }
  [titleCell.imageButton setImage:image forState:UIControlStateNormal];
}

- (void)imageButtonPressed {
  // TODO: ImageSelectionViewController erhält searchKey wenn nicht nil
  // Dann durchläuft ImageSelectionViewController alle Icons und zwar in der
  // Reihenfolge der Keys durch ALLKEYS ARRAY und dann ImageforKey für einzelne
  // Bilder und malt diese in Zeilen / Spalten Wenn die Auswahl > als die
  // Standardicons, also NUM_IMAGES sind rufe Delegate
  // selectedImageCustomWithKey auf mit aus ALLKEYS Array Object Nummer
  // OBJECTNUMBER_IN_TABLE - NUM_IMAGES ergibt 0 für erstes neues.
  //
  if (self.tableView.isEditing) {
    ImageSelectionViewController *imageSelectionViewController =
        [[ImageSelectionViewController alloc] init];
    imageSelectionViewController.imageSelectionView.delegate = self;
    if (_selectedImageIndex == 0 && self.searchKey != nil) {
      NSUInteger keyIndex =
          [[ImageFactory sharedInstance] indexForKey:self.searchKey];
      if (keyIndex != NSUIntegerMax) {
        imageSelectionViewController.customIndex = keyIndex;
      }
    } else {
      imageSelectionViewController.imageSelectionView.selectedImageIndex =
          _selectedImageIndex;
    }
    [self.navigationController pushViewController:imageSelectionViewController
                                         animated:YES];
  }
}

- (void)imageSelectionView:(ImageSelectionView *)imageSelectionView
        selectedImageIndex:(NSUInteger)imageIndex {
  [self setSelectedImageIndex:imageIndex];
}

- (void)imageSelectionView:(ImageSelectionView *)imageSelectionView
    selectedImageCustomWithKey:(NSString *)key {
  self.searchKey = key;
  Kdb4Entry *customEntry = (Kdb4Entry *)self.entry;
  customEntry.image = 0;
  customEntry.customIconUuid =
      [[KdbUUID alloc] initWithData:[KdbUUID stringToData:key]];
  [self setSelectedImageIndex:0];
  // self.entry = customEntry;
  // TODO: REFERENZ ODER NICHT
}

#pragma mark - Password Display

- (void)showStringOnHud:(NSString *)string {
  MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];

  hud.mode = MBProgressHUDModeText;
  hud.detailsLabel.text = string;
  hud.detailsLabel.font = [UIFont fontWithName:@"Andale Mono" size:24];
  hud.margin = 10.f;
  hud.removeFromSuperViewOnHide = YES;
  [hud addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                initWithTarget:hud
                                        action:@selector(hide:)]];
}

- (void)showPasswordPressed {
  [self showStringOnHud:self.entry.password];
}

#pragma mark - Password Generation

- (void)generatePasswordPressed {
  PasswordGeneratorViewController *passwordGeneratorViewController =
      [[PasswordGeneratorViewController alloc] init];
  passwordGeneratorViewController.delegate = self;

  UINavigationController *navigationController = [[UINavigationController alloc]
      initWithRootViewController:passwordGeneratorViewController];

  [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)passwordGeneratorViewController:
            (PasswordGeneratorViewController *)controller
                               password:(NSString *)password {
  passwordCell.textField.text = password;
}

- (void)openUrlPressed {
  NSString *text = urlCell.textField.text;

  NSURL *url = [NSURL URLWithString:text];
  if (url.scheme == nil) {
    url = [NSURL URLWithString:[@"http://" stringByAppendingString:text]];
  }

  BOOL isHttp = [url.scheme isEqualToString:@"http"] ||
                [url.scheme isEqualToString:@"https"];

  BOOL webBrowserIntegrated =
      [[AppSettings sharedInstance] webBrowserIntegrated];
  if (webBrowserIntegrated && isHttp) {
    WebViewController *webViewController = [[WebViewController alloc] init];
    webViewController.entry = self.entry;
    [self.navigationController pushViewController:webViewController
                                         animated:YES];
  } else {
    [[UIApplication sharedApplication] openURL:url
                                       options:@{}
                             completionHandler:nil];
  }
}

@end
