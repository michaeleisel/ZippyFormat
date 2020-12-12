//
//  stringyLib.m
//  stringyLib
//
//  Created by Michael Eisel on 11/28/20.
//

#import "stringyLib.h"

#include <stdio.h>
#include <Foundation/Foundation.h>
#include <QuartzCore/QuartzCore.h>

#ifndef __LP64__
This is only meant for 64-bit systems
#endif

#define really_inline __attribute__((always_inline))

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
    NSInteger newCapacity = length * 2;
    char *newBuffer = malloc(newCapacity);
    memcpy(newBuffer, string->buffer, string->length);
    string->capacity = newCapacity;
    string->buffer = newBuffer;
    if (string->isStack) {
        string->isStack = NO;
    } else {
        free(string->buffer);
    }
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
    string->length = string->length + length;
}

static void appendChar(String *string, char c) {
    stringEnsureExtraCapacity(string, 1);
    string->buffer[string->length] = c;
    string->length++;
}

static inline void appendBinaryNumber(String *string, uint64_t num, int shiftWidth, int mask, int length, bool lowercase, bool isNegative) {
    assert(shiftWidth >= 3); // maxLength is only valid for shiftWidth >= 3
    int maxLength = 22; // ceil(64 / 3)
    if (num == 0) {
        appendChar(string, '0');
        return;
    }
    if (isNegative) {
        appendChar(string, '-');
    }
    char letterStart = lowercase ? 'a' : 'A';
    char temp[maxLength];
    int i = 0;
    while (i < maxLength && num != 0) {
        char next = num & mask;
        char output = next >= 10 ? letterStart + (next - 10) : '0' + next;
        temp[(maxLength - 1) - i] = output;
        num >>= shiftWidth;
        i++;
    }
    appendString(string, temp + maxLength - i, i);
}

static void appendHexNumber(String *string, uint64_t num, int length, bool lowercase, bool isNegative) {
    appendBinaryNumber(string, num, 4, 0xF, length, lowercase, isNegative);
}

static void appendOctNumber(String *string, uint64_t num, int length, bool lowercase, bool isNegative) {
    appendBinaryNumber(string, num, 3, 0x7, length, lowercase, isNegative);
}

static uint64_t printableInt(uint64_t raw, int size, bool treatAsSigned, bool *isNegative) {
    if (treatAsSigned && raw & (1ULL << (size * 8 - 1))) {
        *isNegative = true;
        raw = (~raw) + 1;
    } else {
        *isNegative = false;
    }

    // Mask out higher-order bits outside of the type size
    if (size < 8) {
        raw = raw & ((1ULL << (size * 8)) - 1);
    }
    return raw;
}

static uint64_t extractInt(va_list *args, int size, bool treatAsSigned, bool *isNegative) {
    uint64_t raw = 0;
    if (size == 1 || size == 2 || size == 4) {
        raw = va_arg(*args, unsigned int);
    } else if (size == 8) {
        raw = va_arg(*args, uint64_t);
    } else {
        abort();
    }

    return printableInt(raw, size, treatAsSigned, isNegative);
}

static void writeInt(String *string, uint64_t num, BOOL isNegative) {
    if (num == 0) {
        appendChar(string, '0');
        return;
    }

    if (isNegative) {
        appendChar(string, '-');
    }
    char buffer[24] = {0};
    int idx = sizeof(buffer) - 1;
    while (num != 0) {
        // These mods and divs may seem expensive, but note that they can be replaced by muls by the compiler
        buffer[idx] = '0' + num % 10;
        num /= 10;
        idx--;
    }
    appendString(string, &(buffer[idx + 1]), sizeof(buffer) - idx - 1);
}

static void writeFloat(String *string, const char *formatString, float f) {
    // Floats can translate to really big strings, so just use a reasonably small buffer to start with
    int size = 64;
    char smallBuffer[size];
    int bytesNeeded = snprintf(smallBuffer, sizeof(smallBuffer), formatString, f);
    if (bytesNeeded <= sizeof(smallBuffer) - 1) {
        appendString(string, smallBuffer, bytesNeeded);
        return;
    }
    char largeBuffer[bytesNeeded + 1];
    snprintf(largeBuffer, sizeof(largeBuffer), formatString, f);
    appendString(string, largeBuffer, bytesNeeded);
}

static void writeDouble(String *string, const char *formatString, double f) {
    // Floats can translate to really big strings, so just use a reasonably small buffer to start with
    int size = 64;
    char smallBuffer[size];
    int bytesNeeded = snprintf(smallBuffer, sizeof(smallBuffer), formatString, f);
    if (bytesNeeded <= sizeof(smallBuffer) - 1) {
        appendString(string, smallBuffer, bytesNeeded);
        return;
    }
    char largeBuffer[bytesNeeded + 1];
    snprintf(largeBuffer, sizeof(largeBuffer), formatString, f);
    appendString(string, largeBuffer, bytesNeeded);
}

static void writeLongDouble(String *string, const char *formatString, long double f) {
    // Floats can translate to really big strings, so just use a reasonably small buffer to start with
    int size = 64;
    char smallBuffer[size];
    int bytesNeeded = snprintf(smallBuffer, sizeof(smallBuffer), formatString, f);
    if (bytesNeeded <= sizeof(smallBuffer) - 1) {
        appendString(string, smallBuffer, bytesNeeded);
        return;
    }
    char largeBuffer[bytesNeeded + 1];
    snprintf(largeBuffer, sizeof(largeBuffer), "%Lf", f);
    appendString(string, largeBuffer, bytesNeeded);
}

static bool writeFloatIfPossible(String *string, const char **formatPtr, va_list *args) {
    char firstChar = **formatPtr;
    char floatFormatString[4] = {0};
    int floatFormatStringIdx = 0;
    floatFormatString[floatFormatStringIdx++] = '%';
    char c = '\0';
    if (firstChar == 'l' || firstChar == 'L') {
        floatFormatString[floatFormatStringIdx++] = firstChar;
        c = (*formatPtr)[1];
    } else {
        c = firstChar;
    }
    switch (tolower(c)) {
        case 'a':
        case 'e':
        case 'f':
        case 'g':
            floatFormatString[floatFormatStringIdx++] = c;
            if (firstChar == 'l') {
                writeDouble(string, floatFormatString, va_arg(*args, double));
                *formatPtr += 2;
            } else if (firstChar == 'L') {
                writeLongDouble(string, floatFormatString, va_arg(*args, long double));
                *formatPtr += 2;
            } else {
                writeFloat(string, floatFormatString, va_arg(*args, double));
                *formatPtr += 1;
            }
            return true;
            break;
        default:
            return false;
            break;
    }
}

static bool writeIntIfPossible(String *string, const char **formatPtr, va_list *args) {
    int skip = 1;
    int size = 0;
    switch (**formatPtr) {
        case 'h':
            if ((*formatPtr)[1] == 'h') {
                skip++;
                size = sizeof(char);
            } else {
                size = sizeof(short);
            }
            break;
        case 'l':
            if ((*formatPtr)[1] == 'l') {
                skip++;
                size = sizeof(long long);
            } else {
                size = sizeof(long);
            }
            break;
        case 'q':
            size = sizeof(long long);
            break;
        case 'z':
            size = sizeof(size_t);
            break;
        case 't':
            size = sizeof(ptrdiff_t);
            break;
        case 'j':
            size = sizeof(intmax_t);
            break;
        default:
            size = sizeof(int32_t);
            skip = 0;
    }

    bool isNegative = false;
    char c = (*formatPtr)[skip];
    switch (tolower(c)) {
        case 'd': {
            uint64_t num = extractInt(args, size, true /* treatAsSigned */, &isNegative);
            writeInt(string, num, isNegative);
            (*formatPtr) += skip + 1;
            return true;
        } break;
        case 'u': {
            uint64_t num = extractInt(args, size, false /* treatAsSigned */, &isNegative);
            writeInt(string, num, isNegative);
            (*formatPtr) += skip + 1;
            return true;
        } break;
        case 'x': {
            uint64_t num = extractInt(args, size, false /* treatAsSigned */, &isNegative);
            appendHexNumber(string, num, size, c == 'x', isNegative);
            (*formatPtr) += skip + 1;
            return true;
        } break;
        case 'o': {
            uint64_t num = extractInt(args, size, false /* treatAsSigned */, &isNegative);
            appendOctNumber(string, num, size, c == 'o', isNegative);
            (*formatPtr) += skip + 1;
            return true;
        } break;
        default:
            return false;
    }
}

static really_inline void appendNSString(String *string, NSString *nsString) {
    const char *cString = [nsString UTF8String];
    appendString(string, cString, strlen(cString));
}

static inline int sizeForTypeChar(char typeChar) {
    switch (tolower(typeChar)) {
        case 'c':
            return 1;
        case 's':
            return 2;
        case 'i':
            return 4;
        case 'l':
        case 'q':
            return 8;
    }
    assert(false);
    return 0;
}

static really_inline void appendNSNumber(String *string, NSNumber *number) {
    const char *typeStr = [number objCType];
    char typeChar = typeStr[0];
    if (typeChar != '\0' && typeStr[1] == 0) {
        if (typeChar == 'C' || typeChar == 'I' || typeChar == 'S' || typeChar == 'L' || typeChar == 'Q') {
            bool isNegative = false;
            uint64_t pi = printableInt([number unsignedLongLongValue], sizeForTypeChar(typeChar), false, &isNegative);
            writeInt(string, pi, isNegative);
            return;
        } else if (typeChar == 'c' || typeChar == 'i' || typeChar == 's' || typeChar == 'l' || typeChar == 'q') {
            bool isNegative = false;
            uint64_t pi = printableInt((uint64_t)[number longLongValue], sizeForTypeChar(typeChar), true, &isNegative);
            writeInt(string, pi, isNegative);
            return;
        } else if (typeChar == 'd' || typeChar == 'f') {
            writeDouble(string, "%g", [number doubleValue]);
            return;
        }
    }
    appendNSString(string, [number description]);
}

static really_inline void appendNSArray(String *string, NSArray *array, int nestLevel);
static really_inline void appendNSDictionary(String *string, NSDictionary *dictionary, int nestLevel);

static void appendNSObject(String *string, id object, int nestLevel) {
    if ([object isKindOfClass:[NSArray class]]) {
        appendNSArray(string, object, nestLevel);
    } else if ([object isKindOfClass:[NSDictionary class]]) {
        appendNSDictionary(string, object, nestLevel);
    } else if ([object isKindOfClass:[NSString class]]) {
        appendNSString(string, object);
    } else if ([object isKindOfClass:[NSNumber class]]) {
        appendNSNumber(string, object);
    } else {
        appendNSString(string, [object description]);
    }
    // More can always be added here, such as for NSData
}

static really_inline void appendNesting(String *string, int nestLevel) {
    for (int i = 0; i < nestLevel + 1; i++) {
        APPEND_LITERAL(string, "    ");
    }
}

static really_inline void appendNSDictionary(String *string, NSDictionary *dictionary, int nestLevel) {
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

static really_inline void appendNSArray(String *string, NSArray *array, int nestLevel) {
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

static void appendObject(String *string, va_list *args) {
    id object = va_arg(*args, id);
    appendNSObject(string, object, 0);
}

NSString *ZCFstringCreateWithFormat(NS_VALID_UNTIL_END_OF_SCOPE NSString *format, ...) {
    va_list args;
    va_list argsCopy;
    va_start(args, format);
    va_copy(argsCopy, args);
    const char *cString = [format UTF8String];
    NSInteger cStringLength = strlen(cString);
    const char *curr = cString;
    const NSInteger initialOutputCapacity = 200;
    char stackString[initialOutputCapacity];
    String output = stringCreate(stackString, initialOutputCapacity);
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
                appendObject(&output, &args);
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
                bool appendDone = writeIntIfPossible(&output, &curr, &args);
                if (!appendDone) {
                    appendDone = writeFloatIfPossible(&output, &curr, &args);
                }
                if (!appendDone) {
                    // unrecognized specifier
                }
            } break;
        }
        if (output.useApple) {
            break;
        }
    }
    va_end(args);
    if (output.useApple) {
        return [[NSString alloc] initWithFormat:format arguments:argsCopy];
    }
    va_end(argsCopy);
    if (output.isStack) {
        return CFBridgingRelease(CFStringCreateWithBytes(kCFAllocatorDefault, (UInt8 *)output.buffer, output.length, kCFStringEncodingUTF8, NO));
    } else {
        return CFBridgingRelease(CFStringCreateWithBytesNoCopy(kCFAllocatorDefault, (UInt8 *)output.buffer, output.length, kCFStringEncodingUTF8, NO, kCFAllocatorMalloc));
    }
}

NSString *smallFormattedString() {
    return ZCFstringCreateWithFormat(@"%@", @"foo");
}
