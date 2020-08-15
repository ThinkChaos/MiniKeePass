//
//  KDB.h
//  KeePass2
//
//  Created by Qiang Yu on 1/1/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DEFAULT_TRANSFORMATION_ROUNDS 6000

@class KdbEntry;

#pragma mark - KDBGroup

@interface KdbGroup : NSObject {
  KdbGroup *__unsafe_unretained parent;

  NSInteger image;
  NSString *name;
  NSMutableArray *groups;
  NSMutableArray *entries;

  NSDate *creationTime;
  NSDate *lastModificationTime;
  NSDate *lastAccessTime;
  NSDate *expiryTime;

  BOOL canAddEntries;
}

@property(nonatomic, unsafe_unretained) KdbGroup *parent;

@property(nonatomic, assign) NSInteger image;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, readonly) NSArray *groups;
@property(nonatomic, readonly) NSArray *entries;

/** Delivers all entries including subgroups entries recursively
 @note (KDB4) delivers stringfields as well
 */
@property(nonatomic, readonly) NSArray *allEntries;

@property(nonatomic, strong) NSDate *creationTime;
@property(nonatomic, strong) NSDate *lastModificationTime;
@property(nonatomic, strong) NSDate *lastAccessTime;
@property(nonatomic, strong) NSDate *expiryTime;

@property(nonatomic, assign) BOOL canAddEntries;

- (void)addGroup:(KdbGroup *)group;
- (void)removeGroup:(KdbGroup *)group;
- (void)moveGroup:(KdbGroup *)group toGroup:(KdbGroup *)toGroup;

- (void)addEntry:(KdbEntry *)entry;
- (void)removeEntry:(KdbEntry *)entry;
- (void)moveEntry:(KdbEntry *)entry toGroup:(KdbGroup *)toGroup;

- (BOOL)containsGroup:(KdbGroup *)group;

@end

#pragma mark - KDBEntry

@interface KdbEntry : NSObject {
  KdbGroup *__unsafe_unretained parent;
  NSInteger image;
  NSDate *creationTime;
  NSDate *lastModificationTime;
  NSDate *lastAccessTime;
  NSDate *expiryTime;
}

@property(nonatomic, unsafe_unretained) KdbGroup *parent;

@property(nonatomic, assign) NSInteger image;

@property(nonatomic, strong) NSDate *creationTime;
@property(nonatomic, strong) NSDate *lastModificationTime;
@property(nonatomic, strong) NSDate *lastAccessTime;
@property(nonatomic, strong) NSDate *expiryTime;

- (NSString *)title;
- (void)setTitle:(NSString *)title;

- (NSString *)username;
- (void)setUsername:(NSString *)username;

- (NSString *)password;
- (void)setPassword:(NSString *)password;

- (NSString *)url;
- (void)setUrl:(NSString *)url;

- (NSString *)notes;
- (void)setNotes:(NSString *)notes;

#pragma mark Auto Fill

- (NSInteger)rankForSearchString:(NSString *)searchString;

/// returns the recordIdentifier for Auto Fill
@property(nonatomic, readonly) NSString *recordIdentifier;

#pragma mark -

@end

#pragma mark KDBTree

@interface KdbTree : NSObject {
  KdbGroup *root;
}

@property(nonatomic, strong) KdbGroup *root;

- (KdbGroup *)createGroup:(KdbGroup *)parent;
- (KdbEntry *)createEntry:(KdbGroup *)parent;

@end
