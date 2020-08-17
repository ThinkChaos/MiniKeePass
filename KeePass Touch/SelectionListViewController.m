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

#import "SelectionListViewController.h"

@implementation SelectionListViewController

@synthesize items;
@synthesize selectedIndex;
@synthesize delegate;
@synthesize reference;

- (void)viewDidLoad {
  [super viewDidLoad];
  self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return [items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"Cell";

  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:CellIdentifier];
  }

  // Configure the cell
  cell.textLabel.text = [items objectAtIndex:indexPath.row];

  if (indexPath.row == selectedIndex) {
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    if (@available(iOS 12.0, *)) {
      if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        cell.textLabel.textColor = [UIColor colorWithRed:0.186
                                                   green:0.712
                                                    blue:0.970
                                                   alpha:1];
      } else {
        cell.textLabel.textColor = [UIColor colorWithRed:0.243
                                                   green:0.306
                                                    blue:0.435
                                                   alpha:1];
      }
    } else {
      cell.textLabel.textColor = [UIColor colorWithRed:0.243
                                                 green:0.306
                                                  blue:0.435
                                                 alpha:1];
      // Fallback on earlier versions
    }

  } else {
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (@available(iOS 13.0, *)) {
      cell.textLabel.textColor = UIColor.labelColor;
    } else {
      // Fallback on earlier versions
      cell.textLabel.textColor = UIColor.blackColor;
    }
  }

  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

  if (indexPath.row != selectedIndex) {
    // Remove the checkmark from the current selection
    NSIndexPath *previousPath = [NSIndexPath indexPathForRow:selectedIndex
                                                   inSection:0];

    selectedIndex = indexPath.row;
    NSIndexPath *newSelectedPath = [NSIndexPath indexPathForRow:selectedIndex
                                                      inSection:0];

    [tableView reloadRowsAtIndexPaths:@[ previousPath, newSelectedPath ]
                     withRowAnimation:UITableViewRowAnimationAutomatic];

    // Notify the delegate
    if ([delegate respondsToSelector:@selector
                  (selectionListViewController:selectedIndex:withReference:)]) {
      [delegate selectionListViewController:self
                              selectedIndex:selectedIndex
                              withReference:reference];
    }
  }

  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
