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

#import "GroupViewController.h"
#import "AppSettings.h"
#import "EditItemViewController.h"
#import "EntryViewController.h"
#import "GroupSearchDataSource.h"
#import "ImageFactory.h"
#import "Kdb3Node.h"
#import "SelectGroupViewController.h"

#import "KeyChainUtils.h"
#import "constants.h"

#import "KeePassTouchAppDelegate.h"

#import "KPBiometrics.h"
#import <AuthenticationServices/AuthenticationServices.h>

enum { SECTION_GROUPS, SECTION_ENTRIES, NUM_SECTIONS };

@interface GroupViewController () <UISearchControllerDelegate>

@property(nonatomic, strong) NSMutableArray *groupsArray;
@property(nonatomic, strong) NSMutableArray *entriesArray;

@property(nonatomic, weak) KeePassTouchAppDelegate *appDelegate;

@property(nonatomic, assign) BOOL sortingEnabled;
@property(nonatomic, strong) NSComparisonResult (^groupComparator)
    (id obj1, id obj2);
@property(nonatomic, strong) NSComparisonResult (^entryComparator)
    (id obj1, id obj2);

@property(nonatomic, strong) NSArray *standardToolbarItems;
@property(nonatomic, strong) NSArray *editingToolbarItems;

@property(nonatomic, strong) UIBarButtonItem *deleteButton;
@property(nonatomic, strong) UIBarButtonItem *moveButton;
@property(nonatomic, strong) UIBarButtonItem *renameButton;

@property(nonatomic, strong) GroupSearchDataSource *searchDataSource;
@property(nonatomic, strong) UISearchController *searchController;

@property(nonatomic, strong)
    UIDocumentInteractionController *documentInteractionController;

@end

@implementation GroupViewController

- (id)initWithGroup:(KdbGroup *)group {
  self = [super initWithStyle:UITableViewStylePlain];
  if (self) {
    _group = group;

    if (_group.parent == nil) {
      dispatch_async(
          dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
          ^(void) {
            [self updateCredentialStore];
          });
    }

    // Get the app delegate
    self.appDelegate = [KeePassTouchAppDelegate appDelegate];

    // Configure the various buttons
    self.toolbarItems = self.standardToolbarItems;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;

    // Configure the table
    self.title = self.group.name;
    self.tableView.allowsSelectionDuringEditing = YES;

    self.searchDataSource = [[GroupSearchDataSource alloc] init];
    self.searchDataSource.groupViewController = self;
    self.searchController =
        [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.delegate = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.autocapitalizationType =
        UITextAutocapitalizationTypeNone;

    if (@available(iOS 11.0, *)) {
      // For iOS 11 and later, place the search bar in the navigation bar.
      self.navigationItem.searchController = self.searchController;

      // Make the search bar always visible.
      self.navigationItem.hidesSearchBarWhenScrolling = NO;
    } else {
      // For iOS 10 and earlier, place the search controller's search bar in the
      // table view's header.
      self.tableView.tableHeaderView = self.searchController.searchBar;
    }

    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
    self.searchController.searchResultsUpdater = self.searchDataSource;

    // Get sort settings, and create the sort comparators
    self.sortingEnabled = [[AppSettings sharedInstance] sortAlphabetically];

    self.groupComparator = ^(id obj1, id obj2) {
      NSString *string1 = ((KdbGroup *)obj1).name;
      NSString *string2 = ((KdbGroup *)obj2).name;
      return [string1 localizedCaseInsensitiveCompare:string2];
    };

    self.entryComparator = ^(id obj1, id obj2) {
      NSString *string1 = ((KdbEntry *)obj1).title;
      NSString *string2 = ((KdbEntry *)obj2).title;
      return [string1 localizedCaseInsensitiveCompare:string2];
    };

    // Update the view model from the group information
    [self updateViewModel];
  }
  return self;
}

- (void)viewWillAppear:(BOOL)animated {
  // Update the search bar's placeholder
  self.searchController.searchBar.placeholder = [NSString
      stringWithFormat:@"%@ %@", NSLocalizedString(@"Search", nil), self.title];

  NSArray *selectedIndexPaths = [self.tableView indexPathsForSelectedRows];
  if ([selectedIndexPaths count] > 1) {
    [super viewWillAppear:animated];
    return;
  }

  BOOL sortAlphabetically = [[AppSettings sharedInstance] sortAlphabetically];
  if (self.sortingEnabled != sortAlphabetically) {
    // The sorting option changed, reload the entire dataset
    self.sortingEnabled = sortAlphabetically;
    [self updateViewModel];
    [self.tableView reloadData];
  } else {
    // Reload the cell in case the title was changed by the entry view
    NSIndexPath *selectedIndexPath = [selectedIndexPaths objectAtIndex:0];
    if (selectedIndexPath != nil) {
      NSMutableArray *array;
      switch (selectedIndexPath.section) {
      case SECTION_GROUPS:
        array = self.groupsArray;
        break;
      case SECTION_ENTRIES:
        array = self.entriesArray;
        break;
      default:
        @throw [NSException exceptionWithName:@"RuntimeException"
                                       reason:@"Invalid Section"
                                     userInfo:nil];
        break;
      }

      NSUInteger index = selectedIndexPath.row;
      if (self.sortingEnabled) {
        // Remove and re-add object to maintain sorting
        id object = [array objectAtIndex:index];
        [array removeObjectAtIndex:index];
        index = [self addObject:object toArray:array];
      }

      // The row might have moved or changed contents, just reload the data
      [self.tableView reloadData];

      // Re-select the row (it might have changed)
      selectedIndexPath =
          [NSIndexPath indexPathForRow:index
                             inSection:selectedIndexPath.section];
      [self.tableView selectRowAtIndexPath:selectedIndexPath
                                  animated:NO
                            scrollPosition:UITableViewScrollPositionNone];
    }
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
  }

  for (UIActivityIndicatorView *spinner in self.navigationController.view
           .subviews) {
    if (spinner.tag == 1007)
      [spinner removeFromSuperview];
  }
  [super viewWillAppear:animated];
}

- (void)willPresentSearchController:(UISearchController *)searchController {
  self.tableView.dataSource = self.searchDataSource;
  self.tableView.delegate = self.searchDataSource;
}

- (void)willDismissSearchController:(UISearchController *)searchController {
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  [self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];

  if (_documentInteractionController != nil) {
    [_documentInteractionController dismissMenuAnimated:NO];
  }
}

- (NSArray *)standardToolbarItems {
  if (_standardToolbarItems == nil) {
    UIBarButtonItem *settingsButton =
        [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear"]
                                         style:UIBarButtonItemStylePlain
                                        target:self.appDelegate
                                        action:@selector(showSettingsView)];

    UIBarButtonItem *actionButton = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                             target:self
                             action:@selector(exportFilePressed:)];

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                             target:self
                             action:@selector(addPressed)];

    UIBarButtonItem *changeMasterPassword =
        [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"key"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(changeMasterPassword)];

    UIBarButtonItem *spacer = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                             target:nil
                             action:nil];
    if (_group.parent == nil) {
      _standardToolbarItems = @[
        settingsButton, spacer, actionButton, spacer, changeMasterPassword,
        spacer, addButton
      ];
    } else
      _standardToolbarItems =
          @[ settingsButton, spacer, actionButton, spacer, addButton ];
  }

  return _standardToolbarItems;
}

- (NSArray *)editingToolbarItems {
  if (_editingToolbarItems == nil) {

    self.deleteButton = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                             target:self
                             action:@selector(deleteSelectedItems)];
    self.deleteButton.tintColor = [UIColor colorWithRed:0.8
                                                  green:0.15
                                                   blue:0.15
                                                  alpha:1];
    self.deleteButton.enabled = NO;

    self.moveButton =
        [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"move"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(moveSelectedItems)];
    self.moveButton.enabled = NO;

    self.renameButton =
        [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"rename"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(renameSelectedItem)];
    self.renameButton.enabled = NO;

    UIBarButtonItem *spacer = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                             target:nil
                             action:nil];

    _editingToolbarItems = @[
      self.deleteButton, spacer, self.moveButton, spacer, self.renameButton
    ];
  }

  return _editingToolbarItems;
}

- (UIDocumentInteractionController *)documentInteractionController {
  if (_documentInteractionController == nil) {
    NSURL *url =
        [NSURL fileURLWithPath:self.appDelegate.databaseDocument.filename];
    _documentInteractionController =
        [UIDocumentInteractionController interactionControllerWithURL:url];
  }
  return _documentInteractionController;
}

- (void)setSeachBar:(UISearchBar *)searchBar enabled:(BOOL)enabled {
  static UIView *overlayView = nil;
  if (overlayView == nil) {
    overlayView = [[UIView alloc] initWithFrame:searchBar.frame];
    overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    overlayView.backgroundColor = [UIColor darkGrayColor];
    overlayView.alpha = 0.0;
  }

  searchBar.userInteractionEnabled = enabled;
  if (enabled) {
    [UIView animateWithDuration:0.3
        animations:^{
          overlayView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          [overlayView removeFromSuperview];
          overlayView = nil;
        }];
  } else {
    [searchBar addSubview:overlayView];
    [UIView animateWithDuration:0.3
                     animations:^{
                       overlayView.alpha = 0.25;
                     }];
  }
}

- (void)updateViewModel {
  self.groupsArray = [[NSMutableArray alloc] initWithArray:self.group.groups];
  self.entriesArray = [[NSMutableArray alloc] initWithArray:self.group.entries];

  if (self.sortingEnabled) {
    [self.groupsArray sortUsingComparator:self.groupComparator];
    [self.entriesArray sortUsingComparator:self.entryComparator];
  }
}

- (void)pushViewControllerForGroup:(KdbGroup *)group {
  GroupViewController *groupViewController =
      [[GroupViewController alloc] initWithGroup:group];

  [self.navigationController pushViewController:groupViewController
                                       animated:YES];
}

- (void)pushViewControllerForEntry:(KdbEntry *)entry {

  if (@available(iOS 11.0, *)) {
    // For iOS 11 and later, place the search bar in the navigation bar.

  } else {
    // For iOS 10 and earlier, place the search controller's search bar in the
    // table view's header.
    if (self.searchController.active)
      [self.searchController setActive:NO];
  }

  EntryViewController *entryViewController =
      [[EntryViewController alloc] initWithStyle:UITableViewStyleGrouped];
  entryViewController.entry = entry;
  entryViewController.title = entry.title;

  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    if (self.searchController.active)
      [self.searchController setActive:NO];
  }];
  [self.navigationController pushViewController:entryViewController
                                       animated:YES];
  [CATransaction commit];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
  // Disable multiple select to enable swipe to delete when not editing
  self.tableView.allowsMultipleSelectionDuringEditing = editing;

  [super setEditing:editing animated:animated];

  // If any cell is showing the delete confirmation swipe gesture was used,
  // don't configure toolbar
  NSArray *cells = self.tableView.visibleCells;
  for (UITableViewCell *cell in cells) {
    if (cell.showingDeleteConfirmation) {
      return;
    }
  }

  if (editing) {
    [self.navigationItem setHidesBackButton:YES animated:YES];
    [self setSeachBar:self.searchController.searchBar enabled:NO];

    self.toolbarItems = self.editingToolbarItems;
    [self updateEditingButtons];
  } else {
    [self.navigationItem setHidesBackButton:NO animated:YES];
    [self setSeachBar:self.searchController.searchBar enabled:YES];

    self.toolbarItems = self.standardToolbarItems;
  }
}

- (void)updateEditingButtons {
  NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
  NSUInteger numSelectedRows = [selectedRows count];
  if (numSelectedRows != 0) {
    self.deleteButton.title = [NSLocalizedString(@"Delete", nil)
        stringByAppendingFormat:@" (%lu)", (unsigned long)numSelectedRows];
    self.deleteButton.enabled = YES;

    self.moveButton.title = [NSLocalizedString(@"Move", nil)
        stringByAppendingFormat:@" (%lu)", (unsigned long)numSelectedRows];
    self.moveButton.enabled = YES;

    self.renameButton.title = [NSLocalizedString(@"Rename", nil)
        stringByAppendingFormat:@" (%lu)", (unsigned long)numSelectedRows];
    self.renameButton.enabled = numSelectedRows == 1;
  } else {
    self.deleteButton.title = NSLocalizedString(@"Delete", nil);
    self.deleteButton.enabled = NO;

    self.moveButton.title = NSLocalizedString(@"Move", nil);
    self.moveButton.enabled = NO;

    self.renameButton.title = NSLocalizedString(@"Rename", nil);
    self.renameButton.enabled = NO;
  }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return NUM_SECTIONS;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
  switch (section) {
  case SECTION_GROUPS:
    if ([self.groupsArray count] != 0) {
      return NSLocalizedString(@"Groups", nil);
    }
    break;

  case SECTION_ENTRIES:
    if ([self.entriesArray count] != 0) {
      return NSLocalizedString(@"Entries", nil);
    }
    break;
  }

  return nil;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  switch (section) {
  case SECTION_GROUPS:
    return [self.groupsArray count];
  case SECTION_ENTRIES:
    return [self.entriesArray count];
  }
  return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = nil;

  // Create either a group or entry cell
  switch (indexPath.section) {
  case SECTION_GROUPS: {
    KdbGroup *g = [self.groupsArray objectAtIndex:indexPath.row];
    cell = [self tableView:tableView cellForGroup:g];
    break;
  }
  case SECTION_ENTRIES: {
    KdbEntry *e = [self.entriesArray objectAtIndex:indexPath.row];
    cell = [self tableView:tableView cellForEntry:e];
    break;
  }
  }

  return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
                  cellForGroup:(KdbGroup *)g {
  static NSString *CellIdentifier = @"CellGroup";

  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:CellIdentifier];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.accessoryView.tintColor = [UIColor blueColor];
    cell.tintColor = [UIColor blueColor];
  }

  // Configure the cell
  cell.textLabel.text = g.name;
  cell.imageView.image = [[ImageFactory sharedInstance] imageForGroup:g];

  return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
                  cellForEntry:(KdbEntry *)e {
  static NSString *CellIdentifier = @"CellEntry";

  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                  reuseIdentifier:CellIdentifier];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  }

  // Configure the cell
  cell.textLabel.text = e.title;
  cell.imageView.image = [[ImageFactory sharedInstance] imageForEntry:e];

  // Detail text is a combination of username and url
  NSString *detailText = @"";
  if (e.username.length > 0) {
    detailText = e.username;
  }
  if (e.url.length > 0) {
    if (detailText.length > 0) {
      detailText = [NSString stringWithFormat:@"%@ @ %@", detailText, e.url];
    } else {
      detailText = e.url;
    }
  }
  cell.detailTextLabel.text = detailText;

  return cell;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle != UITableViewCellEditingStyleDelete) {
    return;
  }

  [self deleteElementsFromModelAtIndexPaths:@[ indexPath ]];

  NSUInteger numRows = 0;
  switch (indexPath.section) {
  case SECTION_GROUPS:
    numRows = [self.groupsArray count];
    break;
  case SECTION_ENTRIES:
    numRows = [self.entriesArray count];
    break;
  }

  if (numRows == 0) {
    // Reload the section if there are no more rows
    [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section]
             withRowAnimation:UITableViewRowAnimationAutomatic];
  } else {
    // Delete the row
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                     withRowAnimation:UITableViewRowAnimationAutomatic];
  }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.editing == NO) {
    switch (indexPath.section) {
    case SECTION_GROUPS: {
      [self pushViewControllerForGroup:[self.groupsArray
                                           objectAtIndex:indexPath.row]];
      break;
    }
    case SECTION_ENTRIES: {
      [self pushViewControllerForEntry:[self.entriesArray
                                           objectAtIndex:indexPath.row]];
      break;
    }
    }
  } else {
    [self updateEditingButtons];
  }
}

- (void)tableView:(UITableView *)tableView
    didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.editing) {
    [self updateEditingButtons];
  }
}

#pragma mark - Export Database

- (void)exportFilePressed:(id)sender {
  UIBarButtonItem *actionButton = sender;
  BOOL didShow = [self.documentInteractionController
      presentOpenInMenuFromBarButtonItem:actionButton
                                animated:YES];
  if (!didShow) {
    NSString *prompt = NSLocalizedString(@"There are no applications installed "
                                         @"capable of importing KeePass files",
                                         nil);

    UIAlertController *actionSheetCon = [UIAlertController
        alertControllerWithTitle:prompt
                         message:nil
                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelOKAction =
        [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                 style:UIAlertActionStyleCancel
                               handler:nil];
    [actionSheetCon addAction:cancelOKAction];
    [self presentViewController:actionSheetCon animated:YES completion:nil];
  }
}

- (void)changeMasterPassword {
  DatabaseDocument *database = self.appDelegate.databaseDocument;

  NewKdbViewController *kdbVC = [[NewKdbViewController alloc] init];
  kdbVC.versionSegmentedControl.hidden = YES;
  kdbVC.controls = @[ kdbVC.controls[1], kdbVC.controls[2] ];
  kdbVC.headerTitle = NSLocalizedString(@"Change Database Password", nil);

  kdbVC.nameTextField.text = database.filename;
  kdbVC.donePressed = ^(FormViewController *formViewController) {
    NewKdbViewController *newKDBFinishedVC =
        (NewKdbViewController *)formViewController;

    if (newKDBFinishedVC.passwordTextField1.text.length == 0) {
      [formViewController
          showErrorMessage:NSLocalizedString(@"Password is required", nil)];
      return;
    }
    if (![newKDBFinishedVC.passwordTextField1.text
            isEqualToString:newKDBFinishedVC.passwordTextField2.text]) {
      [formViewController
          showErrorMessage:NSLocalizedString(@"Passwords do not match", nil)];
      return;
    }

    [database saveWithNewPassword:newKDBFinishedVC.passwordTextField1.text];

    // Load the password if present

    NSString *password =
        [KeychainUtils stringForKey:database.filename.lastPathComponent
                     andServiceName:KPT_PASSWORD_SERVICE];

    // Store the new password inside
    if (password) {
      [KeychainUtils setString:newKDBFinishedVC.passwordTextField1.text
                        forKey:database.filename.lastPathComponent
                andServiceName:KPT_PASSWORD_SERVICE];
    }
    [newKDBFinishedVC dismissViewControllerAnimated:YES completion:nil];
  };
  UINavigationController *navVC =
      [[UINavigationController alloc] initWithRootViewController:kdbVC];
  [self.navigationController presentViewController:navVC
                                          animated:YES
                                        completion:nil];
}

#pragma mark - Add Group/Entry

- (void)addPressed {
  UIAlertController *alertCon = [UIAlertController
      alertControllerWithTitle:NSLocalizedString(@"Add", nil)
                       message:nil
                preferredStyle:UIAlertControllerStyleActionSheet];
  UIAlertAction *cancelAction =
      [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                               style:UIAlertActionStyleCancel
                             handler:nil];
  UIAlertAction *groupAction = [UIAlertAction
      actionWithTitle:NSLocalizedString(@"Group", nil)
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *_Nonnull action) {
                NSIndexPath *indexPath = [self addNewGroup];

                // Notify the table of the new row
                if ([self tableView:self.tableView
                        numberOfRowsInSection:indexPath.section] == 1) {
                  // Reload the section if it's the first item
                  NSIndexSet *indexSet =
                      [NSIndexSet indexSetWithIndex:indexPath.section];
                  [self.tableView
                        reloadSections:indexSet
                      withRowAnimation:UITableViewRowAnimationAutomatic];
                } else {
                  // Insert the new row
                  [self.tableView
                      insertRowsAtIndexPaths:@[ indexPath ]
                            withRowAnimation:UITableViewRowAnimationAutomatic];
                }

                // Select the row
                [self.tableView
                    selectRowAtIndexPath:indexPath
                                animated:YES
                          scrollPosition:UITableViewScrollPositionTop];
              }];

  [alertCon addAction:groupAction];
  if (self.group.canAddEntries) {
    UIAlertAction *entryAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"Entry", nil)
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *_Nonnull action) {
                  NSIndexPath *indexPath = [self addNewEntry];

                  // Notify the table of the new row
                  if ([self tableView:self.tableView
                          numberOfRowsInSection:indexPath.section] == 1) {
                    // Reload the section if it's the first item
                    NSIndexSet *indexSet =
                        [NSIndexSet indexSetWithIndex:indexPath.section];
                    [self.tableView
                          reloadSections:indexSet
                        withRowAnimation:UITableViewRowAnimationAutomatic];
                  } else {
                    // Insert the new row
                    [self.tableView insertRowsAtIndexPaths:@[ indexPath ]
                                          withRowAnimation:
                                              UITableViewRowAnimationAutomatic];
                  }

                  // Select the row
                  [self.tableView
                      selectRowAtIndexPath:indexPath
                                  animated:YES
                            scrollPosition:UITableViewScrollPositionTop];
                }];
    [alertCon addAction:entryAction];
  }

  [alertCon addAction:cancelAction];
  alertCon.modalPresentationStyle = UIModalPresentationPopover;
  alertCon.popoverPresentationController.barButtonItem =
      [_standardToolbarItems lastObject];
  [self presentViewController:alertCon animated:YES completion:nil];
}

- (NSIndexPath *)addNewGroup {
  DatabaseDocument *databaseDocument = self.appDelegate.databaseDocument;

  // Create and add a group
  KdbGroup *g = [databaseDocument.kdbTree createGroup:self.group];
  g.name = NSLocalizedString(@"New Group", nil);
  g.image = self.group.image;
  [self.group addGroup:g];
  NSUInteger index = [self addObject:g toArray:self.groupsArray];

  // Save the database
  [databaseDocument save];

  EditItemViewController *editItemViewController =
      [[EditItemViewController alloc] initWithGroup:g];
  editItemViewController.donePressed =
      ^(FormViewController *formViewController) {
        [self renameItem:(EditItemViewController *)formViewController];
      };
  editItemViewController.cancelPressed =
      ^(FormViewController *formViewController) {
        [formViewController dismissViewControllerAnimated:YES completion:nil];
        [self setEditing:NO animated:YES];
      };

  UINavigationController *navigationController = [[UINavigationController alloc]
      initWithRootViewController:editItemViewController];
  [self.appDelegate.window.rootViewController
      presentViewController:navigationController
                   animated:YES
                 completion:nil];

  return [NSIndexPath indexPathForRow:index inSection:SECTION_GROUPS];
}

- (NSIndexPath *)addNewEntry {
  DatabaseDocument *databaseDocument = self.appDelegate.databaseDocument;

  // Create and add an entry
  KdbEntry *e = [databaseDocument.kdbTree createEntry:self.group];
  e.title = NSLocalizedString(@"New Entry", nil);
  e.image = self.group.image;
  [self.group addEntry:e];
  NSUInteger index = [self addObject:e toArray:self.entriesArray];

  // Save the database
  [databaseDocument save];

  EntryViewController *entryViewController =
      [[EntryViewController alloc] initWithStyle:UITableViewStyleGrouped];
  entryViewController.entry = e;
  entryViewController.title = e.title;
  entryViewController.isNewEntry = YES;
  [self.navigationController pushViewController:entryViewController
                                       animated:YES];

  return [NSIndexPath indexPathForRow:index inSection:SECTION_ENTRIES];
}

- (NSUInteger)addObject:(id)object toArray:(NSMutableArray *)array {
  NSUInteger index;
  if (self.sortingEnabled) {
    NSComparisonResult (^comparator)(id obj1, id obj2);
    if ([object isKindOfClass:[KdbGroup class]]) {
      // Object is a KdbGroup, use groupComparator
      comparator = self.groupComparator;
    } else if ([object isKindOfClass:[KdbEntry class]]) {
      // Object is a KdbEntry, use entryComparator
      comparator = self.entryComparator;
    } else {
      @throw [NSException exceptionWithName:@"RuntimeException"
                                     reason:@"Invalid object type"
                                   userInfo:nil];
    }

    index = [array indexOfObject:object
                   inSortedRange:NSMakeRange(0, [array count])
                         options:NSBinarySearchingInsertionIndex
                 usingComparator:comparator];
  } else {
    index = [array count];
  }

  [array insertObject:object atIndex:index];
  return index;
}

#pragma mark - Delete Groups/Entries

- (void)deleteSelectedItems {
  NSArray *indexPaths = self.tableView.indexPathsForSelectedRows;
  [self deleteElementsFromModelAtIndexPaths:indexPaths];
  [self.tableView deleteRowsAtIndexPaths:indexPaths
                        withRowAnimation:UITableViewRowAnimationAutomatic];

  // Clean up section headers
  NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
  if ([self.groupsArray count] == 0) {
    [indexSet addIndex:SECTION_GROUPS];
  }
  if ([self.entriesArray count] == 0) {
    [indexSet addIndex:SECTION_ENTRIES];
  }
  [self.tableView reloadSections:indexSet
                withRowAnimation:UITableViewRowAnimationFade];

  [self setEditing:NO animated:YES];
}

- (void)deleteElementsFromModelAtIndexPaths:(NSArray *)indexPaths {
  NSMutableArray *groupsToRemove = [NSMutableArray array];
  NSMutableArray *enteriesToRemove = [NSMutableArray array];

  // Find items to remove
  for (NSIndexPath *indexPath in indexPaths) {
    if (indexPath.section == SECTION_GROUPS) {
      [groupsToRemove addObject:[self.groupsArray objectAtIndex:indexPath.row]];
    } else if (indexPath.section == SECTION_ENTRIES) {
      [enteriesToRemove
          addObject:[self.entriesArray objectAtIndex:indexPath.row]];
    }
  }

  // Remove groups
  for (KdbGroup *g in groupsToRemove) {
    [self.group removeGroup:g];
    [self.groupsArray removeObject:g];
  }

  // Remote Enteries
  for (KdbEntry *e in enteriesToRemove) {
    [self.group removeEntry:e];
    [self.entriesArray removeObject:e];
  }

  // Save the database
  DatabaseDocument *databaseDocument = self.appDelegate.databaseDocument;
  [databaseDocument save];
}

#pragma mark - Rename Group/Entry

- (void)renameSelectedItem {
  EditItemViewController *editItemViewController;

  NSIndexPath *indexPath =
      [self.tableView.indexPathsForSelectedRows objectAtIndex:0];
  switch (indexPath.section) {
  case SECTION_GROUPS: {
    KdbGroup *g = [self.groupsArray objectAtIndex:indexPath.row];
    editItemViewController = [[EditItemViewController alloc] initWithGroup:g];
    break;
  }
  case SECTION_ENTRIES: {
    KdbEntry *e = [self.entriesArray objectAtIndex:indexPath.row];
    editItemViewController = [[EditItemViewController alloc] initWithEntry:e];
    break;
  }
  }

  editItemViewController.donePressed =
      ^(FormViewController *formViewController) {
        [self renameItem:(EditItemViewController *)formViewController];
      };
  editItemViewController.cancelPressed =
      ^(FormViewController *formViewController) {
        [formViewController dismissViewControllerAnimated:YES completion:nil];
        [self setEditing:NO animated:YES];
      };

  UINavigationController *navigationController = [[UINavigationController alloc]
      initWithRootViewController:editItemViewController];
  [self.appDelegate.window.rootViewController
      presentViewController:navigationController
                   animated:YES
                 completion:nil];
}

- (void)renameItem:(EditItemViewController *)editItemViewController {
  NSString *newName = editItemViewController.nameTextField.text;
  if (newName.length == 0) {
    [editItemViewController
        showErrorMessage:NSLocalizedString(@"New name is invalid", nil)];
    return;
  }

  NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
  switch (indexPath.section) {
  case SECTION_GROUPS: {
    // Update the group
    KdbGroup *g = [self.groupsArray objectAtIndex:indexPath.row];
    g.name = newName;
    g.image = editItemViewController.selectedImageIndex;
    if (editItemViewController.isKdb4 && g.image == 0 &&
        editItemViewController.searchKey != nil) {
      ((Kdb4Group *)g).customIconUuid = [[KdbUUID alloc]
          initWithData:[KdbUUID stringToData:editItemViewController.searchKey]];
    }
    break;
  }

  case SECTION_ENTRIES: {
    // Update the entry
    KdbEntry *e = [self.entriesArray objectAtIndex:indexPath.row];
    e.title = newName;
    e.image = editItemViewController.selectedImageIndex;
    if (editItemViewController.isKdb4 && e.image == 0 &&
        editItemViewController.searchKey != nil) {
      ((Kdb4Entry *)e).customIconUuid = [[KdbUUID alloc]
          initWithData:[KdbUUID stringToData:editItemViewController.searchKey]];
    }
    break;
  }
  }

  // Save the document
  [self.appDelegate.databaseDocument save];

  [editItemViewController dismissViewControllerAnimated:YES completion:nil];

  [self setEditing:NO animated:YES];
  [self.tableView reloadData];
}

#pragma mark - Move Groups/Entries

- (void)moveSelectedItems {
  SelectGroupViewController *selectGroupViewController =
      [[SelectGroupViewController alloc] initWithStyle:UITableViewStylePlain];
  selectGroupViewController.delegate = self;
  UINavigationController *navController = [[UINavigationController alloc]
      initWithRootViewController:selectGroupViewController];

  [self.appDelegate.window.rootViewController
      presentViewController:navController
                   animated:YES
                 completion:nil];
}

- (BOOL)selectGroupViewController:
            (SelectGroupViewController *)selectGroupViewController
                   canSelectGroup:(KdbGroup *)g {
  BOOL validGroup = YES;
  BOOL containsEntry = NO;

  // Check if chosen group is a subgroup of any groups to be moved
  for (NSIndexPath *indexPath in self.tableView.indexPathsForSelectedRows) {
    switch (indexPath.section) {
    case SECTION_GROUPS: {
      KdbGroup *movingGroup = [self.groupsArray objectAtIndex:indexPath.row];
      if (movingGroup.parent == g) {
        validGroup = NO;
      }
      if ([movingGroup containsGroup:g]) {
        validGroup = NO;
      }
      break;
    }

    case SECTION_ENTRIES: {
      containsEntry = YES;
      KdbEntry *movingEntry = [self.entriesArray objectAtIndex:indexPath.row];
      if (movingEntry.parent == g) {
        validGroup = NO;
      }
      break;
    }
    }

    if (!validGroup) {
      break;
    }
  }

  // Failed subgroup check
  if (!validGroup) {
    return NO;
  }

  // Check if trying to move entries to top level in 1.x database
  KdbTree *tree = self.appDelegate.databaseDocument.kdbTree;
  if (containsEntry && g == tree.root &&
      [tree isKindOfClass:[Kdb3Tree class]]) {
    return NO;
  }

  return YES;
}

- (void)selectGroupViewController:
            (SelectGroupViewController *)selectGroupViewController
                    selectedGroup:(KdbGroup *)selectedGroup {
  NSArray *indexPaths = self.tableView.indexPathsForSelectedRows;

  // Find items to move
  NSMutableArray *groupsToMove =
      [NSMutableArray arrayWithCapacity:[indexPaths count]];
  NSMutableArray *enteriesToMove =
      [NSMutableArray arrayWithCapacity:[indexPaths count]];

  for (NSIndexPath *indexPath in indexPaths) {
    switch (indexPath.section) {
    case SECTION_GROUPS:
      [groupsToMove addObject:[self.groupsArray objectAtIndex:indexPath.row]];
      break;
    case SECTION_ENTRIES:
      [enteriesToMove
          addObject:[self.entriesArray objectAtIndex:indexPath.row]];
      break;
    }
  }

  // Add desired items to chosen group
  for (KdbGroup *movingGroup in groupsToMove) {
    if (movingGroup.parent == selectedGroup) {
      continue;
    }
    [movingGroup.parent moveGroup:movingGroup toGroup:selectedGroup];
    [self.groupsArray removeObject:movingGroup];
  }
  for (KdbEntry *movingEntry in enteriesToMove) {
    if (movingEntry.parent == selectedGroup) {
      continue;
    }
    [movingEntry.parent moveEntry:movingEntry toGroup:selectedGroup];
    [self.entriesArray removeObject:movingEntry];
  }

  // Save the database
  DatabaseDocument *databaseDocument = self.appDelegate.databaseDocument;
  [databaseDocument save];

  // Update the table
  [self.tableView deleteRowsAtIndexPaths:indexPaths
                        withRowAnimation:UITableViewRowAnimationAutomatic];

  [self setEditing:NO animated:YES];
}

#pragma mark - Credential Store (> iOS 12)

- (void)updateCredentialStore {
  if (@available(iOS 12.0, *)) {
    // check first if quick unlock via biometrics is available, if not, don't
    // use ASCredentialIdentityStore
    if (![KPBiometrics hasBiometrics])
      return;
    ASCredentialIdentityStore *store = [ASCredentialIdentityStore sharedStore];
    [store getCredentialIdentityStoreStateWithCompletion:^(
               ASCredentialIdentityStoreState *_Nonnull state) {
      if ([state isEnabled]) {
        [[ASCredentialIdentityStore sharedStore]
            removeAllCredentialIdentitiesWithCompletion:^(
                BOOL success, NSError *_Nullable error) {
              if (success) {
                NSArray<ASPasswordCredentialIdentity *> *credentials =
                    [NSArray array];
                NSArray<KdbEntry *> *arr = self->_group.allEntries;
                for (KdbEntry *entry in arr) {
                  if (entry.url.length > 0) {
                    ASCredentialServiceIdentifier *identifier =
                        [[ASCredentialServiceIdentifier alloc]
                            initWithIdentifier:entry.url
                                          type:
                                              ASCredentialServiceIdentifierTypeURL];
                    ASPasswordCredentialIdentity *identity =
                        [[ASPasswordCredentialIdentity alloc]
                            initWithServiceIdentifier:identifier
                                                 user:entry.username
                                     recordIdentifier:entry.recordIdentifier];
                    credentials = [credentials arrayByAddingObject:identity];
                  }
                }
                [store saveCredentialIdentities:credentials
                                     completion:^(BOOL success,
                                                  NSError *_Nullable error) {
                                       if (success) {
                                         DLog(@"saved credentials");
                                       }
                                     }];
              }
            }];
      }
    }];
  }
}

@end
