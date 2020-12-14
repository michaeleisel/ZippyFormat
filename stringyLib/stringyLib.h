//
//  stringyLib.h
//  stringyLib
//
//  Created by Michael Eisel on 11/28/20.
//

#import <Foundation/Foundation.h>

NSString *ZIPStringWithFormat(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
NSString *ZIPStringWithFormatAndArguments(NSString *format, va_list args) NS_FORMAT_FUNCTION(1,0);

@interface NSString (ZIP)
@end

@implementation NSString (ZIP)

- (NSString *)zip_stringWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
{
    va_list args;
    va_start(args, format);
    NSString *string = ZIPStringWithFormatAndArguments(format, args);
    va_end(args);
    return string;
}

@end
