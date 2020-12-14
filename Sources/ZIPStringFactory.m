#import <Foundation/Foundation.h>

#import "ZippyFormat.h"

#ifndef __LP64__
This is only meant for 64-bit systems
#endif

typedef struct {
    char *buffer;
    NSInteger length;
    NSInteger capacity;
    BOOL isStack;
    BOOL useApple;
} String;

static String stringCreate(char *stackString, NSInteger capacity) {
    String string = {
        .buffer = stackString,
        .length = 0,
        .capacity = capacity,
        .isStack = YES,
        .useApple = NO,
    };
    return string;
}

static inline void stringEnsureExtraCapacity(String *string, NSInteger length) {
    NSInteger newLength = string->length + length;
    if (newLength <= string->capacity) {
        return;
    }
    NSInteger newCapacity = newLength * 2;
    char *newBuffer = malloc(newCapacity);
    memcpy(newBuffer, string->buffer, string->length);
    string->capacity = newCapacity;
    if (string->isStack) {
        string->isStack = NO;
    } else {
        free(string->buffer);
    }
    string->buffer = newBuffer;
}

#define APPEND_LITERAL(string, literal) \
do { \
_Static_assert(sizeof(literal) != 8, "literal looks like a pointer"); \
_Static_assert(sizeof(literal) != 0, "zero-length literal not allowed"); \
appendString(string, literal, sizeof(literal) - 1); \
} \
while (0)

static void appendString(String *string, const char *src, NSInteger length) {
    stringEnsureExtraCapacity(string, length);
    memcpy(string->buffer + string->length, src, length);
    string->length += length;
}

static void appendChar(String *string, char c) {
    stringEnsureExtraCapacity(string, 1);
    string->buffer[string->length] = c;
    string->length++;
}

static bool writeNumberIfPossible(String *string, const char **formatPtr, va_list args) {
    const char *format = *formatPtr;
    while (true) {
        char c = *format;
        if (c == '$' || c == '*' || c == '\0') {
            // Positional and * arguments not supported, and '\0' indicates malformed string
            return false;
        }
        char lower = tolower(c);
        if (lower == 'a' || lower == 'e' || lower == 'f' || lower == 'g' || lower == 'd' || lower == 'i' || lower == 'u' || lower == 'o' || lower == 'x' || lower == 'c' || lower == 'p' || lower == 'n') {
            if (lower == 'n') {
                va_arg(args, void *);
                *formatPtr = format + 1;
                return true;
            }
            long length = format - (*formatPtr) + 3;
            char tempFormat[length];
            memcpy(tempFormat, (*formatPtr) - 1, length - 1);
            tempFormat[length - 1] = '\0';
            const int shortDestinationLength = 64;
            char shortDestination[shortDestinationLength];
            int needed = vsnprintf(shortDestination, shortDestinationLength, tempFormat, args);
            if (needed < shortDestinationLength) { // If needed == destinationLength, the null terminator is the issue
                appendString(string, shortDestination, needed);
                *formatPtr = format + 1;
            } else {
                // Number was too large. This is pretty exceptional, i.e. a giant float
                return false;
            }
            return true;
        }
        format++;
    }
    return false;
}

static inline void appendNSString(String *string, NSString *nsString) {
    const char *cString = [nsString UTF8String];
    if (cString) {
        appendString(string, cString, strlen(cString));
    } else {
        string->useApple = true;
    }
}

static inline void appendNSNumber(String *string, NSNumber *number) {
    const char *typeStr = [number objCType];
    char typeChar = typeStr[0];
    if (typeChar != '\0' && typeStr[1] == 0) {
        if (typeChar == 'C' || typeChar == 'I' || typeChar == 'S' || typeChar == 'L' || typeChar == 'Q') {
            char buffer[20 /*digits*/ + 1 /*terminator*/];
            snprintf(buffer, sizeof(buffer), "%llu", [number unsignedLongLongValue]);
            appendString(string, buffer, strlen(buffer));
            return;
        } else if (typeChar == 'c' || typeChar == 'i' || typeChar == 's' || typeChar == 'l' || typeChar == 'q') {
            char buffer[19 /*digits*/ + 1 /*minus sign*/ + 1 /*terminator*/];
            snprintf(buffer, sizeof(buffer), "%lld", [number longLongValue]);
            appendString(string, buffer, strlen(buffer));
            return;
        } else if (typeChar == 'd' || typeChar == 'f') {
            double d = [number doubleValue];
            const int bufferSize = 32;
            char buffer[bufferSize];
            int needed = snprintf(buffer, bufferSize, "%g", d);
            if (needed < bufferSize) {
                appendString(string, buffer, strlen(buffer));
                return;
            }
        }
    }
    appendNSString(string, [number description]);
}

static inline void appendNSArray(String *string, NSArray *array, int nestLevel);
static inline void appendNSDictionary(String *string, NSDictionary *dictionary, int nestLevel);

static void appendNSObject(String *string, id object, int nestLevel) {
    Class nsObjectClass = [NSObject class];
    // To speed up class comparisons, just look at the classes in the object's class hierarchy whose depth we know to be the same as
    // as the class we're comparing against
    Class nearTopClass = [object class];
    Class nearNearTopClass = nil;
    while (YES) {
        Class superclass = [nearTopClass superclass];
        if (superclass == nsObjectClass || superclass == nil) { // superclass == nil if the root class here is, e.g., NSProxy
            break;
        }
        nearNearTopClass = nearTopClass;
        nearTopClass = superclass;
    }
    if (nearTopClass == [NSArray class]) {
        appendNSArray(string, object, nestLevel);
    } else if (nearTopClass == [NSDictionary class]) {
        appendNSDictionary(string, object, nestLevel);
    } else if (nearTopClass == [NSString class]) {
        appendNSString(string, object);
    } else if (nearNearTopClass == [NSNumber class]) { // NSNumber -> NSValue -> NSObject
        appendNSNumber(string, object);
    } else {
        appendNSString(string, [object description]);
    }
    // More can always be added here, such as for NSData
}

static inline void appendNesting(String *string, int nestLevel) {
    for (int i = 0; i < nestLevel + 1; i++) {
        APPEND_LITERAL(string, "    ");
    }
}

static inline void appendNSDictionary(String *string, NSDictionary *dictionary, int nestLevel) {
    appendNesting(string, nestLevel - 1);
    appendString(string, "{\n", 2);
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        appendNesting(string, nestLevel);
        appendNSObject(string, key, nestLevel + 1);
        APPEND_LITERAL(string, " = ");
        appendNSObject(string, obj, nestLevel + 1);
        APPEND_LITERAL(string, ";\n");
    }];
    appendNesting(string, nestLevel - 1);
    appendChar(string, '}');
}

static inline void appendNSArray(String *string, NSArray *array, int nestLevel) {
    appendNesting(string, nestLevel - 1);
    APPEND_LITERAL(string, "(\n");
    NSInteger i = 0;
    NSInteger count = [array count];
    // Use fast enumeration, with our own index, in case fast enumeration is better optimized, e.g. for retain/release
    for (id element in array) {
        appendNesting(string, nestLevel);
        appendNSObject(string, element, nestLevel + 1);
        if (i < count - 1) {
            appendChar(string, ',');
        }
        appendChar(string, '\n');
        i++;
    }
    appendNesting(string, nestLevel - 1);
    appendChar(string, ')');
}

static void appendObject(String *string, va_list args) {
    id object = va_arg(args, id);
    appendNSObject(string, object, 0);
}

NSString *ZIPStringWithFormatAndArguments(NSString *format, va_list args) {
    va_list argsCopy;
    va_copy(argsCopy, args);
    const NSInteger initialOutputCapacity = 500;
    char stackString[initialOutputCapacity];
    String output = stringCreate(stackString, initialOutputCapacity);
    const char *cString = NULL;
    const char *formatCString = [format UTF8String];
    if (formatCString) {
        cString = formatCString;
    } else {
        output.useApple = true;
        cString = "";
    }
    NSInteger cStringLength = strlen(cString);
    const char *curr = cString;
    while (YES) {
        NSInteger remaining = cStringLength - (curr - cString);
        const char *next = memchr(curr, '%', remaining);
        if (!next) {
            appendString(&output, curr, remaining);
            break;
        }
        appendString(&output, curr, next - curr);
        curr = next + 1;
        switch (*curr) {
            case '@':
                appendObject(&output, args);
                curr++;
                break;
            case '%':
                appendChar(&output, '%');
                curr++;
                break;
            case 'C': {
                output.useApple = YES;
                curr++;
            } break;
            case 's': {
                const char *str = va_arg(args, char *);
                appendString(&output, str, strlen(str));
                curr++;
            } break;
            case 'S': {
                output.useApple = YES;
                curr++;
            } break;
            default: {
                // This function assumes it's at the end, cannot have any legitimate cases after it
                bool appendDone = writeNumberIfPossible(&output, &curr, args);
                if (!appendDone) {
                    // Format string appears malformed, which is UB, but just match Apple's treatment of the UB
                    output.useApple = YES;
                }
            } break;
        }
        if (output.useApple) {
            break;
        }
    }
    if (output.useApple) {
        NSString *string = [[NSString alloc] initWithFormat:format arguments:argsCopy];
        va_end(argsCopy);
        return string;
    }
    va_end(argsCopy);
    if (output.isStack) {
        return CFBridgingRelease(CFStringCreateWithBytes(kCFAllocatorDefault, (UInt8 *)output.buffer, output.length, kCFStringEncodingUTF8, NO));
    } else {
        return CFBridgingRelease(CFStringCreateWithBytesNoCopy(kCFAllocatorDefault, (UInt8 *)output.buffer, output.length, kCFStringEncodingUTF8, NO, kCFAllocatorMalloc));
    }
}

@implementation ZIPStringFactory

+ (NSString *)stringWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);
{
    va_list args;
    va_start(args, format);
    NSString *string = ZIPStringWithFormatAndArguments(format, args);
    va_end(args);
    return string;
}

@end

NSString *smallFormattedString() {
    return [ZIPStringFactory stringWithFormat:@"%@", @"foo"];
}

