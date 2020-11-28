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

- (void)testNumbers
{
    ZCFstringCreateWithFormat(@"%lo", -1LL);
    long double ld = 0.1;
    ZCFstringCreateWithFormat(@"%@", [NSNumber numberWithUnsignedLongLong:ULLONG_MAX]);
    const char *sizeSpecs[] = {"h", "hh", "l", "ll", ""};
    const char *numSpecs[] = {"d", "u", "o", "x"};
    const int64_t nums[] = {0, 1, -1, -2, 1ULL << 63, (1ULL << 63) - 1, 1ULL << 31, (1ULL << 31) - 1, 1ULL << 15, (1ULL << 15) - 1};
    for (int i = 0; i < ARRAY_SIZE(sizeSpecs); i++) {
        const char *sizeSpec = sizeSpecs[i];
        for (int j = 0; j < ARRAY_SIZE(numSpecs); j++) {
            const char *numSpec = numSpecs[j];
            for (int k = 0; k < sizeof(nums) / sizeof(*nums); k++) {
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
