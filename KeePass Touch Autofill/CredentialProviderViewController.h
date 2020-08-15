//
//  CredentialProviderViewController.h
//  KeePass Touch Autofill
//
//  Created by Aljoscha Lüers on 20.02.19.
//  Copyright © 2019 Self. All rights reserved.
//

#import <AuthenticationServices/AuthenticationServices.h>

@interface CredentialProviderViewController : ASCredentialProviderViewController

@property(weak, nonatomic) IBOutlet UITableView *entriesTableView;
@property(weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property(weak, nonatomic) IBOutlet UIView *overlayView;

@end
