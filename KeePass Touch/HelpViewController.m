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

#import "HelpViewController.h"

@interface HelpTopic : NSObject
- (HelpTopic *)initWithTitle:(NSString *)title andResource:(NSString *)resource;
+ (HelpTopic *)helpTopicWithTitle:(NSString *)title
                      andResource:(NSString *)resource;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *resource;
@end

@implementation HelpTopic

- (HelpTopic *)initWithTitle:(NSString *)title
                 andResource:(NSString *)resource {
  self = [super init];
  if (self) {
    _title = [title copy];
    _resource = [resource copy];
  }
  return self;
}

+ (HelpTopic *)helpTopicWithTitle:(NSString *)title
                      andResource:(NSString *)resource {
  return [[HelpTopic alloc] initWithTitle:title andResource:resource];
}

@end

@interface HelpViewController ()
@property(nonatomic, strong) NSArray *helpTopics;
@end

@implementation HelpViewController

- (id)init {
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self) {
    self.title = NSLocalizedString(@"Help", nil);
    _helpTopics = @[
      [HelpTopic helpTopicWithTitle:@"iTunes Import/Export"
                        andResource:@"itunes"],
      [HelpTopic helpTopicWithTitle:@"Dropbox Import/Export"
                        andResource:@"dropbox"],
      [HelpTopic helpTopicWithTitle:@"Safari/Email Import"
                        andResource:@"safariemail"],
      [HelpTopic helpTopicWithTitle:@"Create New Database"
                        andResource:@"createdb"],
      [HelpTopic helpTopicWithTitle:@"Key Files" andResource:@"keyfiles"],
      [HelpTopic helpTopicWithTitle:@"Touch ID / Face ID"
                        andResource:@"touchid"],
      [HelpTopic helpTopicWithTitle:@"Autofill" andResource:@"autofill"],
      [HelpTopic helpTopicWithTitle:@"Request Feature / Bug Report"
                        andResource:@"request"],
      [HelpTopic helpTopicWithTitle:@"Source Code" andResource:@"source"],
      [HelpTopic helpTopicWithTitle:@"Imprint" andResource:@"imprint"],
      [HelpTopic helpTopicWithTitle:@"Privacy" andResource:@"privacy"]
    ];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                           target:self
                           action:@selector(closeHelp)];
  self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
}

- (void)closeHelp {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
  switch (section) {
  case 0:
    return NSLocalizedString(@"Help", nil);
    break;
  case 1:
    return NSLocalizedString(@"Technical help / Infos", nil);
    break;
  default:
    return nil;
    break;
  }
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  switch (section) {
  case 0:
    return self.helpTopics.count - 4;
    break;
  case 1:
    return 4;
    break;
  default:
    return 0;
    break;
  }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"Cell";

  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:CellIdentifier];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  }

  // Configure the cell
  if (indexPath.section == 0)
    cell.textLabel.text =
        NSLocalizedString(((HelpTopic *)_helpTopics[indexPath.row]).title, nil);
  else {
    cell.textLabel.text = NSLocalizedString(
        ((HelpTopic *)_helpTopics[_helpTopics.count - 4 + indexPath.row]).title,
        nil);
  }

  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

  if ([[tableView cellForRowAtIndexPath:indexPath].textLabel.text
          containsString:@"Request"]) {
    // MAIL VIEW
    if ([MFMailComposeViewController canSendMail]) {
      MFMailComposeViewController *mcvc =
          [[MFMailComposeViewController alloc] init];
      mcvc.mailComposeDelegate = self;
      [mcvc setToRecipients:[NSArray
                                arrayWithObjects:@"kptouch@innervate.de", nil]];
      [mcvc setSubject:@"Request Feature / Bug Report"];
      [self.navigationController presentViewController:mcvc
                                              animated:YES
                                            completion:nil];
    }

  } else {

    NSInteger index = indexPath.section == 0
                          ? indexPath.row
                          : [tableView numberOfRowsInSection:0] + indexPath.row;

    // Get the title and resource of the selected help page
    NSString *title = ((HelpTopic *)_helpTopics[index]).title;
    NSString *resource = ((HelpTopic *)_helpTopics[index]).resource;

    if (title.length == 0)
      title = @"Unknown";

    NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
    NSString *localizedResource = [NSString
        stringWithFormat:@"%@-%@",
                         [language substringWithRange:NSMakeRange(0, 2)],
                         resource];

    NSString *path = [[NSBundle mainBundle] pathForResource:localizedResource
                                                     ofType:@"html"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
      path = [[NSBundle mainBundle] pathForResource:resource ofType:@"html"];
    }

    // Get the URL of the respurce
    NSURL *url = [NSURL fileURLWithPath:path];

    // Create a web view to display the help page
    WKWebView *webView = [[WKWebView alloc] init];
    webView.backgroundColor = [UIColor whiteColor];
    webView.navigationDelegate = self;
    [webView loadRequest:[NSURLRequest requestWithURL:url]];

    UIViewController *viewController = [[UIViewController alloc] init];
    viewController.title = NSLocalizedString(title, nil);
    viewController.view = webView;

    [self.navigationController pushViewController:viewController animated:YES];
  }
}

#pragma mark - MFMailComposeViewControllerDelegate
- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error {
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:
                        (void (^)(WKNavigationActionPolicy))decisionHandler {
  WKNavigationActionPolicy decision = WKNavigationActionPolicyAllow;

  if ([[[[navigationAction request] URL] scheme] isEqual:@"mailto"]) {
    decision = WKNavigationActionPolicyCancel;

    if ([MFMailComposeViewController canSendMail]) {
      MFMailComposeViewController *mcvc =
          [[MFMailComposeViewController alloc] init];
      mcvc.mailComposeDelegate = self;
      [mcvc setSubject:@"Source Code"];
      [mcvc setToRecipients:[NSArray
                                arrayWithObjects:@"kptouch@innervate.de", nil]];
      [self.navigationController presentViewController:mcvc
                                              animated:YES
                                            completion:nil];
    }
  }

  decisionHandler(decision);
}

@end
