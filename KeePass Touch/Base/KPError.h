//
//  KPError.h
//  KeePass Touch
//
//  Created by Aljoscha Lüers on 29.12.18.
//  Copyright © 2018 Self. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (KPErrorExtension)

/**Use this when presenting Alerts. <br>
 * Will return localizedDescription <br>
 */
@property (nullable,readonly,copy) NSString *errorTitle;

/**Use this when presenting Alerts. <br>
 * Will return localizedRecoverySuggestion <br>
 */
@property (nullable,readonly,copy) NSString *errorMessage;

/**Will return yes if the constructor errorWithTitle:errorMessage was used <br>
 */
@property (nonatomic,readonly) BOOL isInternalError;

/*!
 @brief Create a NSError with custom NSErrorDomain,ErrorCode,ErrorTitle and ErrorMessage
 @param domain the NSError domain
 @param code the NSError code
 @param errorTitle the title of the error
 @param errorMessage the message of the error
 @return NSError
 */
+ (instancetype _Nonnull )errorWithDomain:(NSErrorDomain _Nonnull )domain
                                     code:(NSInteger)code
                               errorTitle:(nullable NSString *)errorTitle
                             errorMessage:(nullable NSString *)errorMessage;

/*!
 @brief Create a NSError with custom ErrorCode,ErrorTitle and ErrorMessage. Uses kMintError_defaultDomain as NSError domain
 @param code the NSError code
 @param errorTitle the title of the error
 @param errorMessage the message of the error
 @return NSError
 */
+ (instancetype _Nonnull )errorWithCode:(NSInteger)code
                             errorTitle:(nullable NSString *)errorTitle
                           errorMessage:(nullable NSString *)errorMessage;

/*!
 @brief Create a NSError with custom ErrorTitle and ErrorMessage. Uses kMintError_defaultDomain as NSError domain and kMintError_defaulInternalCode as NSError code
 @param errorTitle the title of the error
 @param errorMessage the message of the error
 @return NSError
 */
+ (instancetype _Nonnull )errorWithTitle:(nullable NSString *)errorTitle
                            errorMessage:(nullable NSString *)errorMessage;

/*!
 @brief Create a NSError with custom ErrorTitle and ErrorMessage. Uses kMintError_defaultDomain as NSError domain and kMintError_defaulInternalCode as NSError code
 @param errorTitle the title of the error
 @param messageFormat the message of the error
 @return NSError
 */
+ (instancetype _Nonnull )errorWithTitle:(nullable NSString *)errorTitle
                           messageFormat:(nullable NSString *)messageFormat, ... NS_FORMAT_FUNCTION(2,3);



@end

@interface KPError : NSError

@end
