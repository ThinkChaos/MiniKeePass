//
//  CredentialDataSource.h
//  KeePass Touch Autofill
//
//  Created by Aljoscha Lüers on 07.07.19.
//  Copyright © 2019 Self. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KdbEntry;

@interface CredentialDataSource : NSObject

/** initialize a data source with entries from all databases
 */
- (instancetype)initWithEntries:(NSArray <KdbEntry *> *)entries andSearchStrings:(NSArray <NSString *> *)searchStrings;

/// Filters the current data source
- (void)filter:(NSString *)searchString;

/// Contains entries (and with KDB 4 Stringfields), including the current filtering (searchbar e.g.)
@property (nonatomic, readonly) NSArray *likelyEntries;

/// Contains all not likely entries sorted after ABC, including the current filtering  (searchbar e.g.)
@property (nonatomic, readonly) NSArray *otherEntries;

/* - init with Entries -> alle Entries aus allen DBS
 filterWithSearchStrings : -> self.entries filteredEntries (mit Rank)
 auf die filtered entries, dann die passen -> rank += rankForSearchString
 
 für search darauf dann
 searchEntries -> passt intern die filtered und normal arrays an
 -> reloaddata lädt vom datamodel
 */
 
 
@end
