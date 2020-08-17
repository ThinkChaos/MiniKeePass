//
//  CredentialProviderViewController.m
//  KeePass Touch Autofill
//
//  Created by Aljoscha Lüers on 20.02.19.
//  Copyright © 2019 Self. All rights reserved.
//

#import "CredentialProviderViewController.h"

#import "KPViewController.h"
#import "PasswordViewController.h"

#import "Constants.h"
#import "KPBiometrics.h"
#import "KPError.h"
#import "KeychainUtils.h"

#import "CredentialDataSource.h"

// KDB file and kdblib handling
#import "DatabaseDocument.h"
#import "DatabaseManager.h"
#import "ImageFactory.h"
#import "Kdb4Node.h"
#import "KdbLib.h"

@import Firebase;

#define LENGTH_PREDICATE                                                       \
  [NSPredicate predicateWithFormat:@"length > 2 && !(self == 'net' || \
self "        \
                                   @"== 'com') || self == 'org'"]

@interface CredentialProviderViewController () <
    UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate> {
  CredentialDataSource *_source;
}
@end

@implementation CredentialProviderViewController

- (void)viewDidLoad {
  NSUInteger appCount = FIRApp.allApps.count;
  if (appCount == 0)
    [FIRApp configureWithName:@"KeePassTouch_AutoFill"
                      options:[FIROptions defaultOptions]];
}

#pragma mark - Data Source

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [UITableViewCell new];
  cell.textLabel.text = @"missing info";

  NSObject *obj;
  if (tableView.numberOfSections > 1 && indexPath.section == 0) {
    obj = _source.likelyEntries[indexPath.row];
  } else
    obj = _source.otherEntries[indexPath.row];
  // Create either a group or entry cell
  if ([obj isKindOfClass:[StringField class]]) {
    StringField *sf = (StringField *)obj;
    cell = [self tableView:tableView
        cellForCustomField:sf
                   inEntry:sf.containedIn];
  } else if ([obj isKindOfClass:[KdbEntry class]]) {
    KdbEntry *e = (KdbEntry *)obj;
    cell = [self tableView:tableView cellForEntry:e];
  }

  return cell;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
  if (tableView.numberOfSections > 1 && section == 0)
    return NSLocalizedString(@"Likely Entries", nil);
  return NSLocalizedString(@"All Entries", nil);
}

- (UITableViewCell *)tableView:(UITableView *)tableView
                  cellForEntry:(KdbEntry *)e {
  static NSString *CellIdentifier = @"CellEntry";

  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                  reuseIdentifier:CellIdentifier];
    cell.accessoryType = UITableViewCellAccessoryNone;
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

- (UITableViewCell *)tableView:(UITableView *)tableView
            cellForCustomField:(StringField *)sf
                       inEntry:(KdbEntry *)e {
  static NSString *CellIdentifier = @"CellEntry";

  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                  reuseIdentifier:CellIdentifier];
    cell.accessoryType = UITableViewCellAccessoryNone;
  }

  // Configure the cell
  cell.textLabel.text = e.title;
  cell.imageView.image = [[ImageFactory sharedInstance] imageForEntry:e];

  NSString *detailText = @"";
  if (sf.key.length > 0) {
    detailText = sf.key;
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return _source.likelyEntries.count > 0
             ? (_source.otherEntries.count > 0 ? 2 : 1)
             : 1;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  if (section == 0 && tableView.numberOfSections > 1)
    return _source.likelyEntries.count;
  return _source.otherEntries.count;
}

#pragma mark - Selection

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  NSObject *selectedObj;
  if (indexPath.section == 0 && tableView.numberOfSections > 1) {
    selectedObj = _source.likelyEntries[indexPath.row];
  } else {
    selectedObj = _source.otherEntries[indexPath.row];
  }
  ASPasswordCredential *pwCred;
  // Create either a group or entry cell
  if ([selectedObj isKindOfClass:[StringField class]]) {
    StringField *selectedField = (StringField *)selectedObj;
    pwCred = [ASPasswordCredential credentialWithUser:selectedField.key
                                             password:selectedField.value];
  } else if ([selectedObj isKindOfClass:[KdbEntry class]]) {
    KdbEntry *selectedEntry = (KdbEntry *)selectedObj;
    pwCred = [ASPasswordCredential credentialWithUser:selectedEntry.username
                                             password:selectedEntry.password];
  }
  [self.extensionContext completeRequestWithSelectedCredential:pwCred
                                             completionHandler:nil];
}

#pragma mark - Credential Providing Stuff

/*
 Prepare your UI to list available credentials for the user to choose from. The
 items in 'serviceIdentifiers' describe the service the user is logging in to,
 so your extension can prioritize the most relevant credentials in the list.
 */
- (void)prepareCredentialListForServiceIdentifiers:
    (NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {

  BOOL purchased = [[[NSUserDefaults standardUserDefaults]
      initWithSuiteName:@"group.keepass-touch"] boolForKey:@"adsRemoved"];
#ifdef DEBUG
  purchased = YES;
#endif
  if (!purchased) {
    [self showAlertFromError:
              [NSError
                  errorWithTitle:NSLocalizedString(@"Not purchased", nil)
                    errorMessage:
                        NSLocalizedString(
                            @"Please purchase the In-App-Purchase inside the "
                            @"main app, to unlock the Auto Fill Extension.",
                            nil)]
                  completion:^{
                    [self.extensionContext
                        cancelRequestWithError:
                            [NSError
                                errorWithDomain:ASExtensionErrorDomain
                                           code:ASExtensionErrorCodeUserCanceled
                                       userInfo:nil]];
                  }];
    return;
  }
  BOOL hasBiometrics = [KPBiometrics hasBiometrics];
  if (hasBiometrics) {
    [KPBiometrics
        authenticateViaBiometricsWithSuccess:^{
          [self.overlayView removeFromSuperview];
          [self showLoadingAnimation];
          NSArray<KdbEntry *> *allEntriesFromAllDatabases =
              [self entriesFromAllDatabases];
          // show error for no databases
          if (allEntriesFromAllDatabases.count == 0) {
            [self presentFallbackDatabasePicker:serviceIdentifiers];
          }

          NSArray<NSString *> *searchStrings =
              [self searchStringsFromServiceIdentifiers:serviceIdentifiers];

          self->_source = [[CredentialDataSource alloc]
               initWithEntries:allEntriesFromAllDatabases
              andSearchStrings:searchStrings];
          [self->_entriesTableView reloadData];
        }
        failure:^(NSError *error) {
          [self
              showAlertFromError:error
                      completion:^{
                        [self.extensionContext
                            cancelRequestWithError:
                                [NSError
                                    errorWithDomain:ASExtensionErrorDomain
                                               code:
                                                   ASExtensionErrorCodeUserCanceled
                                           userInfo:nil]];
                      }];
        }];
  } else {
    // fallback for no Touch ID / Face ID here
    [self presentFallbackDatabasePicker:serviceIdentifiers];
  }
}

/*
 Implement this method if your extension supports showing credentials in the
 QuickType bar. When the user selects a credential from your app, this method
 will be called with the ASPasswordCredentialIdentity your app has previously
 saved to the ASCredentialIdentityStore. Provide the password by completing the
 extension request with the associated ASPasswordCredential. If using the
 credential would require showing custom UI for authenticating the user, cancel
 the request with error code ASExtensionErrorCodeUserInteractionRequired.
 */
- (void)provideCredentialWithoutUserInteractionForIdentity:
    (ASPasswordCredentialIdentity *)credentialIdentity {
  self.navigationItem.leftBarButtonItem = nil;
  if (_source) {
    for (KdbEntry *entry in _source.otherEntries) {
      if ([entry isKindOfClass:[KdbEntry class]]) {
        if ([entry.recordIdentifier
                isEqualToString:credentialIdentity.recordIdentifier]) {
          ASPasswordCredential *credential =
              [[ASPasswordCredential alloc] initWithUser:entry.username
                                                password:entry.password];
          [self.extensionContext
              completeRequestWithSelectedCredential:credential
                                  completionHandler:nil];
          return;
        }
      }
    }
  }
  [self.extensionContext
      cancelRequestWithError:
          [NSError errorWithDomain:ASExtensionErrorDomain
                              code:ASExtensionErrorCodeUserInteractionRequired
                          userInfo:nil]];
}

/*
 Implement this method if -provideCredentialWithoutUserInteractionForIdentity:
 can fail with ASExtensionErrorCodeUserInteractionRequired. In this case, the
 system may present your extension's UI and call this method. Show appropriate
 UI for authenticating the user then provide the password by completing the
 extension request with the associated ASPasswordCredential.
 */
- (void)prepareInterfaceToProvideCredentialForIdentity:
    (ASPasswordCredentialIdentity *)credentialIdentity {
  [KPBiometrics
      authenticateViaBiometricsWithSuccess:^{
        [self showLoadingAnimation];
        NSArray<KdbEntry *> *allEntriesFromAllDatabases =
            [self entriesFromAllDatabases];
        // show error for no databases
        if (allEntriesFromAllDatabases.count == 0) {
          [self
              showAlertWithTitle:@"No entries found / databases opened"
                         message:@"No entries were found. There is probably no "
                                 @"Touch ID / Face ID database added to the "
                                 @"app. We only support those for now."
                      completion:^{
                        [self.extensionContext
                            cancelRequestWithError:
                                [NSError
                                    errorWithDomain:ASExtensionErrorDomain
                                               code:
                                                   ASExtensionErrorCodeUserCanceled
                                           userInfo:nil]];
                      }];
        }
        self->_source = [[CredentialDataSource alloc]
             initWithEntries:allEntriesFromAllDatabases
            andSearchStrings:nil];
        [self provideCredentialWithoutUserInteractionForIdentity:
                  credentialIdentity];
      }
      failure:^(NSError *error) {
        [self
            showAlertFromError:error
                    completion:^{
                      [self.extensionContext
                          cancelRequestWithError:
                              [NSError
                                  errorWithDomain:ASExtensionErrorDomain
                                             code:
                                                 ASExtensionErrorCodeUserCanceled
                                         userInfo:nil]];
                    }];
      }];
}

- (IBAction)cancel:(id)sender {
  [self.extensionContext
      cancelRequestWithError:
          [NSError errorWithDomain:ASExtensionErrorDomain
                              code:ASExtensionErrorCodeUserCanceled
                          userInfo:nil]];
}

#pragma mark - UISearchBar

- (void)searchBar:(UISearchBar *)searchBar
    textDidChange:(NSString *)searchText {
  [_source filter:searchText];
  [_entriesTableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
  [searchBar resignFirstResponder];
}

#pragma mark - Private Methods

- (void)presentFallbackDatabasePicker:
    (NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers {
  UIAlertController *databasePicker = [UIAlertController
      alertControllerWithTitle:NSLocalizedString(@"Databases", nil)
                       message:NSLocalizedString(@"Pick your database", nil)
                preferredStyle:IS_IPAD ? UIAlertControllerStyleAlert
                                       : UIAlertControllerStyleActionSheet];

  NSFileManager *fileManager = [NSFileManager defaultManager];

  NSURL *groupURL = [fileManager
      containerURLForSecurityApplicationGroupIdentifier:@"group.keepass-touch"];

  NSArray *files = [fileManager contentsOfDirectoryAtPath:groupURL.path
                                                    error:nil];

  NSArray *databases =
      [files filteredArrayUsingPredicate:
                 [NSPredicate predicateWithFormat:@"SELF contains 'kdb'"]];
  NSArray *keyFiles =
      [files filteredArrayUsingPredicate:
                 [NSPredicate predicateWithFormat:@"SELF contains '.key'"]];

  for (NSString *database in databases) {
    UIAlertAction *dbAction = [UIAlertAction
        actionWithTitle:database
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *_Nonnull action) {
                  NSString *dbPath =
                      [groupURL.path stringByAppendingPathComponent:database];
                  PasswordViewController *pwVC = [[PasswordViewController alloc]
                      initWithFilename:database
                              keyFiles:keyFiles];
                  pwVC.donePressed = ^(FormViewController *vc) {
                    PasswordViewController *passwordViewController =
                        (PasswordViewController *)vc;
                    // Get the password
                    NSString *password =
                        passwordViewController.masterPasswordFieldCell.textField
                            .text;
                    if (password.length == 0) {
                      password = nil;
                    }

                    // Get the keyfile
                    NSString *keyFile =
                        [passwordViewController.keyFileCell getSelectedItem];
                    if ([keyFile
                            isEqualToString:NSLocalizedString(@"None", nil)]) {
                      keyFile = nil;
                    } else {
                      keyFile = [groupURL.path
                          stringByAppendingPathComponent:keyFile];
                    }
                    @try {

                      DatabaseDocument *doc =
                          [[DatabaseDocument alloc] initWithFilename:dbPath
                                                            password:password
                                                             keyFile:keyFile];
                      NSArray<NSString *> *searchStrings =
                          [self searchStringsFromServiceIdentifiers:
                                    serviceIdentifiers];
                      // create source from allEntries of database and
                      // searchstrings
                      self->_source = [[CredentialDataSource alloc]
                           initWithEntries:doc.kdbTree.root.allEntries
                          andSearchStrings:searchStrings];
                      [self->_entriesTableView reloadData];
                      [self.overlayView removeFromSuperview];
                      [passwordViewController
                          dismissViewControllerAnimated:YES
                                             completion:nil];

                    } @catch (NSException *exception) {
                      [passwordViewController
                          showErrorMessage:exception.reason];
                    }
                  };
                  UINavigationController *navCon =
                      [[UINavigationController alloc]
                          initWithRootViewController:pwVC];
                  [self presentViewController:navCon
                                     animated:YES
                                   completion:nil];
                }];
    [databasePicker addAction:dbAction];
  }
  [databasePicker
      addAction:[UIAlertAction
                    actionWithTitle:NSLocalizedString(@"Cancel", nil)
                              style:UIAlertActionStyleCancel
                            handler:^(UIAlertAction *_Nonnull action) {
                              [self cancel:action];
                            }]];
  [self presentViewController:databasePicker animated:YES completion:nil];
}

#pragma mark Databases opening

- (NSArray<KdbEntry *> *)entriesFromAllDatabases {

  NSFileManager *fileManager = [NSFileManager defaultManager];

  NSURL *groupURL = [fileManager
      containerURLForSecurityApplicationGroupIdentifier:@"group.keepass-touch"];

  NSArray *files = [fileManager contentsOfDirectoryAtPath:groupURL.path
                                                    error:nil];

  // results for all files
  NSArray *multipleDatabaseEntries = [NSArray array];
  int opening = 1;
  files = [files filteredArrayUsingPredicate:
                     [NSPredicate predicateWithFormat:@"SELF contains 'kdb'"]];
  for (NSString *aPath in files) {
    [self
        showLoadingAnimation:[NSString stringWithFormat:@"Opening %d/%ld",
                                                        opening, files.count]];
    NSString *pw = [KeychainUtils stringForKey:aPath
                                andServiceName:KPT_PASSWORD_SERVICE];
    NSString *keyFile = [KeychainUtils stringForKey:aPath
                                     andServiceName:KPT_KEYFILES_SERVICE];
    if (pw.length > 0 || keyFile.length > 0) {
      NSString *fullPath = [groupURL.path stringByAppendingPathComponent:aPath];
      if (keyFile.length > 0) {
        keyFile = [groupURL.path stringByAppendingPathComponent:keyFile];
      }
      @try {
        DatabaseDocument *doc =
            [[DatabaseDocument alloc] initWithFilename:fullPath
                                              password:pw
                                               keyFile:keyFile];
        // add all entries to array
        multipleDatabaseEntries = [multipleDatabaseEntries
            arrayByAddingObjectsFromArray:doc.kdbTree.root.allEntries];
      } @catch (NSException *exception) {
        [self showAlertFromError:
                  [NSError errorWithTitle:[NSString stringWithFormat:@"Error"]
                             errorMessage:@"Saved password or keefile "
                                          @"incorrect, couldn't open database!"]
                      completion:^{

                      }];
      }
    }
    opening++;
  }
  [self removeLoadingAnimation];
  return multipleDatabaseEntries;
}

#pragma mark Searching

//"Title": "Commerzbank"
//"URL" : "https://www.commerzbank.de"

- (NSArray<NSString *> *)searchStringsFromServiceIdentifiers:
    (NSArray<ASCredentialServiceIdentifier *> *)identifiers {
  NSArray<NSString *> *searchStrings = [NSArray array];
  for (ASCredentialServiceIdentifier *servIdent in identifiers) {
    NSString *fullIdentifier = servIdent.identifier;
    searchStrings = [searchStrings arrayByAddingObject:fullIdentifier];
    if (servIdent.type == ASCredentialServiceIdentifierTypeURL) {
      // remove http:// https:// and www
      fullIdentifier =
          [fullIdentifier stringByReplacingOccurrencesOfString:@"http://"
                                                    withString:@""];
      fullIdentifier =
          [fullIdentifier stringByReplacingOccurrencesOfString:@"https://"
                                                    withString:@""];
      fullIdentifier =
          [fullIdentifier stringByReplacingOccurrencesOfString:@"www."
                                                    withString:@""];
      // split by point and search single strings
      NSArray *domainStrings =
          [fullIdentifier componentsSeparatedByString:@"/"];
      searchStrings =
          [searchStrings arrayByAddingObject:domainStrings.firstObject];

      NSArray *chunks =
          [domainStrings.firstObject componentsSeparatedByString:@"."];
      if (chunks.count >= 2) {
        searchStrings =
            [searchStrings arrayByAddingObject:chunks[chunks.count - 2]];
      } else
        searchStrings = [searchStrings arrayByAddingObjectsFromArray:chunks];
    } else if (servIdent.type == ASCredentialServiceIdentifierTypeDomain) {
      // split by point and search single strings
      searchStrings = [searchStrings
          arrayByAddingObjectsFromArray:[fullIdentifier
                                            componentsSeparatedByString:@"."]];
    } else {
      // search whole string only
    }
    searchStrings =
        [searchStrings filteredArrayUsingPredicate:LENGTH_PREDICATE];
  }
  return searchStrings;
}

@end
