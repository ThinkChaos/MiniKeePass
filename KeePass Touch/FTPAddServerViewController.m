//
//  FTPAddServerViewController.m
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 20.12.17.
//  Copyright © 2017 Self. All rights reserved.
//

#import "FTPAddServerViewController.h"
#import "KPTextField.h"
#import "KeychainUtils.h"
#import <FTPKit/FTPKit.h>

#import "constants.h"

@interface FTPAddServerViewController () {
  UITextField *_host;
  UITextField *_port;
  UITextField *_username;
  UITextField *_password;
}
@end

@implementation FTPAddServerViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = NSLocalizedString(@"FTP Login Data", nil);

  _host = [KPTextField new];

  _host.placeholder = NSLocalizedString(@"Host", nil);
  [self.view addSubview:_host];

  _port = [KPTextField new];
  _port.keyboardType = UIKeyboardTypeNumberPad;
  _port.placeholder = NSLocalizedString(@"Port", nil);

  [self.view addSubview:_port];

  _username = [KPTextField new];
  _username.placeholder = NSLocalizedString(@"Username", nil);
  [self.view addSubview:_username];

  _password = [KPTextField new];
  _password.secureTextEntry = YES;
  _password.placeholder = NSLocalizedString(@"Password", nil);
  [self.view addSubview:_password];

  if (@available(iOS 13.0, *)) {
    self.view.backgroundColor = UIColor.secondarySystemBackgroundColor;
    _host.backgroundColor = UIColor.systemBackgroundColor;
    _port.backgroundColor = UIColor.systemBackgroundColor;
    _username.backgroundColor = UIColor.systemBackgroundColor;
    _password.backgroundColor = UIColor.systemBackgroundColor;
  } else {
    // Fallback on earlier versions
    self.view.backgroundColor = UIColor.lightGrayColor;
    _host.backgroundColor = _port.backgroundColor = _username.backgroundColor =
        _password.backgroundColor = UIColor.whiteColor;
  }

  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                           target:self
                           action:@selector(donePressed)];
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                           target:self
                           action:@selector(cancelPressed)];

  [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                      initWithTarget:self
                                              action:@selector
                                              (dismissFirstResponder)]];

  // Do any additional setup after loading the view.
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];

  CGFloat edgeSpace = [SizeDesign getEdgeSpace];

  CGFloat height = [SizeDesign getTopSpace] + NAV_BAR_HEIGHT;

  _host.frame = CGRectMake(edgeSpace, height, self.view.width * 2 / 3, 50);

  _port.frame =
      CGRectMake(_host.xMax + 5, height,
                 self.view.width - _host.width - 5 - edgeSpace * 2, 50);
  height += _host.height + 5;

  _username.frame =
      CGRectMake(edgeSpace, height, self.view.width - edgeSpace * 2, 50);
  height += _username.height + 5;

  _password.frame =
      CGRectMake(edgeSpace, height, self.view.width - edgeSpace * 2, 50);
}

- (void)donePressed {
  // Connect and list contents.

  NSString *host = _host.text;
  NSString *port = _port.text;

  // intercept illegal values
  if (port.length > 5 || port.intValue == 0 || port.intValue > 65535) {
    [self showErrorMessage:NSLocalizedString(@"Error", nil)
               description:NSLocalizedString(@"Illegal Port", nil)];
    return;
  }

  if (host.length == 0)
    return;
  [self showLoadingAnimation];

  NSString *user = _username.text;
  NSString *password = _password.text;
  NSString *fullHost =
      [host stringByAppendingString:[NSString stringWithFormat:@":%@", port]];
  FTPClient *client = [FTPClient clientWithHost:fullHost
                                           port:21
                                       username:user
                                       password:password];

  [client listContentsAtPath:@"/"
      showHiddenFiles:NO
      success:^(NSArray *contents) {
        [KeychainUtils setString:fullHost
                          forKey:KPT_FTP_KEY_HOST
                  andServiceName:KPT_FTP_SERVICE];
        [KeychainUtils setString:self->_username.text
                          forKey:KPT_FTP_KEY_USER
                  andServiceName:KPT_FTP_SERVICE];
        [KeychainUtils setString:self->_password.text
                          forKey:KPT_FTP_KEY_PASSWD
                  andServiceName:KPT_FTP_SERVICE];
        dispatch_async(dispatch_get_main_queue(), ^{
          [self removeLoadingAnimation];

          [self dismissViewControllerAnimated:YES
                                   completion:^{
                                     if (self->_doneCompletion)
                                       self->_doneCompletion();
                                   }];
        });
      }
      failure:^(NSError *error) {
        [self removeLoadingAnimation];
        [self showErrorMessage:NSLocalizedString(@"Error", nil)
                   description:error.localizedDescription];
      }];
}

- (void)cancelPressed {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissFirstResponder {
  [self.view endEditing:YES];
}

@end
