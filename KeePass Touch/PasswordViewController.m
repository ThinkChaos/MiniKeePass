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

#import "PasswordViewController.h"

#define ROW_KEY_FILE 1

@interface PasswordViewController () {
  NSArray *_keyFiles;
}
@end

@implementation PasswordViewController

@synthesize masterPasswordFieldCell;
@synthesize keyFileCell;

- (id)initWithFilename:(NSString *)filename keyFiles:(NSArray *)keyfiles {
  self = [super init];
  if (self) {
    _keyFiles = keyfiles;
    [self initViews];
    self.footerTitle = [NSString
        stringWithFormat:NSLocalizedString(@"Enter the password and/or select "
                                           @"the keyfile for the %@ database.",
                                           nil),
                         filename];
  }
  return self;
}

- (id)initWithFilename:(NSString *)filename {
  self = [super init];
  if (self) {
    [self initViews];
    self.footerTitle = [NSString
        stringWithFormat:NSLocalizedString(@"Enter the password and/or select "
                                           @"the keyfile for the %@ database.",
                                           nil),
                         filename];
  }
  return self;
}

- (void)initViews {
  self.title = NSLocalizedString(@"Password", nil);
  self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
  [self initControls];
}

- (void)initControls {
  masterPasswordFieldCell =
      [[MasterPasswordFieldCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:nil];
  masterPasswordFieldCell.textField.delegate = self;

  // Create an array to hold the possible keyfile choices
  NSMutableArray *keyFileChoices =
      [NSMutableArray arrayWithObject:NSLocalizedString(@"None", nil)];
  [keyFileChoices addObjectsFromArray:[self keyFiles]];

  keyFileCell =
      [[ChoiceCell alloc] initWithLabel:NSLocalizedString(@"Key File", nil)
                                choices:keyFileChoices
                          selectedIndex:0];

  self.controls =
      [NSArray arrayWithObjects:masterPasswordFieldCell, keyFileCell, nil];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [self.tableView
      deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow]
                    animated:YES];

  [self.masterPasswordFieldCell.textField becomeFirstResponder];
}

- (NSArray *)keyFiles {
  if (_keyFiles)
    return _keyFiles;
  // Get the documents directory
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                       NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];

  // Get the list of key files in the documents directory
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *dirContents = [[NSFileManager defaultManager]
      contentsOfDirectoryAtPath:documentsDirectory
                          error:nil];

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

  return [files
      filteredArrayUsingPredicate:
          [NSPredicate
              predicateWithFormat:@"!(self ENDSWITH '.kdb') && !(self ENDSWITH "
                                  @"'.kdbx') && !(self BEGINSWITH '.')"]];
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row == ROW_KEY_FILE) {
    SelectionListViewController *selectionListViewController =
        [[SelectionListViewController alloc]
            initWithStyle:UITableViewStyleGrouped];
    selectionListViewController.title = NSLocalizedString(@"Key File", nil);
    selectionListViewController.items = keyFileCell.choices;
    selectionListViewController.selectedIndex = keyFileCell.selectedIndex;
    selectionListViewController.delegate = self;
    [self.navigationController pushViewController:selectionListViewController
                                         animated:YES];
  }
}

- (void)selectionListViewController:(SelectionListViewController *)controller
                      selectedIndex:(NSInteger)selectedIndex
                      withReference:(id<NSObject>)reference {
  // Update the cell text
  [keyFileCell setSelectedIndex:selectedIndex];
}

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
  // This makes it so the password text field doesn't clear the field when you
  // toggle the password visible
  textField.text = [textField.text stringByReplacingCharactersInRange:range
                                                           withString:string];
  return NO;
}

@end
