//
//  Tests.m
//  Tests
//
//  Created by Michael Eisel on 11/28/20.
//

#import <XCTest/XCTest.h>
#import <ZippyFormat/ZippyFormat.h>

@interface CustomObject : NSObject
@end

@implementation CustomObject

- (NSString *)description
{
    return [ZIPStringFactory stringWithFormat:@"%@", @"foo"];
}

@end

@interface Tests : XCTestCase

@end

#define ARRAY_SIZE(x) sizeof(x) / sizeof(*(x))

#define PERF_TEST(title, format, ...) \
do { \
    NSString *expected = [NSString stringWithFormat:format, __VA_ARGS__]; \
    NSString *actual = [ZIPStringFactory stringWithFormat:format, __VA_ARGS__]; \
    XCTAssert([expected isEqual:actual]); \
    int limit = 5e4; \
    NSLog(@"%@", format); \
    for (int i = 0; i < 2; i++) { \
        CFTimeInterval start1, start2, end1, end2; \
        @autoreleasepool { \
            start1 = CACurrentMediaTime(); \
            for (int j = 0; j < limit; j++) { \
                [NSString stringWithFormat:format, __VA_ARGS__]; \
            } \
            end1 = CACurrentMediaTime(); \
        } \
        @autoreleasepool { \
            start2 = CACurrentMediaTime(); \
            for (int j = 0; j < limit; j++) { \
                [ZIPStringFactory stringWithFormat:format, __VA_ARGS__]; \
            } \
            end2 = CACurrentMediaTime(); \
        } \
        /*NSLog(@"mult:  %@", @((end1 - start1) / (end2 - start2))); */\
        /*NSLog(@"apple: %@, zippy: %@", @(1 / ((end1 - start1) / limit)), @(1 / ((end2 - start2) / limit)));*/ \
        NSLog(@"%s\t%@\t%@", title, @(1 / ((end1 - start1) / limit)), @(1 / ((end2 - start2) / limit))); \
    } \
} while(0)

#define PERF_TEST2(code) \
do { \
    int limit = 1e5; \
    for (int i = 0; i < 1; i++) { \
        NSLog(@"%s", #code); \
        CFTimeInterval start1, end1; \
        @autoreleasepool { \
            start1 = CACurrentMediaTime(); \
            for (int j = 0; j < limit; j++) { \
                code; \
            } \
            end1 = CACurrentMediaTime(); \
        } \
        NSLog(@"%@", @(end1 - start1)); \
    } \
} while(0)

const int64_t kTestNums[] = {0, 1, -1, -2, 1ULL << 63, (1ULL << 63) - 1, 1ULL << 31, (1ULL << 31) - 1, 1ULL << 15, (1ULL << 15) - 1};

@implementation Tests

static inline void testObject(id object) {
    NSString *expected = [NSString stringWithFormat:@"%@", object];
    NSString *actual = [ZIPStringFactory stringWithFormat:@"%@", object];
    XCTAssert([expected isEqual:actual]);
}

#define TEST(format, ...) \
do { \
NSString *expected = [NSString stringWithFormat:format, __VA_ARGS__]; \
NSString *actual = [ZIPStringFactory stringWithFormat:format, __VA_ARGS__]; \
XCTAssert([expected isEqual:actual]); \
} while(0)

const NSStringEncoding encodings[] = {NSASCIIStringEncoding, NSNEXTSTEPStringEncoding, NSJapaneseEUCStringEncoding, NSUTF8StringEncoding, NSISOLatin1StringEncoding, NSSymbolStringEncoding, NSNonLossyASCIIStringEncoding, NSShiftJISStringEncoding, NSISOLatin2StringEncoding, NSUnicodeStringEncoding, NSWindowsCP1251StringEncoding, NSWindowsCP1252StringEncoding, NSWindowsCP1253StringEncoding, NSWindowsCP1254StringEncoding, NSWindowsCP1250StringEncoding, NSISO2022JPStringEncoding, NSMacOSRomanStringEncoding, NSUTF16StringEncoding, NSUTF16BigEndianStringEncoding, NSUTF16LittleEndianStringEncoding, NSUTF32StringEncoding, NSUTF32BigEndianStringEncoding, NSUTF32LittleEndianStringEncoding};

- (void)testAll
{
    @autoreleasepool {
        [self runAllTests];
    }
}

- (void)runAllTests
{
    ({
        ({
            long long count = 0;
            TEST(@"%d%s%llnfoo%d", 2, "quick", &count, 2);
        });
        long long count1 = 1;
        [NSString stringWithFormat:@"%s%llnfoo", "quick", &count1];
        long long count2 = 1;
        [ZIPStringFactory stringWithFormat:@"%s%llnfoo%d", "quick", &count2];
        XCTAssert(count1 == count2);
    });

    // Bad
    ({
        TEST(@"%d%v", 2);
        NSString *string = @"%d😊";
        string = [string substringWithRange:NSMakeRange(0, [string length] - 1)];
        TEST(@"%@", string);
        TEST(string, 2);
        unichar chars[5];
        [@"foo" getBytes:chars maxLength:sizeof(chars) usedLength:NULL encoding:NSUTF16StringEncoding options:0 range:NSMakeRange(0, 3) remainingRange:NULL];
        TEST(@"%C", chars[0]);
        TEST(@"%S", (const unichar *)chars);
    });

    // Other
    ({
        XCTAssert([@"" isEqual:[ZIPStringFactory stringWithFormat:@""]]);
        TEST(@"%2$d, %1$@", @"foo", 2);
        TEST(@"%@", @"");
        TEST(@"%d%d", 1, 2);
        TEST(@"%.02lf", (double)1.1);
        TEST(@"%.02lf", (double)M_PI);
        TEST(@"%1$lf", (double)M_PI);
        TEST(@"%c", 'a');
        TEST(@"%c", 'a');
        TEST(@"%s %s", "the quick brown", "fox");
        TEST(@"%%%@", @"");
        TEST(@"%@", @"");
        TEST(@"%@", @"");
        TEST(@"the %@ brown %@ jumped over %@", @"quick", @"fox", @"the lazy dog");
        TEST(@"the %@ brown %@ jumped over %@.", @"quick", @"fox", @"the lazy dog");
        NSString *bigString = @"a";
        for (NSInteger i = 0; i < 13; i++) {
            bigString = [bigString stringByAppendingString:bigString];
            TEST(@"%@", bigString);
            NSString *nsFormat = [NSString stringWithFormat:@"%@%%1$d", bigString];
            TEST(nsFormat, 3);
            //TEST(@"%@%@%@%@", bigString, bigString, bigString, bigString);
            NSString *expected = [NSString stringWithFormat:@"%@%@%@%@", bigString, bigString, bigString, bigString];
            NSString *actual = [ZIPStringFactory stringWithFormat:@"%@%@%@%@", bigString, bigString, bigString, bigString];
            XCTAssert([expected isEqual:actual]);
        }
        TEST(@"%@", @"😊");
        const unichar chars[3] = {'a', 'b', 'c'};
        TEST(@"%@", [NSString stringWithCharacters:chars length:3]);
        for (int i = 0; i < ARRAY_SIZE(encodings); i++) {
            NSStringEncoding encoding = encodings[i];
            NSData *data = [@"the quick brown 😊 😊" dataUsingEncoding:encoding];
            if (data) {
                TEST(@"%@", [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:encoding]);
            }
        }
    });

    // Objects
    ({
        testObject(nil);
        testObject([@"asdf" dataUsingEncoding:NSUTF8StringEncoding]);
        testObject([[CustomObject alloc] init]);
        testObject([NSNumber numberWithChar:-1]);
        testObject(@"asdf");
        testObject(@1);
        testObject([NSNumber numberWithBool:YES]);
        testObject([NSNumber numberWithBool:NO]);
        testObject([NSNumber numberWithFloat:1.1]);
        testObject([NSNumber numberWithDouble:1.1]);
        testObject(@[@"asdf"]);
        testObject(@[@"asdf", @1, @[]]);
        testObject(@[]);
        testObject(@{});
        testObject(@{@"a": @2});
        testObject(@{@"a": @2, @"b": @3});
        testObject(@{@"a": @2, @"b": @[@2, @{@"c": @[@"asdf"]}]});
        for (int i = 0; i < ARRAY_SIZE(kTestNums); i++) {
            int64_t num = kTestNums[i];
            testObject([NSNumber numberWithChar:num]);
            testObject([NSNumber numberWithUnsignedChar:num]);
            testObject([NSNumber numberWithInt:(int)num]);
            testObject([NSNumber numberWithUnsignedInt:(unsigned int)num]);
            testObject([NSNumber numberWithInteger:num]);
            testObject([NSNumber numberWithUnsignedLongLong:num]);
            testObject([NSNumber numberWithLongLong:num]);
        }
    });

    // Floats
    ({
        const char *sizeSpecs[] = {"L", "l", ""};
        const char *numSpecs[] = {"a", "A", "e", "E", "f", "F", "g", "G"};
        const long double nums[] = {0, 1, -1, -2, (long double)(1ULL << 63), (long double)((1ULL << 63) - 1), (long double)(1ULL << 31), (1ULL << 31) - 1, 1ULL << 15, (1ULL << 15) - 1, 0.1, 3.1415, -0.1, FLT_MAX, DBL_MAX, FLT_MIN, DBL_MIN, LDBL_MAX, LDBL_MIN, INFINITY, -INFINITY, NAN};
        [ZIPStringFactory stringWithFormat:@"%a", (double)nums[7]];
        for (int i = 0; i < ARRAY_SIZE(sizeSpecs); i++) {
            const char *sizeSpec = sizeSpecs[i];
            for (int j = 0; j < ARRAY_SIZE(numSpecs); j++) {
                const char *numSpec = numSpecs[j];
                for (int k = 0; k < ARRAY_SIZE(nums); k++) {
                    if (strcmp(sizeSpec, "L") == 0) {
                        long double num = nums[k];
                        NSString *nsFormat = [NSString stringWithFormat:@"%%%s%s", sizeSpec, numSpec];
                        NSString *actual = [ZIPStringFactory stringWithFormat:nsFormat, num];
                        NSString *expected = [NSString stringWithFormat:nsFormat, num];
                        // todo: investigate why Apple seems to differ incorrectly from printf for this specifier
                        if (tolower(numSpec[0]) != 'a') {
                            // LDBL_MAX, for example, seems unnecessarily truncated by Apple
                            XCTAssert([actual isEqual:expected] || [expected length] > 500 && [actual hasPrefix:expected]);
                        }
                    } else if (strcmp(sizeSpec, "l") == 0) {
                        double num = nums[k];
                        NSString *nsFormat = [NSString stringWithFormat:@"%%%s%s", sizeSpec, numSpec];
                        NSString *actual = [ZIPStringFactory stringWithFormat:nsFormat, num];
                        NSString *expected = [NSString stringWithFormat:nsFormat, num];
                        if (tolower(numSpec[0]) != 'a') {
                            XCTAssert([actual isEqual:expected]);
                        }
                    } else { // float
                        float num = nums[k];
                        NSString *nsFormat = [NSString stringWithFormat:@"%%%s%s", sizeSpec, numSpec];
                        NSString *actual = [ZIPStringFactory stringWithFormat:nsFormat, num];
                        NSString *expected = [NSString stringWithFormat:nsFormat, num];
                        if (tolower(numSpec[0]) != 'a') {
                            XCTAssert([actual isEqual:expected]);
                        }
                    }
                }
            }
        }
    });

    // Ints
    ({
        const char *sizeSpecs[] = {"h", "hh", "l", "ll", "q", "z", "t", "j", ""};
        const char *numSpecs[] = {"d", "u", "o", "x"};
        for (int i = 0; i < ARRAY_SIZE(sizeSpecs); i++) {
            const char *sizeSpec = sizeSpecs[i];
            for (int j = 0; j < ARRAY_SIZE(numSpecs); j++) {
                const char *numSpec = numSpecs[j];
                for (int k = 0; k < ARRAY_SIZE(kTestNums); k++) {
                    int64_t num = kTestNums[k];
                    NSString *nsFormat = [NSString stringWithFormat:@"%%%s%s", sizeSpec, numSpec];
                    NSString *actual = [ZIPStringFactory stringWithFormat:nsFormat, num];
                    NSString *expected = [NSString stringWithFormat:nsFormat, num];
                    XCTAssert([actual isEqual:expected]);
                }
            }
        }
    });

    // Perf
    ({
        PERF_TEST("one_int", @"%d", 2);
        PERF_TEST("one_long_double", @"%Lf", (long double)M_PI);
        PERF_TEST("short_string", @"%@", @"short");
        PERF_TEST("long_string", @"%@", @"the quick brown fox jumped over the lazy dog");
        PERF_TEST("two_strings", @"%@%@", @"the quick brown fox ", @"jumped over the lazy dog");
        PERF_TEST("two_c_strings", @"%s%s", "the quick brown fox ", "jumped over the lazy dog");
        PERF_TEST("int_long_string", @"the quick brown fox jumped over %d lazy dogs", 2500);
        PERF_TEST("dictionary", @"%@", @{@"foo": @"bar"});
        PERF_TEST("array", @"%@", @[@"foo", @"bar"]);
        PERF_TEST("nsnumber", @"%@", @2.5);
        NSString *hugeString = @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        PERF_TEST("huge_string", @"%@%@%@%@", hugeString, hugeString, hugeString, hugeString);
    });
}

@end
