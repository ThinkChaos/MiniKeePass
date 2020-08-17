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

// Controller
#import "KPViewController.h"
#import "PinViewController.h"
#import "SelectionListViewController.h"
#import "SettingsViewController.h"
// Cells
#import "ChoiceCell.h"
#import "SwitchCell.h"
// Other
#import "AppSettings.h"
#import "constants.h"
#import "KeePassTouchAppDelegate.h"
#import "KeychainUtils.h"
#import "KPBiometrics.h"
// Purchase
#import "RMStore.h"
#import <StoreKit/StoreKit.h>

#define kRemoveAdsProductIdentifier @"KeePassTouch.RemoveAds"

@interface SKProduct (priceAsString)
@property (nonatomic, readonly) NSString *priceAsString;
@end
@implementation SKProduct (priceAsString)

- (NSString *)priceAsString
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [formatter setLocale:[self priceLocale]];
    
    NSString *str = [formatter stringFromNumber:[self price]];
    
    return [NSString stringWithFormat:@" (%@)", str];
}

@end

enum {
    SECTION_TOUCHID,
    SECTION_PIN,
    SECTION_DELETE_ON_FAILURE,
    SECTION_CLOSE,
    SECTION_REMEMBER_PASSWORDS,
    SECTION_HIDE_PASSWORDS,
    SECTION_SORTING,
    SECTION_PASSWORD_ENCODING,
    SECTION_CLEAR_CLIPBOARD,
    SECTION_WEB_BROWSER,
    SECTION_FTP,
    SECTION_PURCHASE,
    SECTION_NUMBER
};

enum {
    ROW_PIN_ENABLED,
    ROW_PIN_LOCK_TIMEOUT,
    ROW_PIN_NUMBER
};

enum {
    ROW_DELETE_ON_FAILURE_ENABLED,
    ROW_DELETE_ON_FAILURE_ATTEMPTS,
    ROW_DELETE_ON_FAILURE_NUMBER
};

enum {
    ROW_CLOSE_ENABLED,
    ROW_CLOSE_TIMEOUT,
    ROW_CLOSE_NUMBER
};

enum {
    ROW_CLEAR_CLIPBOARD_ENABLED,
    ROW_CLEAR_CLIPBOARD_TIMEOUT,
    ROW_CLEAR_CLIPBOARD_NUMBER
};

enum {
    ROW_FTP_RESET,
    ROW_FTP_DROPBOX,
    ROW_FTP_DROPBOX_AUTO_SYNC,
    ROW_FTP_COUNT
};

enum {
    ROW_PURCHASE_BUY,
    ROW_PURCHASE_RESTORE,
    ROW_PURCHASE_COUNT
};
enum {
    ROW_TOUCHID_DEFAULT,
    ROW_TOUCHID_TOUCHID,
    ROW_TOUCHID_COUNT
};

@interface SettingsViewController ()  <PinViewControllerDelegate, SelectionListViewControllerDelegate> {
    AppSettings *appSettings;
    SKProduct *_product;
    
    SwitchCell *pinEnabledCell;
    SwitchCell *biometryEnabledCell;
    SwitchCell *defaultDatabaseEnabledCell;
    ChoiceCell *defaultDatabaseCell;
    ChoiceCell *pinLockTimeoutCell;
    SwitchCell *deleteOnFailureEnabledCell;
    ChoiceCell *deleteOnFailureAttemptsCell;
    SwitchCell *closeEnabledCell;
    ChoiceCell *closeTimeoutCell;
    SwitchCell *rememberPasswordsEnabledCell;
    SwitchCell *hidePasswordsCell;
    SwitchCell *sortingEnabledCell;
    ChoiceCell *passwordEncodingCell;
    SwitchCell *clearClipboardEnabledCell;
    ChoiceCell *clearClipboardTimeoutCell;
    SwitchCell *webBrowserIntegratedCell;
    SwitchCell *dbAutoSyncSwitchCell;
    NSString *tempPin;
}
@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    appSettings = [AppSettings sharedInstance];

    self.title = NSLocalizedString(@"Settings", nil);
    
    if([SKPaymentQueue canMakePayments]){
        [[RMStore defaultStore] requestProducts:[NSSet setWithObject:kRemoveAdsProductIdentifier] success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
            _product = products.firstObject;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:SECTION_PURCHASE] withRowAnimation:UITableViewRowAnimationNone];
            });
            
        } failure:^(NSError *error) {
            [self showAlertFromError:error];
        }];
    }
    
    
    pinEnabledCell = [[SwitchCell alloc] initWithLabel:NSLocalizedString(@"PIN Enabled", nil)];
    [pinEnabledCell.switchControl addTarget:self
                                     action:@selector(didToggleSwitch:)
                           forControlEvents:UIControlEventValueChanged];
    
    biometryEnabledCell = nil;
    if ([KPBiometrics hasBiometrics])
    {
        NSString *biometryTitle = NSLocalizedString(@"TouchID Enabled", nil);
        biometryTitle = [KPBiometrics supportFaceID] ? [biometryTitle stringByReplacingOccurrencesOfString:@"TouchID" withString:@"FaceID"] : biometryTitle;
        biometryEnabledCell = [[SwitchCell alloc] initWithLabel:biometryTitle];
        [biometryEnabledCell.switchControl addTarget:self
                                              action:@selector(didToggleSwitch:)
                                    forControlEvents:UIControlEventValueChanged];
    }

    
    KeePassTouchAppDelegate *appDelegate = [KeePassTouchAppDelegate appDelegate];
    NSArray *databaseEntryList = [NSArray arrayWithObject:@"None"];
    databaseEntryList = [databaseEntryList arrayByAddingObjectsFromArray:appDelegate.filesViewController.databaseFiles];
    defaultDatabaseCell = [[ChoiceCell alloc] initWithLabel:NSLocalizedString(@"Default Database", nil)
                                                    choices:databaseEntryList
                                              selectedIndex:[appSettings defaultDatabase]];
    
    pinLockTimeoutCell = [[ChoiceCell alloc] initWithLabel:NSLocalizedString(@"Lock Timeout", nil)
                                                   choices:@[NSLocalizedString(@"Immediately", nil),
                                                             NSLocalizedString(@"30 Seconds", nil),
                                                             NSLocalizedString(@"1 Minute", nil),
                                                             NSLocalizedString(@"2 Minutes", nil),
                                                             NSLocalizedString(@"5 Minutes", nil)]
                                             selectedIndex:[appSettings pinLockTimeoutIndex]];
    
    dbAutoSyncSwitchCell = [[SwitchCell alloc] initWithLabel:NSLocalizedString(@"Auto Sync", nil)];
    dbAutoSyncSwitchCell.switchControl.on = appSettings.autoSyncEnabled;
    [dbAutoSyncSwitchCell.switchControl addTarget:self action:@selector(didToggleSwitch:) forControlEvents:UIControlEventValueChanged];
    
    deleteOnFailureEnabledCell = [[SwitchCell alloc] initWithLabel:NSLocalizedString(@"Enabled", nil)];
    [deleteOnFailureEnabledCell.switchControl addTarget:self
                                                 action:@selector(didToggleSwitch:)
                                       forControlEvents:UIControlEventValueChanged];
    
    deleteOnFailureAttemptsCell = [[ChoiceCell alloc] initWithLabel:NSLocalizedString(@"Attempts", nil)
                                                            choices:@[@"3",
                                                                      @"5",
                                                                      @"10",
                                                                      @"15"]
                                                      selectedIndex:[appSettings deleteOnFailureAttemptsIndex]];
    
    closeEnabledCell = [[SwitchCell alloc] initWithLabel:NSLocalizedString(@"Close Enabled", nil)];
    [closeEnabledCell.switchControl addTarget:self
                                       action:@selector(didToggleSwitch:)
                             forControlEvents:UIControlEventValueChanged];
    
    closeTimeoutCell = [[ChoiceCell alloc] initWithLabel:NSLocalizedString(@"Close Timeout", nil)
                                                 choices:@[NSLocalizedString(@"Immediately", nil),
                                                           NSLocalizedString(@"30 Seconds", nil),
                                                           NSLocalizedString(@"1 Minute", nil),
                                                           NSLocalizedString(@"2 Minutes", nil),
                                                           NSLocalizedString(@"5 Minutes", nil)]
                                           selectedIndex:[appSettings closeTimeoutIndex]];
    
    rememberPasswordsEnabledCell = [[SwitchCell alloc] initWithLabel:NSLocalizedString(@"Enabled", nil)];
    [rememberPasswordsEnabledCell.switchControl addTarget:self
                                                   action:@selector(didToggleSwitch:)
                                         forControlEvents:UIControlEventValueChanged];
    
    hidePasswordsCell = [[SwitchCell alloc] initWithLabel:NSLocalizedString(@"Hide Passwords", nil)];
    [hidePasswordsCell.switchControl addTarget:self
                                        action:@selector(didToggleSwitch:)
                              forControlEvents:UIControlEventValueChanged];
    
    sortingEnabledCell = [[SwitchCell alloc] initWithLabel:NSLocalizedString(@"Enabled", nil)];
    [sortingEnabledCell.switchControl addTarget:self
                                         action:@selector(didToggleSwitch:)
                               forControlEvents:UIControlEventValueChanged];

    passwordEncodingCell = [[ChoiceCell alloc] initWithLabel:NSLocalizedString(@"Encoding", nil)
                                                     choices:@[NSLocalizedString(@"UTF-8", nil),
                                                               NSLocalizedString(@"UTF-16 Big Endian", nil),
                                                               NSLocalizedString(@"UTF-16 Little Endian", nil),
                                                               NSLocalizedString(@"Latin 1 (ISO/IEC 8859-1)", nil),
                                                               NSLocalizedString(@"Latin 2 (ISO/IEC 8859-2)", nil),
                                                               NSLocalizedString(@"7-Bit ASCII", nil),
                                                               NSLocalizedString(@"Japanese EUC", nil),
                                                               NSLocalizedString(@"ISO-2022-JP", nil)]
                                               selectedIndex:0];

    clearClipboardEnabledCell = [[SwitchCell alloc] initWithLabel:NSLocalizedString(@"Enabled", nil)];
    [clearClipboardEnabledCell.switchControl addTarget:self
                                                action:@selector(didToggleSwitch:)
                                      forControlEvents:UIControlEventValueChanged];
    
    clearClipboardTimeoutCell = [[ChoiceCell alloc] initWithLabel:NSLocalizedString(@"Clear Timeout", nil)
                                                          choices:@[NSLocalizedString(@"30 Seconds", nil),
                                                                    NSLocalizedString(@"1 Minute", nil),
                                                                    NSLocalizedString(@"2 Minutes", nil),
                                                                    NSLocalizedString(@"3 Minutes", nil)]
                                                    selectedIndex:[appSettings clearClipboardTimeoutIndex]];

    webBrowserIntegratedCell = [[SwitchCell alloc] initWithLabel:NSLocalizedString(@"Integrated", nil)];
    [webBrowserIntegratedCell.switchControl addTarget:self
                                           action:@selector(didToggleSwitch:)
                                 forControlEvents:UIControlEventValueChanged];

    // Add version number to table view footer
    CGFloat viewWidth = CGRectGetWidth(self.tableView.frame);
    UIView *tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewWidth, 40)];
    
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"];
    
    UILabel *versionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, viewWidth, 30)];
    versionLabel.textAlignment = NSTextAlignmentCenter;
    versionLabel.backgroundColor = [UIColor clearColor];
    versionLabel.font = [UIFont boldSystemFontOfSize:17];
    versionLabel.textColor = [UIColor grayColor];
    versionLabel.text = [NSString stringWithFormat:NSLocalizedString(@"KeePass Touch version %@", nil), appVersion];
    versionLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if (@available(iOS 13.0, *)) {
        versionLabel.shadowColor = [UIColor systemBackgroundColor];
    } else {
        // Fallback on earlier versions
        versionLabel.shadowColor = [UIColor whiteColor];
    }
    versionLabel.shadowOffset = CGSizeMake(0.0, 1.0);

    [tableFooterView addSubview:versionLabel];
    
    self.tableView.tableFooterView = tableFooterView;
    self.tableView.cellLayoutMarginsFollowReadableWidth = NO;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Delete the temp pin
    tempPin = nil;
    
    // Initialize all the controls with their settings
    pinEnabledCell.switchControl.on = [appSettings pinEnabled];
    
    deleteOnFailureEnabledCell.switchControl.on = [appSettings deleteOnFailureEnabled];
    
    closeEnabledCell.switchControl.on = [appSettings closeEnabled];
    
    rememberPasswordsEnabledCell.switchControl.on = [appSettings rememberPasswordsEnabled];
    
    hidePasswordsCell.switchControl.on = [appSettings hidePasswords];
    
    sortingEnabledCell.switchControl.on = [appSettings sortAlphabetically];
    
    [passwordEncodingCell setSelectedIndex:[appSettings passwordEncodingIndex]];
    
    clearClipboardEnabledCell.switchControl.on = [appSettings clearClipboardEnabled];
    [clearClipboardTimeoutCell setSelectedIndex:[appSettings clearClipboardTimeoutIndex]];

    webBrowserIntegratedCell.switchControl.on = [appSettings webBrowserIntegrated];
    
    NSInteger toBeSelected = 0;
    NSInteger defaultdb = [appSettings defaultDatabase];
    KeePassTouchAppDelegate *appDelegate = [KeePassTouchAppDelegate appDelegate];
    if(defaultdb <= (appDelegate.filesViewController.databaseFiles.count))
    {
        toBeSelected = defaultdb;
    }
    else
    {
        toBeSelected = 0;
        [appSettings setDefaultDatabase:0];
    }
    [defaultDatabaseCell setSelectedIndex:toBeSelected];

    // Update which controls are enabled
    [self updateEnabledControls];
}

- (void)updateEnabledControls {
    BOOL pinEnabled = [appSettings pinEnabled];
    BOOL deleteOnFailureEnabled = [appSettings deleteOnFailureEnabled];
    BOOL closeEnabled = [appSettings closeEnabled];
    BOOL clearClipboardEnabled = [appSettings clearClipboardEnabled];
    BOOL touchIDEnabled = [appSettings isTouchIDEnabled];
    // Enable/disable the components dependant on settings
    [pinLockTimeoutCell setEnabled:pinEnabled];
    [biometryEnabledCell.switchControl setOn:touchIDEnabled];
    [deleteOnFailureEnabledCell setEnabled:pinEnabled];
    [deleteOnFailureAttemptsCell setEnabled:pinEnabled && deleteOnFailureEnabled];
    [closeTimeoutCell setEnabled:closeEnabled];
    [clearClipboardTimeoutCell setEnabled:clearClipboardEnabled];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SECTION_NUMBER;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SECTION_TOUCHID:
            if(biometryEnabledCell != nil)
                return ROW_TOUCHID_COUNT;
            return ROW_TOUCHID_COUNT - 1;
        case SECTION_PIN:
            return ROW_PIN_NUMBER;
            
        case SECTION_DELETE_ON_FAILURE:
            return ROW_DELETE_ON_FAILURE_NUMBER;
            
        case SECTION_CLOSE:
            return ROW_CLOSE_NUMBER;
            
        case SECTION_REMEMBER_PASSWORDS:
        case SECTION_HIDE_PASSWORDS:
        case SECTION_WEB_BROWSER:
        case SECTION_SORTING:
        case SECTION_PASSWORD_ENCODING:
            return 1;
            
        case SECTION_CLEAR_CLIPBOARD:
            return ROW_CLEAR_CLIPBOARD_NUMBER;
        case SECTION_FTP:
            return ROW_FTP_COUNT;
        case SECTION_PURCHASE:
            return _product ? ROW_PURCHASE_COUNT : 0;
    }
    return 0;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SECTION_PIN:
            return NSLocalizedString(@"PIN Protection", nil);
            
        case SECTION_DELETE_ON_FAILURE:
            return NSLocalizedString(@"Delete All Data on PIN Failure", nil);
            
        case SECTION_CLOSE:
            return NSLocalizedString(@"Close Database on Timeout", nil);
            
        case SECTION_REMEMBER_PASSWORDS:
            return NSLocalizedString(@"Remember Database Passwords", nil);
            
        case SECTION_HIDE_PASSWORDS:
            return NSLocalizedString(@"Hide Passwords", nil);
            
        case SECTION_SORTING:
            return NSLocalizedString(@"Sorting", nil);
            
        case SECTION_PASSWORD_ENCODING:
            return NSLocalizedString(@"Password Encoding", nil);

        case SECTION_CLEAR_CLIPBOARD:
            return NSLocalizedString(@"Clear Clipboard on Timeout", nil);

        case SECTION_WEB_BROWSER:
            return NSLocalizedString(@"Web Browser", nil);
        case SECTION_FTP:
            return @"FTP & Dropbox";
        case SECTION_TOUCHID:
            return biometryEnabledCell != nil ? [[KPBiometrics supportFaceID] ? @"Face ID & " : @"Touch ID & " stringByAppendingString:NSLocalizedString(@"Default Database", nil)] : NSLocalizedString(@"Default Database", nil);
        case SECTION_PURCHASE:
            return NSLocalizedString(@"In-App-Purchase", nil);
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case SECTION_PIN:
            return NSLocalizedString(@"Prevent unauthorized access to KeePass Touch with a PIN.", nil);
        case SECTION_TOUCHID:
        {
            NSString *fullDescription = [NSString string];
            if(biometryEnabledCell != nil)
                fullDescription = [NSString stringWithFormat:@"%@ & ",NSLocalizedString(@"Unlock your database quickly with TouchID", nil)];
            if([KPBiometrics supportFaceID])
                fullDescription = [fullDescription stringByReplacingOccurrencesOfString:@"TouchID" withString:@"Face ID"];
            fullDescription = [fullDescription stringByAppendingString:NSLocalizedString(@"Choose to open a default database on launch.", nil)];
            return fullDescription;
        }
        case SECTION_DELETE_ON_FAILURE:
            return NSLocalizedString(@"Delete all files and passwords after too many failed attempts.", nil);
            
        case SECTION_CLOSE:
            return NSLocalizedString(@"Automatically close an open database after the selected timeout.", nil);
            
        case SECTION_REMEMBER_PASSWORDS:
            return NSLocalizedString(@"Stores remembered database passwords in the devices's secure keychain.", nil);
            
        case SECTION_HIDE_PASSWORDS:
            return NSLocalizedString(@"Hides passwords when viewing a password entry.", nil);
            
        case SECTION_SORTING:
            return NSLocalizedString(@"Sort Groups and Entries Alphabetically", nil);
            
        case SECTION_PASSWORD_ENCODING:
            return NSLocalizedString(@"The string encoding used for passwords when converting them to database keys.", nil);
            
        case SECTION_CLEAR_CLIPBOARD:
            return NSLocalizedString(@"Clear the contents of the clipboard after a given timeout upon performing a copy.", nil);
            
        case SECTION_WEB_BROWSER:
            return NSLocalizedString(@"Switch between an integrated web browser and Safari.", nil);
            
        case SECTION_PURCHASE:
            return NSLocalizedString(@"Restore or buy AutoFill & the removal of ads. \nThat way you will support our cause to bring more features to KeePass Touch", nil);
        
    }
    return nil;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
//    NSLog(@"indexPath is %@", [indexPath description]);
    switch (indexPath.section) {
        case SECTION_PIN:
            switch (indexPath.row) {
                case ROW_PIN_ENABLED:
                    return pinEnabledCell;
                case ROW_PIN_LOCK_TIMEOUT:
                    return pinLockTimeoutCell;
            }
            break;
            
        case SECTION_DELETE_ON_FAILURE:
            switch (indexPath.row) {
                case ROW_DELETE_ON_FAILURE_ENABLED:
                    return deleteOnFailureEnabledCell;
                case ROW_DELETE_ON_FAILURE_ATTEMPTS:
                    return deleteOnFailureAttemptsCell;
            }
            break;
            
        case SECTION_CLOSE:
            switch (indexPath.row) {
                case ROW_CLOSE_ENABLED:
                    return closeEnabledCell;
                case ROW_CLOSE_TIMEOUT:
                    return closeTimeoutCell;
            }
            break;
            
        case SECTION_REMEMBER_PASSWORDS:
            return rememberPasswordsEnabledCell;
            break;
            
        case SECTION_HIDE_PASSWORDS:
            return hidePasswordsCell;
            break;
            
        case SECTION_SORTING:
            return sortingEnabledCell;
            break;
            
        case SECTION_PASSWORD_ENCODING:
            return passwordEncodingCell;
            break;
            
            
        case SECTION_CLEAR_CLIPBOARD:
            switch (indexPath.row) {
                case ROW_CLEAR_CLIPBOARD_ENABLED:
                    return clearClipboardEnabledCell;
                case ROW_CLEAR_CLIPBOARD_TIMEOUT:
                    return clearClipboardTimeoutCell;
            }
            break;
        case SECTION_WEB_BROWSER:
            return webBrowserIntegratedCell;
            break;
        case SECTION_FTP:
        {
            if(indexPath.row == ROW_FTP_DROPBOX)
            {
                UITableViewCell *dbCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                dbCell.textLabel.text = NSLocalizedString(@"Reset Dropbox Settings", nil);
                return dbCell;
            }
            else if(indexPath.row == ROW_FTP_DROPBOX_AUTO_SYNC) {
                return dbAutoSyncSwitchCell;
            }
            UITableViewCell *ftpCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            ftpCell.textLabel.text = NSLocalizedString(@"Reset FTP data", nil);
            return ftpCell;
        }
            break;
        case SECTION_TOUCHID:
        {
            switch (indexPath.row) {
                case ROW_TOUCHID_DEFAULT:
                    return defaultDatabaseCell;
                    break;
                case ROW_TOUCHID_TOUCHID:
                {
                    if(biometryEnabledCell != nil)
                        return biometryEnabledCell;
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case SECTION_PURCHASE:
        {
            UITableViewCellStyle rowStyle = indexPath.row == ROW_PURCHASE_BUY ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault;
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:rowStyle reuseIdentifier:nil];
            
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.text = indexPath.row == ROW_PURCHASE_BUY ? NSLocalizedString(@"Autofill & Remove Ads", nil) : NSLocalizedString(@"Restore Purchase", nil);
            if(appSettings.purchased) {
                cell.textLabel.textColor = cell.detailTextLabel.textColor = UIColor.lightGrayColor;
                cell.detailTextLabel.text = NSLocalizedString(@"(Purchased)", nil);
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            else {
                cell.detailTextLabel.textColor = UIColor.grayColor;
                cell.detailTextLabel.text = _product.priceAsString;
            }
            return cell;
        }
            break;
    }
    
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // BOOL for all Selection rows
    UITableViewCell *cell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:[ChoiceCell class]])
    {
        ChoiceCell *choiCell = (ChoiceCell *)cell;
        SelectionListViewController *selectionListViewController = [[SelectionListViewController alloc] initWithStyle:UITableViewStyleGrouped];
        selectionListViewController.title = cell.textLabel.text;
        selectionListViewController.items = choiCell.choices;
        selectionListViewController.selectedIndex = choiCell.selectedIndex;
        selectionListViewController.delegate = self;
        selectionListViewController.reference = indexPath;
        [self.navigationController pushViewController:selectionListViewController animated:YES];
    }
    else if(indexPath.section == SECTION_FTP) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        if(indexPath.row == ROW_FTP_DROPBOX) {
            [DBClientsManager unlinkAndResetClients];
            [defaults removeObjectForKey:@"DBAutoSync"];
            [defaults removeObjectForKey:@"DropboxPath"];
        }
        else if(indexPath.row == ROW_FTP_DROPBOX_AUTO_SYNC)
        {
            // nothing to do here, as the switch handles it
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            return;
        }
        else
        {
            [KeychainUtils deleteStringForKey:KPT_FTP_KEY_HOST andServiceName:KPT_FTP_SERVICE];
            [KeychainUtils deleteStringForKey:KPT_FTP_KEY_USER andServiceName:KPT_FTP_SERVICE];
            [KeychainUtils deleteStringForKey:KPT_FTP_KEY_PASSWD andServiceName:KPT_FTP_SERVICE];
        }
        
        
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated:YES];
        hud.mode = MBProgressHUDModeText;
        hud.detailsLabel.text = NSLocalizedString(@"Reset complete", nil);
        hud.detailsLabel.font = [UIFont fontWithName:@"Andale Mono" size:22];
        hud.margin = 10.f;
        hud.removeFromSuperViewOnHide = YES;
        [hud hideAnimated:YES afterDelay:1.5f];
        
        
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    else if(indexPath.section == SECTION_PURCHASE) {
        switch (indexPath.row) {
            case ROW_PURCHASE_BUY:
            {
                [[RMStore defaultStore] addPayment:kRemoveAdsProductIdentifier success:^(SKPaymentTransaction *transaction) {
                    if(transaction.transactionState == SKPaymentTransactionStateRestored ||
                       transaction.transactionState == SKPaymentTransactionStatePurchased)
                    {
                        [[KeePassTouchAppDelegate appDelegate] clearAds];
                    }
                } failure:^(SKPaymentTransaction *transaction, NSError *error) {
                    if(error != nil)
                        [self showAlertWithTitle:NSLocalizedString(@"Error", nil) message:error.localizedDescription];
                    else {
                        if(transaction.transactionState == SKPaymentTransactionStateRestored ||
                           transaction.transactionState == SKPaymentTransactionStatePurchased)
                        {
                            [[KeePassTouchAppDelegate appDelegate] clearAds];
                        }
                        else
                            [self showAlertWithTitle:NSLocalizedString(@"Error", nil) message:@"Purchase failed for unknown reason"];
                    }
                }];
            }
                break;
            case ROW_PURCHASE_RESTORE:
            {
                [[RMStore defaultStore] restoreTransactionsOnSuccess:^(NSArray *transactions){
                    if(transactions.count == 0) {
                        [self showAlertWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No restorable transactions found", nil)];
                    }
                    else {
                        for (SKPaymentTransaction *transaction in transactions) {
                            if(transaction.transactionState == SKPaymentTransactionStatePurchased ||
                               transaction.transactionState == SKPaymentTransactionStateRestored) {
                                [[KeePassTouchAppDelegate appDelegate] clearAds];
                            }
                        }
                    }
                } failure:^(NSError *error) {
                    [self showAlertWithTitle:NSLocalizedString(@"Error", nil) message:error.localizedDescription];
                }];
            }
                break;
            default:
                break;
        }
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)selectionListViewController:(SelectionListViewController *)controller selectedIndex:(NSInteger)selectedIndex withReference:(id<NSObject>)reference {
    NSIndexPath *indexPath = (NSIndexPath*)reference;
    if (indexPath.section == SECTION_TOUCHID && indexPath.row == ROW_TOUCHID_DEFAULT) {
        [appSettings setDefaultDatabase:selectedIndex];
    }
    else if (indexPath.section == SECTION_PIN && indexPath.row == ROW_PIN_LOCK_TIMEOUT) {
        [appSettings setPinLockTimeoutIndex:selectedIndex];
    } else if (indexPath.section == SECTION_DELETE_ON_FAILURE && indexPath.row == ROW_DELETE_ON_FAILURE_ATTEMPTS) {
        [appSettings setDeleteOnFailureAttemptsIndex:selectedIndex];
    } else if (indexPath.section == SECTION_CLOSE && indexPath.row == ROW_CLOSE_TIMEOUT) {
        [appSettings setCloseTimeoutIndex:selectedIndex];
    } else if (indexPath.section == SECTION_PASSWORD_ENCODING) {
        [appSettings setPasswordEncodingIndex:selectedIndex];
    } else if (indexPath.section == SECTION_CLEAR_CLIPBOARD && indexPath.row == ROW_CLEAR_CLIPBOARD_TIMEOUT) {
        [appSettings setClearClipboardTimeoutIndex:selectedIndex];
    }
    UITableViewCell *cell = [self tableView:self.tableView cellForRowAtIndexPath:indexPath];
    if([cell isKindOfClass:[ChoiceCell class]])
        [(ChoiceCell *)cell setSelectedIndex:selectedIndex];
}

#pragma mark - SwitchCell Handling

- (void)didToggleSwitch:(UISwitch *)sender {
    if([sender isEqual:pinEnabledCell.switchControl]) {
        if (pinEnabledCell.switchControl.on) {
            PinViewController *pinViewController = [[PinViewController alloc] init];
            pinViewController.modalPresentationStyle = UIModalPresentationOverCurrentContext;
            pinViewController.textLabel.text = NSLocalizedString(@"Set PIN", nil);
            pinViewController.delegate = self;
            [self presentViewController:pinViewController animated:YES completion:nil];
        } else {
            // Delete the PIN and disable the PIN enabled setting
            [KeychainUtils deleteStringForKey:KPT_PIN_KEY andServiceName:KPT_PIN_SERVICE];
            [appSettings setPinEnabled:NO];
        }
    }
    else if([sender isEqual:biometryEnabledCell.switchControl]) {
        if(!biometryEnabledCell.switchControl.on) {
            // Ask to deactivate
            NSString *localizedBiometryText = NSLocalizedString(@"Deactivating biometry requires you to remember your master password to your database. Please make sure you do before you continue.", nil);
            UIAlertController *alertCon = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warning", nil) message:localizedBiometryText preferredStyle:UIAlertControllerStyleAlert];
            [alertCon addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Deactivate", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [appSettings setTouchIDEnabled:biometryEnabledCell.switchControl.on];
                [self updateEnabledControls];
            }]];
            [alertCon addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [biometryEnabledCell.switchControl setOn:YES];
            }]];
            [self presentViewController:alertCon animated:YES completion:nil];
            return;
        }
        else {
            [appSettings setTouchIDEnabled:biometryEnabledCell.switchControl.on];
            // Delete without question, it is enabled now
            [KeychainUtils deleteAllForServiceName:KPT_PASSWORD_SERVICE];
            [KeychainUtils deleteAllForServiceName:KPT_KEYFILES_SERVICE];
        }
    }
    else if([sender isEqual:rememberPasswordsEnabledCell.switchControl]) {
        [appSettings setRememberPasswordsEnabled:sender.on];
        // Delete all database passwords from the keychain
        [KeychainUtils deleteAllForServiceName:KPT_PASSWORD_SERVICE];
        [KeychainUtils deleteAllForServiceName:KPT_KEYFILES_SERVICE];
    }
    else if([sender isEqual:hidePasswordsCell.switchControl])
        [appSettings setHidePasswords:sender.on];
    else if([sender isEqual:closeEnabledCell.switchControl])
        [appSettings setCloseEnabled:sender.on];
    else if([sender isEqual:deleteOnFailureEnabledCell.switchControl])
        [appSettings setDeleteOnFailureEnabled:sender.on];
    else if([sender isEqual:dbAutoSyncSwitchCell.switchControl])
        appSettings.autoSyncEnabled = sender.on;
    else if([sender isEqual:sortingEnabledCell.switchControl])
        [appSettings setSortAlphabetically:sender.on];
    else if([sender isEqual:clearClipboardEnabledCell.switchControl])
        [appSettings setClearClipboardEnabled:sender.on];
    else if([sender isEqual:webBrowserIntegratedCell.switchControl])
        [appSettings setWebBrowserIntegrated:sender.on];
    // Update which controls are enabled
    [self updateEnabledControls];
}

- (void)pinViewController:(PinViewController *)controller pinEntered:(NSString *)pin {        
    if (tempPin == nil) {
        tempPin = [pin copy];
        
        controller.textLabel.text = NSLocalizedString(@"Confirm PIN", nil);
        
        // Clear the PIN entry for confirmation
        [controller clearEntry];
    } else if ([tempPin isEqualToString:pin]) {
        tempPin = nil;
        
        // Set the PIN and enable the PIN enabled setting
        [KeychainUtils setString:pin forKey:KPT_PIN_KEY andServiceName:KPT_PIN_SERVICE];
        [appSettings setPinEnabled:pinEnabledCell.switchControl.on];
        
        // Update which controls are enabled
        [self updateEnabledControls];
        
        // Remove the PIN view
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        tempPin = nil;
        
        // Notify the user the PINs they entered did not match
        controller.textLabel.text = NSLocalizedString(@"PINs did not match. Try again", nil);
        
        // Clear the PIN entry to let them try again
        [controller clearEntry];
    }
}

@end
