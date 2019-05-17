//
//  CoreImageMetalFilterTests.m
//  CoreImageMetalFilterTests
//
//  Created by Mo DeJong on 12/13/18.
//  Copyright © 2019 Mo DeJong. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "sRGB.h"
#import "BT709.h"

@interface CoreImageMetalFilterTests : XCTestCase

@end

static inline
BOOL
floatIsEqualEpsilion(float f1, float f2, float epsilion)
{
  float delta = f1 - f2;
  return (delta < epsilion);
}

static inline
BOOL
floatIsEqual(float f1, float f2)
{
  float epsilion = 0.001;
  return floatIsEqualEpsilion(f1, f2, epsilion);
}

@implementation CoreImageMetalFilterTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (BOOL) isExactlyTheSame:(int)R
                        G:(int)G
                        B:(int)B
                     decR:(int)decR
                     decG:(int)decG
                     decB:(int)decB
{
  return (B == decB) && (G == decG) && (R == decR);
}

// Is v2 close enough to v1 (+- delta), return TRUE if so

- (BOOL) isCloseEnough:(int)v1
                    v2:(int)v2
                 delta:(int)delta
{
  assert(delta > 0);
  
  int max = (v1 + delta);
  int min = (v1 - delta);
  
  if (v2 >= min && v2 <= max) {
    return TRUE;
  } else {
    return FALSE;
  }
}

- (BOOL) isOffBy:(int)R
               G:(int)G
               B:(int)B
            decR:(int)decR
            decG:(int)decG
            decB:(int)decB
           delta:(int)delta
{
  BOOL BClose = [self isCloseEnough:B v2:decB delta:delta];
  BOOL GClose = [self isCloseEnough:G v2:decG delta:delta];
  BOOL RClose = [self isCloseEnough:R v2:decR delta:delta];
  
  if (BClose == FALSE || GClose == FALSE || RClose == FALSE) {
    // One of these values is larger than +-1 delta
    return FALSE;
  } else {
    // All 3 values are close enough
    return TRUE;
  }
}


- (void)testConvertsLinearRGBToBT709_NoGamma_75Percent {
  
  // Gray at 75% intensity
  //
  // Linear RGB (191 191 191) -> REC.709 (180 128 128)
  
  int Rin = 191;
  int Gin = Rin;
  int Bin = Rin;
  
  float Rn, Gn, Bn;
  
  Rn = byteNorm(Rin);
  Gn = Rn;
  Bn = Rn;
  
  int Y, Cb, Cr;
  int applyGammaMap = 0;
  
  int result;
  
  result = BT709_convertLinearRGBToYCbCr(Rn, Gn, Bn, &Y, &Cb, &Cr, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = Y;
    int expectedVal = 180;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cb;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int R, G, B;
  result = BT709_convertYCbCrToRGB(Y, Cb, Cr, &R, &G, &B, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = R;
    int expectedVal = Rin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = G;
    int expectedVal = Gin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = B;
    int expectedVal = Bin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
}

- (void)testConvertsLinearRGBToBT709_WithGamma_75Percent {
  
  // Gray at 75% intensity
  //
  // Linear RGB (191 191 191) -> REC.709 (206 128 128)
  
  int Rin = 191;
  int Gin = Rin;
  int Bin = Rin;
  
  float Rn, Gn, Bn;
  
  Rn = byteNorm(Rin);
  Gn = Rn;
  Bn = Rn;
  
  int Y, Cb, Cr;
  int applyGammaMap = 1;
  
  int result;
  
  result = BT709_convertLinearRGBToYCbCr(Rn, Gn, Bn, &Y, &Cb, &Cr, applyGammaMap);
  XCTAssert(result == 0);
  
  // iOS emits 210 for this Y value, what is the gamma?
  
  {
    int v = Y;
    int expectedVal = 206;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cb;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int R, G, B;
  result = BT709_convertYCbCrToRGB(Y, Cb, Cr, &R, &G, &B, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = R;
    int expectedVal = Rin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = G;
    int expectedVal = Gin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = B;
    int expectedVal = Bin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
}

- (void)testConvertsLinearRGBToBT709_NoGamma_25Percent {
  
  // Gray at 25% intensity
  //
  // Linear RGB (64 64 64) -> REC.709 (71 128 128)
  
  int Rin = 64;
  int Gin = Rin;
  int Bin = Rin;
  
  float Rn, Gn, Bn;
  
  Rn = byteNorm(Rin);
  Gn = Rn;
  Bn = Rn;
  
  int Y, Cb, Cr;
  int applyGammaMap = 0;
  
  int result;
  
  result = BT709_convertLinearRGBToYCbCr(Rn, Gn, Bn, &Y, &Cb, &Cr, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = Y;
    int expectedVal = 71;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cb;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int R, G, B;
  result = BT709_convertYCbCrToRGB(Y, Cb, Cr, &R, &G, &B, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = R;
    int expectedVal = Rin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = G;
    int expectedVal = Gin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = B;
    int expectedVal = Bin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
}

- (void)testConvertsLinearRGBToBT709_WithGamma_25Percent {
  
  // Gray at 25% intensity
  //
  // Linear RGB (64 64 64) -> REC.709 (124 128 128)
  
  // Note that using the rounded linear value 64
  // means that the output is rounded up and then
  // the decoded value is +1. When an intermediate
  // float is used the Y rounds down to 123 which
  // decodes exactly when returning to sRGB.
  
  int Rin = 64;
  int Gin = Rin;
  int Bin = Rin;
  
  float Rn, Gn, Bn;
  
  Rn = byteNorm(Rin);
  Gn = Rn;
  Bn = Rn;
  
  int Y, Cb, Cr;
  int applyGammaMap = 1;
  
  int result;
  
  result = BT709_convertLinearRGBToYCbCr(Rn, Gn, Bn, &Y, &Cb, &Cr, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = Y;
    int expectedVal = 124;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cb;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int R, G, B;
  result = BT709_convertYCbCrToRGB(Y, Cb, Cr, &R, &G, &B, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = R;
    int expectedVal = Rin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = G;
    int expectedVal = Gin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = B;
    int expectedVal = Bin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
}

- (void)testConvertsLinearRGBToBT709_42PercentBlue_srgb {
  // sRGB (0 0 107) -> REC.709 (22 169 124)
  
  int Rin = 0;
  int Gin = 0;
  int Bin = 107;
  
  int Y, Cb, Cr;
  int applyGammaMap = 1;
  
  int result;
  
  result = BT709_from_sRGB_convertRGBToYCbCr(Rin, Gin, Bin, &Y, &Cb, &Cr, 1);
  XCTAssert(result == 0);
  
  {
    int v = Y;
    int expectedVal = 22;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cb;
    int expectedVal = 169;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 124;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int R, G, B;
  result = BT709_to_sRGB_convertYCbCrToRGB(Y, Cb, Cr, &R, &G, &B, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = R;
    int expectedVal = Rin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = G;
    int expectedVal = Gin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = B;
    int expectedVal = Bin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
}

// Round trip sRGB -> BT.709 with all R,G,B values

- (void)testConvertsRGBTo709_RoundTripAll_WithGamma {
  
  // The sRGB space will contain more pixels than the BT.709
  // space because of the compressed range of YCbCr vlaues.
  
  NSMutableDictionary *mDict = [NSMutableDictionary dictionary];
  
  mDict[@"exact"] = @(0);
  mDict[@"off1"] = @(0);
  mDict[@"off2"] = @(0);
  mDict[@"off3"] = @(0);
  mDict[@"off4"] = @(0);
  mDict[@"off5"] = @(0);
  mDict[@"off6"] = @(0);
  mDict[@"off7"] = @(0);
  mDict[@"off8"] = @(0);
  mDict[@"off9"] = @(0);
  mDict[@"offMore9"] = @(0);
  
  const int applyGammaMap = 1;
  
  for (int R = 0; R <= 255; R++) {
    for (int G = 0; G <= 255; G++) {
      for (int B = 0; B <= 255; B++) {
        
        int Y, Cb, Cr;
        
        int result;
        
        result = BT709_from_sRGB_convertRGBToYCbCr(R, G, B, &Y, &Cb, &Cr, applyGammaMap);
        XCTAssert(result == 0);
        
        // Reverse encoding process to get back to original RGB
        
        int decR, decG, decB;
        
        result = BT709_to_sRGB_convertYCbCrToRGB(Y, Cb, Cr, &decR, &decG, &decB, applyGammaMap);
        XCTAssert(result == 0);
        
        // Determine if the round trip is exact, off by 1, off by 2
        // or off by more than 2.
        
        BOOL isTheSame = [self isExactlyTheSame:R G:G B:B decR:decR decG:decG decB:decB];
        
        if (isTheSame) {
          // Increment count of values that are exactly the same
          
          NSString *key = @"exact";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:1]) {
          NSString *key = @"off1";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:2]) {
          NSString *key = @"off2";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:3]) {
          NSString *key = @"off3";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:4]) {
          NSString *key = @"off4";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:5]) {
          NSString *key = @"off5";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:6]) {
          NSString *key = @"off6";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:7]) {
          NSString *key = @"off7";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:8]) {
          NSString *key = @"off8";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:9]) {
          NSString *key = @"off9";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else {
          // Off by more than 3, save as a key
          NSString *str = [NSString stringWithFormat:@"(%d %d %d) != (%d %d %d)", R, G, B, decR, decG, decB];
          //          mDict[str] = @"";
          
          NSString *key = @"offMore9";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        }
      }
    }
  }
  
  NSLog(@"mDict %@", mDict);
  
  // Lossy range conversion means a whole bunch of colors are not an exact match
  
  XCTAssert([mDict[@"exact"] intValue] == 2753221, @"all exact");
  
  return;
}

/* Round trip with software
 
 exact =  2753221
 off1 =  12653553
 off2 =   1006705
 off3 =    295446
 off4 =     67339
 off5 =       952
 off6 =         0
 off7 =         0
 off8 =         0
 off9 =         0
 offMore9 =     0
 
 */

// Round trip sRGB -> Apple196 with all R,G,B values

- (void)testConvertsRGBToApple196_RoundTripAll_WithGamma {
  
  // The sRGB space will contain more pixels than the BT.709
  // space because of the compressed range of YCbCr vlaues.
  
  NSMutableDictionary *mDict = [NSMutableDictionary dictionary];
  
  mDict[@"exact"] = @(0);
  mDict[@"off1"] = @(0);
  mDict[@"off2"] = @(0);
  mDict[@"off3"] = @(0);
  mDict[@"off4"] = @(0);
  mDict[@"off5"] = @(0);
  mDict[@"off6"] = @(0);
  mDict[@"off7"] = @(0);
  mDict[@"off8"] = @(0);
  mDict[@"off9"] = @(0);
  mDict[@"offMore9"] = @(0);
  
  const int applyGammaMap = 1;
  
  for (int R = 0; R <= 255; R++) {
    for (int G = 0; G <= 255; G++) {
      for (int B = 0; B <= 255; B++) {
        
        int Y, Cb, Cr;
        
        int result;
        
        result = Apple196_from_sRGB_convertRGBToYCbCr(R, G, B, &Y, &Cb, &Cr);
        XCTAssert(result == 0);
        
        // Reverse encoding process to get back to original RGB
        
        int decR, decG, decB;
        
        result = Apple196_to_sRGB_convertYCbCrToRGB(Y, Cb, Cr, &decR, &decG, &decB, applyGammaMap);
        XCTAssert(result == 0);
        
        // Determine if the round trip is exact, off by 1, off by 2
        // or off by more than 2.
        
        BOOL isTheSame = [self isExactlyTheSame:R G:G B:B decR:decR decG:decG decB:decB];
        
        if (isTheSame) {
          // Increment count of values that are exactly the same
          
          NSString *key = @"exact";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:1]) {
          NSString *key = @"off1";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:2]) {
          NSString *key = @"off2";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:3]) {
          NSString *key = @"off3";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:4]) {
          NSString *key = @"off4";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:5]) {
          NSString *key = @"off5";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:6]) {
          NSString *key = @"off6";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:7]) {
          NSString *key = @"off7";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:8]) {
          NSString *key = @"off8";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:9]) {
          NSString *key = @"off9";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else {
          // Off by more than 3, save as a key
          NSString *str = [NSString stringWithFormat:@"(%d %d %d) != (%d %d %d)", R, G, B, decR, decG, decB];
          //          mDict[str] = @"";
          
          NSString *key = @"offMore9";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        }
      }
    }
  }
  
  NSLog(@"mDict %@", mDict);
  
  // Lossy range conversion means a whole bunch of colors are not an exact match
  
  XCTAssert([mDict[@"exact"] intValue] == 2753405, @"all exact");
  
  return;
}

/*
 Software results:
 
 exact =  2753405;
 off1  = 13499212;
 off2  =   524599;
 off3 = 0;
 off4 = 0;
 off5 = 0;
 off6 = 0;
 off7 = 0;
 off8 = 0;
 off9 = 0;
 offMore9 = 0;
 
 */


// SRGB curve to represent gamma encoded value before matrix transform

- (void)testConvertSRGBToSRGB_RoundTripAll_WithGamma {
  
  // The sRGB space will contain more pixels than the BT.709
  // space because of the compressed range of YCbCr vlaues.
  
  NSMutableDictionary *mDict = [NSMutableDictionary dictionary];
  
  mDict[@"exact"] = @(0);
  mDict[@"off1"] = @(0);
  mDict[@"off2"] = @(0);
  mDict[@"off3"] = @(0);
  mDict[@"off4"] = @(0);
  mDict[@"off5"] = @(0);
  mDict[@"off6"] = @(0);
  mDict[@"off7"] = @(0);
  mDict[@"off8"] = @(0);
  mDict[@"off9"] = @(0);
  mDict[@"offMore9"] = @(0);
  
  const int applyGammaMap = 1;
  
  for (int R = 0; R <= 255; R++) {
    for (int G = 0; G <= 255; G++) {
      for (int B = 0; B <= 255; B++) {
        
        int Y, Cb, Cr;
        
        int result;
        
        result = sRGB_from_sRGB_convertRGBToYCbCr(R, G, B, &Y, &Cb, &Cr);
        XCTAssert(result == 0);
        
        // Reverse encoding process to get back to original RGB
        
        int decR, decG, decB;
        
        result = sRGB_to_sRGB_convertYCbCrToRGB(Y, Cb, Cr, &decR, &decG, &decB, applyGammaMap);
        XCTAssert(result == 0);
        
        // Determine if the round trip is exact, off by 1, off by 2
        // or off by more than 2.
        
        BOOL isTheSame = [self isExactlyTheSame:R G:G B:B decR:decR decG:decG decB:decB];
        
        if (isTheSame) {
          // Increment count of values that are exactly the same
          
          NSString *key = @"exact";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:1]) {
          NSString *key = @"off1";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:2]) {
          NSString *key = @"off2";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:3]) {
          NSString *key = @"off3";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:4]) {
          NSString *key = @"off4";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:5]) {
          NSString *key = @"off5";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:6]) {
          NSString *key = @"off6";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:7]) {
          NSString *key = @"off7";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:8]) {
          NSString *key = @"off8";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else if ([self isOffBy:R G:G B:B decR:decR decG:decG decB:decB delta:9]) {
          NSString *key = @"off9";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        } else {
          // Off by more than 3, save as a key
          NSString *str = [NSString stringWithFormat:@"(%d %d %d) != (%d %d %d)", R, G, B, decR, decG, decB];
          //          mDict[str] = @"";
          
          NSString *key = @"offMore9";
          NSNumber *countNum = mDict[key];
          int countPlusOne = [countNum intValue] + 1;
          mDict[key] = @(countPlusOne);
        }
      }
    }
  }
  
  NSLog(@"mDict %@", mDict);
  
  // Lossy range conversion means a whole bunch of colors are not an exact match
  
  XCTAssert([mDict[@"exact"] intValue] == 2753772, @"all exact");
  
  return;
}

/*
 
 Apple196 results:
 
 exact =  2753405
 off1  = 13499212
 off2  =   524599
 off3  =        0
 
 sRGB encode/decode results:
 
 exact =  2753772
 off1 =  13893861
 off2 =    129583
 off3 =         0
 
 */

// Given an input sRGB triple in the form (R G B), convert
// to YCbCr based on the BT.709 transform using the
// gamma encoding defined by sRGB gamma curve.

// NW (40 201 53)  -> REC.709 (142 76 59)
// NE (52 195 59)  -> REC.709 (141 80 67)

// SW (214 53 201) -> REC.709 (89 180 197)
// SE (202 58 197) -> REC.709 (90 178 189)

// expr {round((40 + 52 + 214 + 202) / 4.0)} = 127
// expr {round((201 + 195 + 53 + 58) / 4.0)} = 127
// expr {round((53 + 59 + 201 + 197) / 4.0)} = 128

// expr {(142 + 141 + 89 + 90) / 4.0} = 115.5
// expr {(76 + 80 + 180 + 178) / 4.0} = 128.5 -> 129
// expr {(59 + 67 + 197 + 189) / 4.0} = 128.0

- (void)testConvertsSRGBToYCbCr_ResampleUpperNW {
  // sRGB (40 201 53) -> REC.709 (142 76 59)
  
  int Rin = 40;
  int Gin = 201;
  int Bin = 53;
  
  int Y, Cb, Cr;
  int applyGammaMap = 1;
  
  int result;
  
  result = BT709_from_sRGB_convertRGBToYCbCr(Rin, Gin, Bin, &Y, &Cb, &Cr, 1);
  XCTAssert(result == 0);
  
  {
    int v = Y;
    int expectedVal = 142;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cb;
    int expectedVal = 76;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 59;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int R, G, B;
  result = BT709_to_sRGB_convertYCbCrToRGB(Y, Cb, Cr, &R, &G, &B, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = R;
    int expectedVal = Rin - 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = G;
    int expectedVal = Gin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = B;
    int expectedVal = Bin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
}

- (void)testConvertsSRGBToYCbCr_ResampleUpperNE {
  // sRGB (52 195 59) -> REC.709 (141 80 67)
  
  int Rin = 52;
  int Gin = 195;
  int Bin = 59;
  
  int Y, Cb, Cr;
  int applyGammaMap = 1;
  
  int result;
  
  result = BT709_from_sRGB_convertRGBToYCbCr(Rin, Gin, Bin, &Y, &Cb, &Cr, 1);
  XCTAssert(result == 0);
  
  {
    int v = Y;
    int expectedVal = 141;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cb;
    int expectedVal = 80;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 67;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int R, G, B;
  result = BT709_to_sRGB_convertYCbCrToRGB(Y, Cb, Cr, &R, &G, &B, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = R;
    int expectedVal = Rin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = G;
    int expectedVal = Gin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = B;
    int expectedVal = Bin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
}

- (void)testConvertsSRGBToYCbCr_ResampleUpperSW {
  // sRGB (214 53 201) -> REC.709 (89 180 197)
  
  int Rin = 214;
  int Gin = 53;
  int Bin = 201;
  
  int Y, Cb, Cr;
  int applyGammaMap = 1;
  
  int result;
  
  result = BT709_from_sRGB_convertRGBToYCbCr(Rin, Gin, Bin, &Y, &Cb, &Cr, 1);
  XCTAssert(result == 0);
  
  {
    int v = Y;
    int expectedVal = 89;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cb;
    int expectedVal = 180;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 197;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int R, G, B;
  result = BT709_to_sRGB_convertYCbCrToRGB(Y, Cb, Cr, &R, &G, &B, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = R;
    int expectedVal = Rin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = G;
    int expectedVal = Gin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = B;
    int expectedVal = Bin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
}

- (void)testConvertsSRGBToYCbCr_ResampleUpperSE {
  // sRGB (202 58 197) -> REC.709 (90 178 189)
  
  int Rin = 202;
  int Gin = 58;
  int Bin = 197;
  
  int Y, Cb, Cr;
  int applyGammaMap = 1;
  
  int result;
  
  result = BT709_from_sRGB_convertRGBToYCbCr(Rin, Gin, Bin, &Y, &Cb, &Cr, 1);
  XCTAssert(result == 0);
  
  {
    int v = Y;
    int expectedVal = 90;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cb;
    int expectedVal = 178;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 189;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int R, G, B;
  result = BT709_to_sRGB_convertYCbCrToRGB(Y, Cb, Cr, &R, &G, &B, applyGammaMap);
  XCTAssert(result == 0);
  
  {
    int v = R;
    int expectedVal = Rin;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = G;
    int expectedVal = Gin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = B;
    int expectedVal = Bin + 1;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
}

// Convert RGB to linear YCbCr and back to RGB to ensure
// that the conversion ranges are correct.

- (void)testConvertsSRGBToYCbCr_LinearRanges50Per {
  // 50% linear intensity in all 3 components
  
  int R, G, B;
  float Y, Cb, Cr;
  
  R = round(sRGB_linearNormToNonLinear(0.5) * 255.0f);
  G = R;
  B = R;
  
  sRGB_ycbcr_tolinearNorm(R, G, B, &Y, &Cb, &Cr);
  
  int Yint = (int) round(Y * 100.0);
  int Cbint = (int) round(Cb * 100.0);
  int Crint = (int) round(Cr * 100.0);
  
  {
    int v = Yint;
    int expectedVal = 50;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cbint;
    int expectedVal = 0;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Crint;
    int expectedVal = 0;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  // Convert YCbCr back to RGB
  
  float decRn, decGn, decBn;
  
  int result = BT709_convertNormalizedYCbCrToRGB(Y, Cb, Cr, &decRn, &decGn, &decBn, 0);
  XCTAssert(result == 0, @"BT709_convertNormalizedYCbCrToRGB result");
  
  // Check linear result before passing back through sRGB gamma
  
  {
    int v = decRn * 100.0f;
    int expectedVal = 50;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decGn * 100.0f;
    int expectedVal = 50;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decBn * 100.0f;
    int expectedVal = 50;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int decR = BT709_from_linear(decRn, BT709GammaSrgb);
  int decG = BT709_from_linear(decGn, BT709GammaSrgb);
  int decB = BT709_from_linear(decBn, BT709GammaSrgb);
  
  {
    int v = decR;
    int expectedVal = R;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }

  {
    int v = decG;
    int expectedVal = G;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }

  {
    int v = decB;
    int expectedVal = B;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }

}

- (void)testConvertsSRGBToYCbCr_LinearRanges50PerRed {
  // 50% linear intensity in R component
  
  int R, G, B;
  float Y, Cb, Cr;
  
  R = round(sRGB_linearNormToNonLinear(0.5) * 255.0f);
  G = 0;
  B = 0;
  
  sRGB_ycbcr_tolinearNorm(R, G, B, &Y, &Cb, &Cr);
  
  int Yint = (int) round(Y * 100.0);
  int Cbint = (int) round(Cb * 100.0);
  int Crint = (int) round(Cr * 100.0);
  
  {
    int v = Yint;
    int expectedVal = 11;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cbint;
    int expectedVal = -6;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Crint;
    int expectedVal = 25;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  // Convert YCbCr back to RGB
  
  float decRn, decGn, decBn;
  
  int result = BT709_convertNormalizedYCbCrToRGB(Y, Cb, Cr, &decRn, &decGn, &decBn, 0);
  XCTAssert(result == 0, @"BT709_convertNormalizedYCbCrToRGB result");
  
  // Check linear result before passing back through sRGB gamma
  
  {
    int v = decRn * 100.0f;
    int expectedVal = 50;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decGn * 100.0f;
    int expectedVal = 0;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decBn * 100.0f;
    int expectedVal = 0;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int decR = BT709_from_linear(decRn, BT709GammaSrgb);
  int decG = BT709_from_linear(decGn, BT709GammaSrgb);
  int decB = BT709_from_linear(decBn, BT709GammaSrgb);

  {
    int v = decR;
    int expectedVal = R;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decG;
    int expectedVal = G;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decB;
    int expectedVal = B;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
}

- (void)testConvertsSRGBToYCbCr_LinearRanges50PerBlue {
  // 50% linear intensity in B component
  
  int R, G, B;
  float Y, Cb, Cr;
  
  R = 0;
  G = 0;
  B = round(sRGB_linearNormToNonLinear(0.5) * 255.0f);
  
  sRGB_ycbcr_tolinearNorm(R, G, B, &Y, &Cb, &Cr);
  
  int Yint = (int) round(Y * 100.0);
  int Cbint = (int) round(Cb * 100.0);
  int Crint = (int) round(Cr * 100.0);
  
  {
    int v = Yint;
    int expectedVal = 4;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cbint;
    int expectedVal = 25;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Crint;
    int expectedVal = -2;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  // Convert YCbCr back to RGB
  
  float decRn, decGn, decBn;
  
  int result = BT709_convertNormalizedYCbCrToRGB(Y, Cb, Cr, &decRn, &decGn, &decBn, 0);
  XCTAssert(result == 0, @"BT709_convertNormalizedYCbCrToRGB result");
  
  // Check linear result before passing back through sRGB gamma
  
  {
    int v = decRn * 100.0f;
    int expectedVal = 0;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decGn * 100.0f;
    int expectedVal = 0;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decBn * 100.0f;
    int expectedVal = 50;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int decR = BT709_from_linear(decRn, BT709GammaSrgb);
  int decG = BT709_from_linear(decGn, BT709GammaSrgb);
  int decB = BT709_from_linear(decBn, BT709GammaSrgb);
  
  {
    int v = decR;
    int expectedVal = R;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decG;
    int expectedVal = G;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decB;
    int expectedVal = B;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
}

- (void)testConvertsSRGBToYCbCr_LinearRanges50PerBR {
  // 50% linear intensity in B and R component
  
  int R, G, B;
  float Y, Cb, Cr;
  
  G = 0;
  R = B = round(sRGB_linearNormToNonLinear(0.5) * 255.0f);
  
  sRGB_ycbcr_tolinearNorm(R, G, B, &Y, &Cb, &Cr);
  
  int Yint = (int) round(Y * 100.0);
  int Cbint = (int) round(Cb * 100.0);
  int Crint = (int) round(Cr * 100.0);
  
  {
    int v = Yint;
    int expectedVal = 14;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cbint;
    int expectedVal = 19;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Crint;
    int expectedVal = 23;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  // Convert YCbCr back to RGB
  
  float decRn, decGn, decBn;
  
  int result = BT709_convertNormalizedYCbCrToRGB(Y, Cb, Cr, &decRn, &decGn, &decBn, 0);
  XCTAssert(result == 0, @"BT709_convertNormalizedYCbCrToRGB result");
  
  // Check linear result before passing back through sRGB gamma
  
  {
    int v = decRn * 100.0f;
    int expectedVal = 50;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decGn * 100.0f;
    int expectedVal = 0;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decBn * 100.0f;
    int expectedVal = 50;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  int decR = BT709_from_linear(decRn, BT709GammaSrgb);
  int decG = BT709_from_linear(decGn, BT709GammaSrgb);
  int decB = BT709_from_linear(decBn, BT709GammaSrgb);
  
  {
    int v = decR;
    int expectedVal = R;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decG;
    int expectedVal = G;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = decB;
    int expectedVal = B;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
}

// Generate linear average that takes gamma into account

- (void)testConvertsSRGBToYCbCr_AverageOf4_t1_sRGB {
  // NW (40 201 53)  -> REC.709 with sRGB (150 79 63)
  // NE (52 195 59)  -> REC.709 with sRGB (149 83 71)
  
  // SW (214 53 201) -> REC.709 with sRGB (100 177 193)
  // SE (202 58 197) -> REC.709 with sRGB (101 175 186)
  
  int R1 = 40;
  int G1 = 201;
  int B1 = 53;
  
  int R2 = 52;
  int G2 = 195;
  int B2 = 59;
  
  int R3 = 214;
  int G3 = 53;
  int B3 = 201;
  
  int R4 = 202;
  int G4 = 58;
  int B4 = 197;
  
  int Y1, Y2, Y3, Y4;
  int Cb, Cr;
  
  const BT709Gamma inputGamma = BT709GammaSrgb;
  const BT709Gamma outputGamma = BT709GammaSrgb;

  BT709_average_pixel_values(R1, G1, B1,
                             R2, G2, B2,
                             R3, G3, B3,
                             R4, G4, B4,
                             &Y1, &Y2, &Y3, &Y4,
                             &Cb, &Cr,
                             inputGamma, outputGamma);

  // Expected output?
  // (R G B) (155 149 150)
  
  // Got (84 77 78)
  // (Y Cb Cr) (? 128 131)
  
  // Need to search Y values to find each Y1, Y2, Y3, Y4
  // that is closest to the original pixel given a fixed
  // Cb and Cr.
  
  // Output:
  
//  minDelta 0.57 : Y = 61 : p3 0.04 0.03 0.03
//  sRGB  58  51  52
//  minDelta 0.52 : Y = 67 : p3 0.05 0.04 0.04
//  sRGB  65  58  59
//  minDelta 0.59 : Y = 189 : p3 0.62 0.58 0.59
//  sRGB 207 200 201
//  minDelta 0.51 : Y = 185 : p3 0.59 0.55 0.56
//  sRGB 202 195 197
//  Y1 Y2 Y3 Y4 :  61  67 189 185

  // (Y Cb Cr)
  // (145 128 129) (143 128 128)
  // ( 95 128 129) ( 95 128 128)
  
  {
    int v = Y1;
    int expectedVal = 150;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y2;
    int expectedVal = 149;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y3;
    int expectedVal = 100;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y4;
    int expectedVal = 101;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  // Ave Cb Cr
  
  {
    int v = Cb;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 131;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
}

- (void)testConvertsSRGBToYCbCr_AverageOf4_t1_Apple {
  // NW (40 201 53)  -> REC.709 with sRGB (150 79 63)
  // NE (52 195 59)  -> REC.709 with sRGB (149 83 71)
  
  // SW (214 53 201) -> REC.709 with sRGB (100 177 193)
  // SE (202 58 197) -> REC.709 with sRGB (101 175 186)
  
  int R1 = 40;
  int G1 = 201;
  int B1 = 53;
  
  int R2 = 52;
  int G2 = 195;
  int B2 = 59;
  
  int R3 = 214;
  int G3 = 53;
  int B3 = 201;
  
  int R4 = 202;
  int G4 = 58;
  int B4 = 197;
  
  int Y1, Y2, Y3, Y4;
  int Cb, Cr;
  
  const BT709Gamma inputGamma = BT709GammaSrgb;
  const BT709Gamma outputGamma = BT709GammaApple;
  
  BT709_average_pixel_values(R1, G1, B1,
                             R2, G2, B2,
                             R3, G3, B3,
                             R4, G4, B4,
                             &Y1, &Y2, &Y3, &Y4,
                             &Cb, &Cr,
                             inputGamma, outputGamma);
  
  {
    int v = Y1;
    int expectedVal = 145;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y2;
    int expectedVal = 142;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y3;
    int expectedVal = 95;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y4;
    int expectedVal = 95;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  // Ave Cb Cr
  
  {
    int v = Cb;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 131;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
}

- (void)testConvertsSRGBToYCbCr_AverageOf4_t1_Linear {
  // NW (40 201 53)  -> REC.709 with sRGB (150 79 63)
  // NE (52 195 59)  -> REC.709 with sRGB (149 83 71)
  
  // SW (214 53 201) -> REC.709 with sRGB (100 177 193)
  // SE (202 58 197) -> REC.709 with sRGB (101 175 186)
  
  int R1 = 40;
  int G1 = 201;
  int B1 = 53;
  
  int R2 = 52;
  int G2 = 195;
  int B2 = 59;
  
  int R3 = 214;
  int G3 = 53;
  int B3 = 201;
  
  int R4 = 202;
  int G4 = 58;
  int B4 = 197;
  
  int Y1, Y2, Y3, Y4;
  int Cb, Cr;
  
  const BT709Gamma inputGamma = BT709GammaSrgb;
  const BT709Gamma outputGamma = BT709GammaLinear;
  
  BT709_average_pixel_values(R1, G1, B1,
                             R2, G2, B2,
                             R3, G3, B3,
                             R4, G4, B4,
                             &Y1, &Y2, &Y3, &Y4,
                             &Cb, &Cr,
                             inputGamma, outputGamma);
  
  {
    int v = Y1;
    int expectedVal = 109;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y2;
    int expectedVal = 104;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y3;
    int expectedVal = 62;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y4;
    int expectedVal = 59;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  // Ave Cb Cr
  
  {
    int v = Cb;
    int expectedVal = 128;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 131;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
}

// Generate linear average that takes gamma into account

- (void)testConvertsSRGBToYCbCr_AverageOf4_t2 {
  // NW (8 210 54)   -> REC.709 (150 80 46)
  // NE (6 214 51)   -> REC.709 (152 77 43)
  
  // SW (247 45 201) -> REC.709 (101 176 210)
  // SE (248 40 203) -> REC.709 (98 179 213)
  
  int R1 = 8;
  int G1 = 210;
  int B1 = 54;
  
  int R2 = 6;
  int G2 = 214;
  int B2 = 51;
  
  int R3 = 247;
  int G3 = 45;
  int B3 = 201;
  
  int R4 = 248;
  int G4 = 40;
  int B4 = 203;
  
  int Y1, Y2, Y3, Y4;
  int Cb, Cr;
  
  const BT709Gamma inputGamma = BT709GammaSrgb;
  const BT709Gamma outputGamma = BT709GammaSrgb;
  
  BT709_average_pixel_values(R1, G1, B1,
                             R2, G2, B2,
                             R3, G3, B3,
                             R4, G4, B4,
                             &Y1, &Y2, &Y3, &Y4,
                             &Cb, &Cr,
                             inputGamma, outputGamma);
  
  {
    int v = Y1;
    int expectedVal = 150; // not 16
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y2;
    int expectedVal = 152; // not 16
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y3;
    int expectedVal = 101;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y4;
    int expectedVal = 98;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  // Ave Cb Cr
  
  {
    int v = Cb;
    int expectedVal = 123;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 139;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
}

- (void)testConvertsSRGBToYCbCr_AverageOf4_t3 {
  // NW (10 204 66)  -> REC.709 (147 87 48)
  // NE (14 201 70)  -> REC.709 (146 89 51)
  
  // SW (244 51 186) -> REC.709 (103 168 207)
  // SE (240 54 183) -> REC.709 ()
  
  int R1 = 10;
  int G1 = 204;
  int B1 = 66;
  
  int R2 = 14;
  int G2 = 201;
  int B2 = 70;
  
  int R3 = 244;
  int G3 = 51;
  int B3 = 186;
  
  int R4 = 240;
  int G4 = 54;
  int B4 = 183;
  
  int Y1, Y2, Y3, Y4;
  int Cb, Cr;
  
  const BT709Gamma inputGamma = BT709GammaSrgb;
  const BT709Gamma outputGamma = BT709GammaSrgb;
  
  BT709_average_pixel_values(R1, G1, B1,
                             R2, G2, B2,
                             R3, G3, B3,
                             R4, G4, B4,
                             &Y1, &Y2, &Y3, &Y4,
                             &Cb, &Cr,
                             inputGamma, outputGamma);
  
  {
    int v = Y1;
    int expectedVal = 147;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y2;
    int expectedVal = 146;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y3;
    int expectedVal = 103;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Y4;
    int expectedVal = 104;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  // Ave Cb Cr
  
  {
    int v = Cb;
    int expectedVal = 121;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
  {
    int v = Cr;
    int expectedVal = 140;
    XCTAssert(v == expectedVal, @"%3d != %3d", v, expectedVal);
  }
  
}

@end
