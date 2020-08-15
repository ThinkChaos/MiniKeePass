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

#import "DatabaseManager.h"


#import "KeePassTouchAppDelegate.h"
#import "KeychainUtils.h"
#import "PasswordViewController.h"
#import "AppSettings.h"
#import "ImageFactory.h"
// Biometrics
#import "KPBiometrics.h"
#import <LocalAuthentication/LocalAuthentication.h>

#import "constants.h"

@implementation DatabaseManager

static DatabaseManager *sharedInstance;

+ (void)initialize {
    static BOOL initialized = NO;
    if (!initialized)     {
        initialized = YES;
        sharedInstance = [[DatabaseManager alloc] init];
    }
}

+ (DatabaseManager*)sharedInstance {
    return sharedInstance;
}

- (void)openDatabaseDocument:(NSString *)filePath
                     success:(void (^)(DatabaseDocument *))successBlock
                     failure:(void (^)(NSError *))failure
{
    __block BOOL databaseLoaded = NO;
    [[ImageFactory sharedInstance] clear];
    self.selectedFilename = [filePath lastPathComponent];
    
    // Get the application delegate
    KeePassTouchAppDelegate *appDelegate = [KeePassTouchAppDelegate appDelegate];
    
    // Get the documents directory
    NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];
    
    // Load the password and keyfile from the keychain
    NSString *password = [KeychainUtils stringForKey:self.selectedFilename
                                      andServiceName:KPT_PASSWORD_SERVICE];
    __block NSString *keyFile = [KeychainUtils stringForKey:self.selectedFilename
                                     andServiceName:KPT_KEYFILES_SERVICE];
    // Try and load the database with the cached password from the keychain
    if (password != nil || keyFile != nil) {
        if ([[AppSettings sharedInstance] isTouchIDEnabled])
        {
            databaseLoaded = YES;
            // Authenticate User
            [KPBiometrics authenticateViaBiometricsWithSuccess:^{
                // Get the absolute path to the database
                NSString *path = [documentsDirectory stringByAppendingPathComponent:self.selectedFilename];
                
                // Get the absolute path to the keyfile
                NSString *keyFilePath = nil;
                if (keyFile != nil) {
                    keyFilePath = [documentsDirectory stringByAppendingPathComponent:keyFile];
                }
                
                @try {
                    DatabaseDocument *dd = [[DatabaseDocument alloc] initWithFilename:path password:password keyFile:keyFilePath];
                    if(successBlock)
                        successBlock(dd);
                } @catch (NSException *exception) {
                    // Ignore
                    NSLog(@"Exception Database Manager");
                }
            } failure:^(NSError *error) {
                if(error.code == LAErrorUserFallback)
                {
                    // Fallback
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showDatabasePasswordViewController:self.selectedFilename success:successBlock];
                    });
                }
                else if(error.code == LAErrorTouchIDNotEnrolled) {
                    UIAlertController *alertCon = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"Biometry unlock is enabled, but no identities are enrolled. Should I disable biometry unlock?", nil) preferredStyle:UIAlertControllerStyleAlert];
                    
                    [alertCon addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                    
                    UIAlertAction *deactivateAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Deactivate", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        
                        // DEACTIVATE PRESSED
                        NSString *localizedBiometryText = NSLocalizedString(@"Deactivating biometry requires you to remember your master password to your database. Please make sure you do before you continue.", nil);
                        UIAlertController *alertCon = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warning", nil) message:localizedBiometryText preferredStyle:UIAlertControllerStyleAlert];
                        [alertCon addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Deactivate", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                            [[AppSettings sharedInstance] setTouchIDEnabled:NO];
                        }]];
                        [alertCon addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                        [appDelegate.navigationController presentViewController:alertCon animated:YES completion:nil];
                        
                    }];
                    [alertCon addAction:deactivateAction];
                    [appDelegate.navigationController presentViewController:alertCon animated:YES completion:nil];
                    return;
                }
                else if(error.code != LAErrorUserCancel) {
                    if(failure)
                        failure(error);
                    return;
                }
                else {
                    // no error, user cancelled
                    if(failure)
                        failure(nil);
                    return;
                }
            }];
        }
        else {
            // Get the absolute path to the database
            NSString *path = [documentsDirectory stringByAppendingPathComponent:self.selectedFilename];
            
            // Get the absolute path to the keyfile
            NSString *keyFilePath = nil;
            if (keyFile != nil) {
                keyFilePath = [documentsDirectory stringByAppendingPathComponent:keyFile];
            }
            // Load the database
            @try {
                
                
                DatabaseDocument *dd = [[DatabaseDocument alloc] initWithFilename:path password:password keyFile:keyFilePath];
                
                databaseLoaded = YES;
                
                // Set the database document in the application delegate
                if(successBlock)
                    successBlock(dd);
            } @catch (NSException *exception) {
                // Ignore
                
            }
        }
    }
    
    // Prompt the user for the password if we haven't loaded the database yet
    if (!databaseLoaded) {
        // Prompt the user for a password
        [self showDatabasePasswordViewController:self.selectedFilename success:successBlock];
    }
}

-(void)showDatabasePasswordViewController:(NSString *)filename
                                  success:(void (^)(DatabaseDocument *))successBlock {
    PasswordViewController *passwordViewController = [[PasswordViewController alloc] initWithFilename:filename];
    passwordViewController.donePressed = ^(FormViewController *formViewController) {
        [self openDatabaseWithPasswordViewController:(PasswordViewController *)formViewController success:successBlock];
    };
    
    // Create a default keyfile name from the database name
    NSString *keyFile = [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"key"];
    
    // Select the keyfile if it's in the list
    NSInteger index = [passwordViewController.keyFileCell.choices indexOfObject:keyFile];
    if (index != NSNotFound) {
        passwordViewController.keyFileCell.selectedIndex = index;
    } else {
        passwordViewController.keyFileCell.selectedIndex = 0;
    }
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:passwordViewController];
    
    KeePassTouchAppDelegate *appDelegate = [KeePassTouchAppDelegate appDelegate];
    
    [appDelegate.window.rootViewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)openDatabaseWithPasswordViewController:(PasswordViewController *)passwordViewController
                                       success:(void (^)(DatabaseDocument *))successBlock {
    NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:self.selectedFilename];

    // Get the password
    NSString *password = passwordViewController.masterPasswordFieldCell.textField.text;
    if ([password isEqualToString:@""]) {
        password = nil;
    }

    // Get the keyfile
    NSString *keyFile = [passwordViewController.keyFileCell getSelectedItem];
    if ([keyFile isEqualToString:NSLocalizedString(@"None", nil)]) {
        keyFile = nil;
    }

    // Get the absolute path to the keyfile
    NSString *keyFilePath = nil;
    if (keyFile != nil) {
        NSString *documentsDirectory = [KeePassTouchAppDelegate documentsDirectory];
        keyFilePath = [documentsDirectory stringByAppendingPathComponent:keyFile];
    }
    
    // Load the database
    @try {
        // Open the database
        DatabaseDocument *dd = [[DatabaseDocument alloc] initWithFilename:path password:password keyFile:keyFilePath];
        
        // Store the password in the keychain
        if ([[AppSettings sharedInstance] rememberPasswordsEnabled] || [[AppSettings sharedInstance] isTouchIDEnabled]) {
            [KeychainUtils setString:password forKey:self.selectedFilename
                      andServiceName:KPT_PASSWORD_SERVICE];
            [KeychainUtils setString:keyFile forKey:self.selectedFilename
                      andServiceName:KPT_KEYFILES_SERVICE];
        }
        

        // Dismiss the view controller, and after animation set the database document
        [passwordViewController dismissViewControllerAnimated:YES completion:^{
            // Set the database document in the application delegate
            if(successBlock)
                successBlock(dd);
        }];
    } @catch (NSException *exception) {
        NSLog(@"%@", exception);
        [passwordViewController showErrorMessage:exception.reason];
        
    }
}

@end
