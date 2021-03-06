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

#import "KdbLib.h"
#import "SelectGroupViewController.h"
#import <UIKit/UIKit.h>

@interface GroupViewController : UITableViewController <SelectGroupDelegate>

@property(nonatomic, weak, readonly) KdbGroup *group;

- (id)initWithGroup:(KdbGroup *)group;

- (void)pushViewControllerForGroup:(KdbGroup *)group;
- (void)pushViewControllerForEntry:(KdbEntry *)entry;

- (UITableViewCell *)tableView:(UITableView *)tableView
                  cellForGroup:(KdbGroup *)g;
- (UITableViewCell *)tableView:(UITableView *)tableView
                  cellForEntry:(KdbEntry *)e;

@end
