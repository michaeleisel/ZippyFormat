//
//  Tests.m
//  Tests
//
//  Created by Michael Eisel on 11/28/20.
//

#import <XCTest/XCTest.h>
#import "stringyLib.h"

@interface Tests : XCTestCase

@end

#define ARRAY_SIZE(x) sizeof(x) / sizeof(*(x))

@implementation Tests

// todo: subnormal floats?
- (void)testFloats
{
    long double ld = 1ULL << 63;
    const char *sizeSpecs[] = {"L", "l", ""};
    const char *numSpecs[] = {"a", "A", "e", "E", "f", "F", "g", "G"};
    const long double nums[] = {0, 1, -1, -2, (long double)(1ULL << 63), (long double)((1ULL << 63) - 1), (long double)(1ULL << 31), (1ULL << 31) - 1, 1ULL << 15, (1ULL << 15) - 1, 0.1, 3.1415, -0.1, FLT_MAX, DBL_MAX, FLT_MIN, DBL_MIN, LDBL_MAX, LDBL_MIN};
    ZCFstringCreateWithFormat(@"%a", nums[7]);
    for (int i = 0; i < ARRAY_SIZE(sizeSpecs); i++) {
        const char *sizeSpec = sizeSpecs[i];
        for (int j = 0; j < ARRAY_SIZE(numSpecs); j++) {
            const char *numSpec = numSpecs[j];
            for (int k = 0; k < ARRAY_SIZE(nums); k++) {
                if (strcmp(sizeSpec, "L") == 0) {
                    long double num = nums[k];
                    char *format = NULL;
                    asprintf(&format, "%%%s%s", sizeSpec, numSpec);
                    NSString *nsFormat = @(format);
                    NSString *actual = ZCFstringCreateWithFormat(nsFormat, num);
                    NSString *expected = [NSString stringWithFormat:nsFormat, num];
                    // todo: investigate why Apple seems to differ incorrectly from printf for this specifier
                    if (tolower(numSpec[0]) != 'a') {
                        // LDBL_MAX, for example, seems unnecessarily truncated by Apple
                        XCTAssert([actual isEqual:expected] || [expected length] > 500 && [actual hasPrefix:expected]);
                    }
                } else if (strcmp(sizeSpec, "l") == 0) {
                    double num = nums[k];
                    char *format = NULL;
                    asprintf(&format, "%%%s%s", sizeSpec, numSpec);
                    NSString *nsFormat = @(format);
                    NSString *actual = ZCFstringCreateWithFormat(nsFormat, num);
                    NSString *expected = [NSString stringWithFormat:nsFormat, num];
                    if (tolower(numSpec[0]) != 'a') {
                        XCTAssert([actual isEqual:expected]);
                    }
                } else { // float
                    float num = nums[k];
                    char *format = NULL;
                    asprintf(&format, "%%%s%s", sizeSpec, numSpec);
                    NSString *nsFormat = @(format);
                    NSString *actual = ZCFstringCreateWithFormat(nsFormat, num);
                    NSString *expected = [NSString stringWithFormat:nsFormat, num];
                    if (tolower(numSpec[0]) != 'a') {
                        XCTAssert([actual isEqual:expected]);
                    }
                }
            }
        }
    }
}

- (void)testInts
{
    ZCFstringCreateWithFormat(@"%lo", -1LL);
    ZCFstringCreateWithFormat(@"%@", [NSNumber numberWithUnsignedLongLong:ULLONG_MAX]);
    const char *sizeSpecs[] = {"h", "hh", "l", "ll", "q", "z", "t", "j", ""};
    const char *numSpecs[] = {"d", "u", "o", "x"};
    const int64_t nums[] = {0, 1, -1, -2, 1ULL << 63, (1ULL << 63) - 1, 1ULL << 31, (1ULL << 31) - 1, 1ULL << 15, (1ULL << 15) - 1};
    for (int i = 0; i < ARRAY_SIZE(sizeSpecs); i++) {
        const char *sizeSpec = sizeSpecs[i];
        for (int j = 0; j < ARRAY_SIZE(numSpecs); j++) {
            const char *numSpec = numSpecs[j];
            for (int k = 0; k < ARRAY_SIZE(nums); k++) {
                int64_t num = nums[k];
                char *format = NULL;
                asprintf(&format, "%%%s%s", sizeSpec, numSpec);
                NSString *nsFormat = @(format);
                NSString *actual = ZCFstringCreateWithFormat(nsFormat, num);
                NSString *expected = [NSString stringWithFormat:nsFormat, num];
                XCTAssert([actual isEqual:expected]);
            }
        }
    }
}

@end
