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

#import "DatabaseDocument.h"
#import "AppSettings.h"
#import "ImageFactory.h"
#import "KdbLib.h"
#import "Kdb4Node.h"

@interface DatabaseDocument ()
@property (nonatomic, strong) KdbPassword *kdbPassword;
@end

@implementation DatabaseDocument

- (id)initWithFilename:(NSString *)filename password:(NSString *)password keyFile:(NSString *)keyFile {
    self = [super init];
    if (self) {
        if (password == nil && keyFile == nil) {
            @throw [NSException exceptionWithName:@"IllegalArgument"
                                           reason:NSLocalizedString(@"No password or keyfile specified", nil)
                                         userInfo:nil];
        }

        self.filename = filename;

        NSStringEncoding passwordEncoding = [[AppSettings sharedInstance] passwordEncoding];
        self.kdbPassword = [[KdbPassword alloc] initWithPassword:password
                                                passwordEncoding:passwordEncoding
                                                         keyFile:keyFile];

        self.kdbTree = [KdbReaderFactory load:self.filename withPassword:self.kdbPassword];
        
        if([self.kdbTree isKindOfClass:[Kdb4Tree class]])
        {
            [[ImageFactory sharedInstance] initializeWithCustomIcons:((Kdb4Tree *)self.kdbTree).customIcons];
        }
    }
    return self;
}

- (void)save {
    [KdbWriterFactory persist:self.kdbTree file:self.filename withPassword:self.kdbPassword];
}

- (void)saveWithNewPassword:(NSString *)password {
    [KdbWriterFactory persist:self.kdbTree file:self.filename withPassword:[self.kdbPassword copyWithNewPassword:password]];
}

+ (void)searchGroup:(KdbGroup *)group searchText:(NSString *)searchText results:(NSMutableArray *)results {
    for (KdbEntry *entry in group.entries) {
        if ([self matchesEntry:entry searchText:searchText].count > 0) {
            [results addObject:entry];
        }
    }

    for (KdbGroup *g in group.groups) {
        if (![g.name isEqualToString:@"Backup"] && ![g.name isEqualToString:NSLocalizedString(@"Backup", nil)]) {
            [self searchGroup:g searchText:searchText results:results];
            
        }
    }
}

+ (NSMutableArray *)filterGroup:(KdbGroup *)group
                     searchText:(NSString *)searchText {
    
    NSMutableArray *fieldsAndEntries = [NSMutableArray new];
    // array for research
    NSMutableArray *results = [NSMutableArray new];
    // research into results array
    [self searchGroup:group searchText:searchText results:results];
    // filter each entry for exact match
    for (KdbEntry *entry in results) {
        NSArray *matches = [self matchesEntry:entry searchText:searchText];
        for (NSObject *match in matches) {
            if([match isKindOfClass:[KdbEntry class]])
                [fieldsAndEntries addObject:match];
            else if([match isKindOfClass:[StringField class]])
                [fieldsAndEntries addObject:match];
        }
    }
    return fieldsAndEntries;
}

+ (NSMutableArray *)filterEntries:(NSArray <KdbEntry *> *)entries
                       searchText:(NSString *)searchText {
    NSMutableArray *fieldsAndEntries = [NSMutableArray new];
    for (KdbEntry *entry in entries) {
        if([entry isKindOfClass:[KdbEntry class]]) {
            NSArray *matches = [self matchesEntry:entry searchText:searchText];
            for (NSObject *match in matches) {
                if([match isKindOfClass:[KdbEntry class]])
                    [fieldsAndEntries addObject:match];
                else if([match isKindOfClass:[StringField class]])
                    [fieldsAndEntries addObject:match];
            }
        }
        // KDBX 4 stringfields addition
        else if([entry isKindOfClass:[StringField class]]) {
            StringField *sf = (StringField *)entry;
            if([self matchesEntry:sf.containedIn searchText:searchText].count > 0)
                [fieldsAndEntries addObject:sf];
        }
        
    }
    return fieldsAndEntries;
}

+ (NSArray *)matchesEntry:(KdbEntry *)entry searchText:(NSString *)searchText {
    NSArray *matches = [NSArray array];
    if([searchText isEqualToString:@""] ||
       [entry.title rangeOfString:searchText options:NSCaseInsensitiveSearch].length > 0 ||
       [entry.username rangeOfString:searchText options:NSCaseInsensitiveSearch].length > 0 ||
       [entry.url rangeOfString:searchText options:NSCaseInsensitiveSearch].length > 0 ||
       [entry.notes rangeOfString:searchText options:NSCaseInsensitiveSearch].length > 0)
    {
        matches = [matches arrayByAddingObject:entry];
        if([entry isKindOfClass:[Kdb4Entry class]]) {
            Kdb4Entry *v4entry = (Kdb4Entry *)entry;
            matches = [matches arrayByAddingObjectsFromArray:v4entry.stringFields];
        }
       
    }
    // check for stringfields matches
    else if([entry isKindOfClass:[Kdb4Entry class]]) {
        Kdb4Entry *v4entry = (Kdb4Entry *)entry;
        NSArray <StringField *> *fields = v4entry.stringFields;
        for (StringField *strfield in fields) {
            if([strfield.key rangeOfString:searchText options:NSCaseInsensitiveSearch].length > 0)
                [matches arrayByAddingObject:strfield];
        }
    }
    return matches;
}



@end
