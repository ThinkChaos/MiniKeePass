//
//  Kdb.m
//  KeePass2
//
//  Created by Qiang Yu on 2/13/10.
//  Copyright 2010 Qiang Yu. All rights reserved.
//

#import "Kdb.h"

@implementation KdbGroup

@synthesize parent;
@synthesize image;
@synthesize name;
@synthesize groups;
@synthesize entries;
@synthesize creationTime;
@synthesize lastModificationTime;
@synthesize lastAccessTime;
@synthesize expiryTime;
@synthesize canAddEntries;

- (id)init {
  self = [super init];
  if (self) {
    groups = [[NSMutableArray alloc] initWithCapacity:8];
    entries = [[NSMutableArray alloc] initWithCapacity:16];
    canAddEntries = YES;
  }
  return self;
}

- (void)addGroup:(KdbGroup *)group {
  group.parent = self;
  [groups addObject:group];
}

- (void)removeGroup:(KdbGroup *)group {
  group.parent = nil;
  [groups removeObject:group];
}

- (void)moveGroup:(KdbGroup *)group toGroup:(KdbGroup *)toGroup {
  [self removeGroup:group];
  [toGroup addGroup:group];
}

- (void)addEntry:(KdbEntry *)entry {
  entry.parent = self;
  [entries addObject:entry];
}

- (void)removeEntry:(KdbEntry *)entry {
  entry.parent = nil;
  [entries removeObject:entry];
}

- (void)moveEntry:(KdbEntry *)entry toGroup:(KdbGroup *)toGroup {
  [self removeEntry:entry];
  [toGroup addEntry:entry];
}

- (NSArray *)allEntries {
  if (self.groups.count == 0) {
    NSArray *allEntries = [NSArray array];
    for (KdbEntry *ent in self.entries) {
      allEntries = [allEntries arrayByAddingObject:ent];
    }
    return allEntries;
  } else {
    NSArray *allEntries = [NSArray array];
    for (KdbEntry *ent in self.entries) {
      allEntries = [allEntries arrayByAddingObject:ent];
    }
    for (KdbGroup *subGroup in self.groups) {
      allEntries =
          [allEntries arrayByAddingObjectsFromArray:[subGroup allEntries]];
    }
    return allEntries;
  }
}

- (BOOL)containsGroup:(KdbGroup *)group {
  // Check trivial case where group is passed to itself
  if (self == group) {
    return YES;
  } else {
    // Check subgroups
    for (KdbGroup *subGroup in groups) {
      if ([subGroup containsGroup:group]) {
        return YES;
      }
    }
    return NO;
  }
}

- (NSString *)description {
  return [NSString
      stringWithFormat:@"KdbGroup [image=%ld, name=%@, creationTime=%@, "
                       @"lastModificationTime=%@, lastAccessTime=%@, "
                       @"expiryTime=%@]\n ===============\nentries:\n{%@\n} "
                       @"\n==========================\n groups: \n{%@\n}",
                       (long)image, name, creationTime, lastModificationTime,
                       lastAccessTime, expiryTime, self.groups, self.entries];
}

@end

@implementation KdbEntry

@synthesize parent;
@synthesize image;
@synthesize creationTime;
@synthesize lastModificationTime;
@synthesize lastAccessTime;
@synthesize expiryTime;

- (NSString *)title {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)setTitle:(NSString *)title {
  [self doesNotRecognizeSelector:_cmd];
}

- (NSString *)username {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)setUsername:(NSString *)username {
  [self doesNotRecognizeSelector:_cmd];
}

- (NSString *)password {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)setPassword:(NSString *)password {
  [self doesNotRecognizeSelector:_cmd];
}

- (NSString *)url {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)setUrl:(NSString *)url {
  [self doesNotRecognizeSelector:_cmd];
}

- (NSString *)notes {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)setNotes:(NSString *)notes {
  [self doesNotRecognizeSelector:_cmd];
}

- (BOOL)isEqual:(id)object {

  if (![[object class] isEqual:[self class]])
    return NO;
  KdbEntry *other = object;
  return [self.creationTime isEqual:other.creationTime] &&
         [self.username isEqualToString:other.username] &&
         [self.password isEqualToString:other.password] &&
         [self.title isEqualToString:other.title];
}

- (NSString *)description {
  return [NSString
      stringWithFormat:
          @"KdbEntry [image=%ld, title=%@, username=%@, password=%@, url=%@, "
          @"notes=%@, creationTime=%@, lastModificationTime=%@, "
          @"lastAccessTime=%@, expiryTime=%@]",
          (long)image, self.title, self.username, self.password, self.url,
          self.notes, creationTime, lastModificationTime, lastAccessTime,
          expiryTime];
}

- (NSInteger)rankForSearchString:(NSString *)searchString {
  NSInteger rank = 0;
  if (searchString.length == 0)
    return -1;

  if ([self.title isEqualToString:searchString])
    rank += searchString.length * 2;
  else if ([self.title rangeOfString:searchString
                             options:NSCaseInsensitiveSearch]
               .length > 0)
    rank += searchString.length;

  if ([self.url isEqualToString:searchString])
    rank += searchString.length * 2;
  else if ([self.url rangeOfString:searchString options:NSCaseInsensitiveSearch]
               .length > 0)
    rank += searchString.length;

  if ([self.notes isEqualToString:searchString])
    rank += 2;
  else if ([self.notes rangeOfString:searchString
                             options:NSCaseInsensitiveSearch]
               .length > 0)
    rank++;

  return rank;
}

- (NSString *)recordIdentifier {
  return [NSString stringWithFormat:@"%@:%@:%@", self.parent.name, self.title,
                                    self.creationTime];
}

@end

@implementation KdbTree

@synthesize root;

- (KdbGroup *)createGroup:(KdbGroup *)parent {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (KdbEntry *)createEntry:(KdbGroup *)parent {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (NSString *)description {
  return self.root.description;
}

@end
