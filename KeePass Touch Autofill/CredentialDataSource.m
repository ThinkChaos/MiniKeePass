//
//  CredentialDataSource.m
//  KeePass Touch Autofill
//
//  Created by Aljoscha Lüers on 07.07.19.
//  Copyright © 2019 Self. All rights reserved.
//

#import "CredentialDataSource.h"
#import "DatabaseDocument.h"

#import "KDB.h"

@interface CredentialDataSource ()
{
    /// All likely entries sorted by rank
    NSMutableDictionary <NSNumber *, NSArray *> *_likelyRankedEntries;
    
    /// All non likely entries sorted by ABC
    NSMutableArray <KdbEntry *> *_entries;
    
    // All initial entries
    NSArray <KdbEntry *> *_initialEntries;
    
    /// all likely initial entries
    NSMutableDictionary <NSNumber *, NSArray *> *_likelyInitials;
    
    // search String for Search bar
    NSString *_currentSearchString;
    
}
@end

@implementation CredentialDataSource



- (instancetype)initWithEntries:(NSArray<KdbEntry *> *)entries andSearchStrings:(NSArray<NSString *> *)searchStrings {
    self = [super init];
    _initialEntries = entries;
    [self createLikelyInitials:searchStrings];
    
    // init the searchbar string
    _currentSearchString = @"";
    
    return self;
}

- (void)createLikelyInitials:(NSArray <NSString *> *)searchStrings {
    NSArray *likelyEntries = [NSArray array];
    for (NSString *searchParticle in searchStrings) {
        likelyEntries = [likelyEntries arrayByAddingObjectsFromArray:[DatabaseDocument filterEntries:_initialEntries searchText:searchParticle]];
    }
    NSSet *likelySet = [NSSet setWithArray:likelyEntries];
    likelyEntries = [likelySet allObjects];
    
    // create likelies
    NSMutableDictionary <NSNumber *, NSArray *> *createLikelies = [NSMutableDictionary new];
    
    for (KdbEntry *entry in likelyEntries) {
        NSInteger rank = 0;
        for (NSString *searchStr in searchStrings) {
            NSInteger checkedRank = [entry rankForSearchString:searchStr];
            if(checkedRank > rank)
                rank = checkedRank;
        }
        if(rank > 0) {
            NSArray *entryRankArray = [createLikelies objectForKey:@(rank)];
            if(!entryRankArray)
                [createLikelies setObject:@[entry] forKey:@(rank)];
            else {
                entryRankArray = [entryRankArray arrayByAddingObject:entry];
                [createLikelies setObject:entryRankArray forKey:@(rank)];
            }
        }
    }
    _likelyInitials = createLikelies;
}

- (void)filter:(NSString *)searchString {
    _currentSearchString = searchString;
    if(searchString.length == 0) {
        _likelyRankedEntries = [_likelyInitials mutableCopy];
        _entries = [_initialEntries mutableCopy];
    }
    else {
        _likelyRankedEntries = nil;
        _entries = nil;
    }
}

#pragma mark - Public getters

- (NSArray *)likelyEntries {
    if(_likelyRankedEntries.allValues.count == 0) {
        _likelyRankedEntries = [NSMutableDictionary new];
        // build dictionary
        for (NSNumber *rank in _likelyInitials.allKeys) {
            NSArray *rankEntries = [_likelyInitials objectForKey:rank];
            rankEntries = [DatabaseDocument filterEntries:rankEntries searchText:_currentSearchString];
            [_likelyRankedEntries setObject:rankEntries forKey:rank];
        }
        
    }
    NSArray *keys = [_likelyRankedEntries allKeys];
    keys = [keys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj2 compare:obj1];
    }];
    
    NSArray *sortedEntries = [NSArray array];
    for (int i = 0; i < keys.count; i++) {
        sortedEntries = [sortedEntries arrayByAddingObjectsFromArray:[_likelyRankedEntries objectForKey:keys[i]]];
    }
    return sortedEntries;
}

- (NSArray *)otherEntries {
    if(_entries.count == 0) {
        // build entries
        _entries = [DatabaseDocument filterEntries:_initialEntries searchText:_currentSearchString];
    }
    return _entries;
}

@end
