//
//  KPError.m
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 29.12.18.
//  Copyright © 2018 Self. All rights reserved.
//

#import "KPError.h"


NSString * const kMintError_defaultDomain = @"MintDefaultError";

NSInteger const kMintError_defaultInternalErrorCode = 7000;

@implementation NSError (KPErrorExtension)

-(NSString *)errorTitle
{
    return self.localizedDescription;
}

-(NSString *)errorMessage
{
    return self.localizedRecoverySuggestion;
}

-(BOOL) isInternalError
{
    return self.code == kMintError_defaultInternalErrorCode;
}

+ (instancetype _Nonnull )errorWithDomain:(NSErrorDomain _Nonnull )domain
                                     code:(NSInteger)code
                               errorTitle:(nullable NSString *)errorTitle
                             errorMessage:(nullable NSString *)errorMessage
{
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: errorTitle,
                               NSLocalizedRecoverySuggestionErrorKey: errorMessage
                               };
    
    NSError *error = [NSError errorWithDomain:domain
                                         code:code
                                     userInfo:userInfo];
    return error;
}

+ (instancetype _Nonnull )errorWithCode:(NSInteger)code
                             errorTitle:(nullable NSString *)errorTitle
                           errorMessage:(nullable NSString *)errorMessage
{
    return [self errorWithDomain:kMintError_defaultDomain
                            code:code
                      errorTitle:errorTitle
                    errorMessage:errorMessage];
}

+ (instancetype _Nonnull )errorWithTitle:(nullable NSString *)errorTitle
                            errorMessage:(nullable NSString *)errorMessage
{
    return [self errorWithCode:kMintError_defaultInternalErrorCode
                    errorTitle:errorTitle
                  errorMessage:errorMessage];
}

+ (instancetype _Nonnull )errorWithTitle:(nullable NSString *)errorTitle
                           messageFormat:(nullable NSString *)messageFormat, ... NS_FORMAT_FUNCTION(2,3)
{
    va_list va;
    va_start(va, messageFormat);
    NSString *string = [[NSString alloc] initWithFormat:messageFormat
                                              arguments:va];
    va_end(va);
    
    return [self errorWithCode:kMintError_defaultInternalErrorCode
                    errorTitle:errorTitle
                  errorMessage:string];
}

@end

@implementation KPError

@end
