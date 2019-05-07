//
//  BT709.h
//
//  Created by Moses DeJong on 12/14/18.
//
//  Header only interface to mapping from from linear RGB to BT.709,
//  from sRGB to BT.709, and vice versa.
//
//  https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.709-6-201506-I!!PDF-E.pdf
//  https://forums.creativecow.net/thread/2/1131717
//  https://www.khronos.org/registry/DataFormat/specs/1.2/dataformat.1.2.html#TRANSFER_ITU
//
//  See license.txt for license terms.

#include "sRGB.h"

#if !defined(_BT709_H)
#define _BT709_H

typedef enum
{
  BT709GammaSrgb = 1,
  BT709GammaApple = 2,
  BT709GammaLinear = 3
} BT709Gamma;

// BT.601 constants

// Kr, Kg, Kb (601)

//const float Kr = 0.299f;
//const float Kg = 0.587f;
//const float Kb = 0.114f;
//
//const float Er_minus_Ey_Range = 0.701f * 2.0f; // 1.402 : aka 2*(1.0 - Kr)
//const float Eb_minus_Ey_Range = 0.886f * 2.0f; // 1.772 : aka 2*(1.0 - Kb)

// Kr, Kg, Kb (709)

const static float BT709_Kr = 0.2126f;
const static float BT709_Kg = 0.7152f;
const static float BT709_Kb = 0.0722f;

const static float BT709_Er_minus_Ey_Range = 1.5748f; // 2*(1.0 - Kr)
const static float BT709_Eb_minus_Ey_Range = 1.8556f; // 2*(1.0 - Kb)

//const static float Er_minus_Ey_Range = (2.0f * (1.0f - Kr));
//const static float Eb_minus_Ey_Range = (2.0f * (1.0f - Kb));

// Generic

const static float BT709_Kr_over_Kg = BT709_Kr / BT709_Kg;
const static float BT709_Kb_over_Kg = BT709_Kb / BT709_Kg;

const static int BT709_YMin =  16;
const static int BT709_YMax = 235;

const static int BT709_UVMin =  16;
const static int BT709_UVMax = 240;

// BT.709

// Convert a non-linear log value to a linear value.
// Note that normV must be normalized in the range [0.0 1.0].
// Note that converting from non-linear to linear
// with a form like pow(x, Gamma) will reduce the signal strength.

static inline
float BT709_nonLinearNormToLinear(float normV) {
  
  if (normV < 0.081f) {
    normV *= (1.0f / 4.5f);
  } else {
    const float a = 0.099f;
    const float gamma = 1.0f / 0.45f;
    normV = (normV + a) * (1.0f / (1.0f + a));
    normV = pow(normV, gamma);
  }
  
  return normV;
}

// ((v + 0.099) / 1.099) ^ 1.961

// Convert a linear log value to a non-linear value.
// Note that normV must be normalized in the range [0.0 1.0]
// Note that converting from linear to non-linear
// with a form like pow(x, 1/Gamma) will boost the signal up.

static inline
float BT709_linearNormToNonLinear(float normV) {
  
  if (normV < 0.018f) {
    normV *= 4.5f;
  } else {
    // This 0.45 constant rounds better than (1.0f / 2.2f)
    const float a = 0.099f;
    const float gamma = 0.45f;
    normV = (1.0f + a) * pow(normV, gamma) - a;
  }
  
  return normV;
}

// Apple ColorSync defined gamma 1.961 combined with a straight line
// with a slope of 16 (aka 0.0625) intersects at (0.00349, 0.05584)

// [gamma a b c d e f]
//
// Curve Type 3 : Y = (aX+b)^gamma     [X >= d],     Y = cX [X < d]
//
// "com.apple.cmm.ParamCurve3" = (
//                                       "1.960938", // gamma
//                                       1, // a
//                                       0, // b
//                                       "0.0625", // c
//                                       "0.05583828", // d
//                                       0, // e
//                                       0 // f
//                                       );

//#define APPLE_GAMMA_196 (1.961f)
#define APPLE_GAMMA_196 (1.960938f)

static inline
float Apple196_nonLinearNormToLinear(float normV) {
  const float xIntercept = 0.05583828f;
  
  if (normV < xIntercept) {
    normV *= (1.0f / 16.0f);
  } else {
    const float gamma = APPLE_GAMMA_196;
    normV = pow(normV, gamma);
  }
  
  return normV;
}

static inline
float Apple196_linearNormToNonLinear(float normV) {
  const float yIntercept = 0.00349f;
  
  if (normV < yIntercept) {
    normV *= 16.0f;
  } else {
    const float gamma = 1.0f / APPLE_GAMMA_196;
    normV = pow(normV, gamma);
  }
  
  return normV;
}

// Decode Gamma encoding to a byte value that is already normalized.
// A decode converts from non-linear to linear.

static inline
int BT709_decodeGamma(int v, int minv, int maxv) {
#if defined(DEBUG)
  assert(v >= minv);
  assert(v <= maxv);
#endif // DEBUG
  v = v - minv;
  
  float normV = v / (float) (maxv - minv);
  
  normV = BT709_nonLinearNormToLinear(normV);
  
  int rInt = round(normV * (maxv - minv));
  rInt += minv;
  return rInt;
}

// Add Gamma encoding on a byte value that is already normalized

static inline
int BT709_encodeGamma(int v, int minv, int maxv) {
#if defined(DEBUG)
  assert(v >= minv);
  assert(v <= maxv);
#endif // DEBUG
  v = v - minv;
  
  float normV = v / (float) (maxv - minv);
  
  normV = BT709_linearNormToNonLinear(normV);
  
  int rInt = round(normV * (maxv - minv));
  rInt += minv;
  return rInt;
}

// Given a non-linear gamma encoded and normalized value,
// pass through Y Cb Cr conversion matrix and generate
// integer representations of the components. Note that
// it is also possible that this method can be invoked
// with a linear value that is not gamma encoded, for
// example when an alpha channel is encoded.

static inline
int BT709_convertNonLinearRGBToYCbCr(
                                  float Rn,
                                  float Gn,
                                  float Bn,
                                  int *YPtr,
                                  int *CbPtr,
                                  int *CrPtr)
{
  const int debug = 0;
  
#if defined(DEBUG)
  assert(YPtr);
  assert(CbPtr);
  assert(CrPtr);
#endif // DEBUG
  
  if (debug) {
    printf("Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    printf("R G B in byte range : %.4f %.4f %.4f\n", Rn*255.0f, Gn*255.0f, Bn*255.0f);
  }
  
  // https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.709-6-201506-I!!PDF-E.pdf
  
  float Ey = (BT709_Kr * Rn) + (BT709_Kg * Gn) + (BT709_Kb * Bn);
  float Eb = (Bn - Ey) / BT709_Eb_minus_Ey_Range;
  float Er = (Rn - Ey) / BT709_Er_minus_Ey_Range;
  
  if (debug) {
    printf("Ey Eb Er : %.4f %.4f %.4f\n", Ey, Eb, Er);
  }
  
  // Quant Y to range [16, 235] (inclusive 219 values)
  // Quant Eb, Er to range [16, 240] (inclusive 224 values, centered at 128)
  
  float AdjEy = (Ey * (BT709_YMax-BT709_YMin)) + 16;
  float AdjEb = (Eb * (BT709_UVMax-BT709_UVMin)) + 128;
  float AdjEr = (Er * (BT709_UVMax-BT709_UVMin)) + 128;
  
  if (debug) {
    printf("unrounded:\n");
    printf("Ey Eb Er : %.4f %.4f %.4f\n", AdjEy, AdjEb, AdjEr);
  }
  
  // Round to nearest int value
  
  int Y = (int) round(AdjEy);
  int Cb = (int) round(AdjEb);
  int Cr = (int) round(AdjEr);
  
#if defined(DEBUG)
  assert(Y >= BT709_YMin);
  assert(Y <= BT709_YMax);
  
  assert(Cb >= BT709_UVMin);
  assert(Cb <= BT709_UVMax);
  
  assert(Cr >= BT709_UVMin);
  assert(Cr <= BT709_UVMax);
#endif // DEBUG
  
  *YPtr = Y;
  *CbPtr = Cb;
  *CrPtr = Cr;
  
  if (debug) {
    printf("Y Cb Cr : %3d %3d %3d\n", Y, Cb, Cr);
  }
  
  return 0;
}

// Given a normalized linear RGB pixel value, convert to BT.709
// YCbCr log colorspace. This method assumes Alpha = 255, the
// gamma flag makes it possible to return Y without a gamma
// adjustment.

static inline
int BT709_convertLinearRGBToYCbCr(
                            float Rn,
                            float Gn,
                            float Bn,
                            int *YPtr,
                            int *CbPtr,
                            int *CrPtr,
                            int applyGammaMap)
{
  const int debug = 0;
  
#if defined(DEBUG)
  assert(YPtr);
  assert(CbPtr);
  assert(CrPtr);
#endif // DEBUG
  
  if (debug) {
    printf("Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    printf("R G B in byte range : %.4f %.4f %.4f\n", Rn*255.0f, Gn*255.0f, Bn*255.0f);
  }

  // Gamma adjustment to non-linear value
  
  if (applyGammaMap) {
    
    if (debug) {
      printf("pre  to non-linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    }
    
    // Always encode using BT.709 defined curve.
    // Apple may decode with a slightly different curve.
    
    Rn = BT709_linearNormToNonLinear(Rn);
    Gn = BT709_linearNormToNonLinear(Gn);
    Bn = BT709_linearNormToNonLinear(Bn);
    
    if (debug) {
      printf("post to non-linear Rn Gn Bn : %.4f %.4f %.4f : percent %3d %3d %3d\n", Rn, Gn, Bn, (int)(Rn*100.0f), (int)(Gn*100.0f), (int)(Bn*100.0f));
      printf("R G B in byte range : %.4f %.4f %.4f\n", Rn*255.0f, Gn*255.0f, Bn*255.0f);
    }
  }
  
  int result = BT709_convertNonLinearRGBToYCbCr(Rn, Gn, Bn, YPtr, CbPtr, CrPtr);
  return result;
}

// Previous API, only used in test cases

static inline
int BT709_convertRGBToYCbCr(
                                    int R,
                                    int G,
                                    int B,
                                    int *YPtr,
                                    int *CbPtr,
                                    int *CrPtr,
                                    int applyGammaMap)
{
  float Rn = byteNorm(R);
  float Gn = byteNorm(G);
  float Bn = byteNorm(B);
  
  return BT709_convertLinearRGBToYCbCr(Rn, Gn, Bn, YPtr, CbPtr, CrPtr, applyGammaMap);
}

// Given YCbCr values (Can be non-linear or linear), convert to RGB, note
// that this method assumes the caller will deal with converting non-linear
// output back to linear values (if non-linear). The returned R,G,B vlaues
// are normalized.

static inline
int BT709_convertNormalizedYCbCrToRGB(
                                      float Yn,
                                      float Cbn,
                                      float Crn,
                                      float *RPtr,
                                      float *GPtr,
                                      float *BPtr,
                                      const int unscale)
{
  const int debug = 0;
  
  // BT.601
  //
  // 1.164,  0.000, 1.596
  // 1.164, -0.392, -0.813
  // 1.164,  2.017, 0.000
  
  // BT.709 (HDTV)
  // (col0) (col1) (col2)
  // 1.164  0.000  1.793
  // 1.164 -0.213 -0.533
  // 1.164  2.112  0.000
  
  // Col 0 : range of Y and UV values
  //
  // [0] : 1.164 : YScale
  // [1] : 1.164 : YScale
  // [2] : 1.164 : YScale
  
  // Col 1 :
  // [0] : 0.0 (No Cb input)
  // [1] : -1 * UVScale * Eb_minus_Ey_Range * Kb_over_Kg
  // [2] : UVScale * Eb_minus_Ey_Range
  
  // Col 2 : Cr
  //
  // [0] : UVScale * Er_minus_Ey_Range
  // [1] : -1 * UVScale * Er_minus_Ey_Range * Kr_over_Kg
  // [2] : 0.0
  
  const float YScale = 255.0f / (unscale ? (BT709_YMax-BT709_YMin) : 255.0f);
  const float UVScale = 255.0f / (unscale ? (BT709_UVMax-BT709_UVMin) : 255.0f);
  
  const
  float BT709Mat[] = {
    YScale,   0.000f,  (UVScale * BT709_Er_minus_Ey_Range),
    YScale, (-1.0f * UVScale * BT709_Eb_minus_Ey_Range * BT709_Kb_over_Kg),  (-1.0f * UVScale * BT709_Er_minus_Ey_Range * BT709_Kr_over_Kg),
    YScale, (UVScale * BT709_Eb_minus_Ey_Range),  0.000f,
  };
  
  if (debug) {
    printf("Mat 3x3:\n");
    printf("%.8f %.8f %.8f\n", BT709Mat[0], BT709Mat[1], BT709Mat[2]);
    printf("%.8f %.8f %.8f\n", BT709Mat[3], BT709Mat[4], BT709Mat[5]);
    printf("%.8f %.8f %.8f\n", BT709Mat[6], BT709Mat[7], BT709Mat[8]);
  }
  
  // Matrix multiply operation
  //
  // rgb = BT709Mat * YCbCr
  
  if (debug) {
    // Print the normalized Y value before dealing with colors in the Mat
    
    float Yscaled = (Yn * BT709Mat[0]);
    
    printf("Yscaled %.8f\n", Yscaled);
    
    float YscaledByte = Yscaled * 255.0f;
    
    printf("Yscaled in byte range %.4f\n", YscaledByte);
  }
  
  // Convert input Y, Cb, Cr to normalized float values
  
  float Rn = (Yn * BT709Mat[0]) + (Cbn * BT709Mat[1]) + (Crn * BT709Mat[2]);
  float Gn = (Yn * BT709Mat[3]) + (Cbn * BT709Mat[4]) + (Crn * BT709Mat[5]);
  float Bn = (Yn * BT709Mat[6]) + (Cbn * BT709Mat[7]) + (Crn * BT709Mat[8]);
  
  if (debug) {
    printf("RGB Matrix intermediates:\n");
    printf("%.8f %.8f %.8f\n", (Yn * BT709Mat[0]), (Cbn * BT709Mat[1]), (Crn * BT709Mat[2]));
    printf("%.8f %.8f %.8f\n", (Yn * BT709Mat[3]), (Cbn * BT709Mat[4]), (Crn * BT709Mat[5]));
    printf("%.8f %.8f %.8f\n", (Yn * BT709Mat[6]), (Cbn * BT709Mat[7]), (Crn * BT709Mat[8]));
  }
  
  if (debug) {
    printf("unclamped:\n");
    printf("Rn %.8f\n", Rn);
    printf("Gn %.8f\n", Gn);
    printf("Bn %.8f\n", Bn);
  }
  
  // Saturate normalized linear (R G B) to range [0.0, 1.0]
  
  Rn = saturatef(Rn);
  Gn = saturatef(Gn);
  Bn = saturatef(Bn);
  
  if (debug) {
    printf("clamped:\n");
    printf("Rn %.8f\n", Rn);
    printf("Gn %.8f\n", Gn);
    printf("Bn %.8f\n", Bn);
  }
  
  *RPtr = Rn;
  *GPtr = Gn;
  *BPtr = Bn;
  
  return 0;
}

// Given a YCbCr input stored as an integer, apply the
// BT.709 matrix conversion step and return a non-linear
// result (result is still gamma adjusted) as a normalzied value.

static inline
int BT709_convertYCbCrToNonLinearRGB(
                                  int Y,
                                  int Cb,
                                  int Cr,
                                  float *RPtr,
                                  float *GPtr,
                                  float *BPtr)
{
  const int debug = 0;

#if defined(DEBUG)
  assert(RPtr);
  assert(GPtr);
  assert(BPtr);

  assert(BT709_YMin <= Y && Y <= BT709_YMax);
#endif // DEBUG

  // https://en.wikipedia.org/wiki/YCbCr#ITU-R_BT.709_conversion
  // http://www.niwa.nu/2013/05/understanding-yuv-values/

  // Normalize Y to range [0 255]
  //
  // Note that the matrix multiply will adjust
  // this byte normalized range to account for
  // the limited range [16 235]

  float Yn = (Y - 16) * (1.0f / 255.0f);

  // Normalize Cb and CR with zero at 128 and range [0 255]
  // Note that matrix will adjust to limited range [16 240]

  float Cbn = (Cb - 128) * (1.0f / 255.0f);
  float Crn = (Cr - 128) * (1.0f / 255.0f);

  if (debug) {
    printf("zerod normalized Yn Cbn Crn : %.8f %.8f %.8f\n", Yn, Cbn, Crn);

    int Yint = round(Yn * 255.0f);
    int Cbint = round(Cbn * 255.0f);
    int Crint = round(Crn * 255.0f);

    printf("as byte range Y Cb Cr : %3d %3d %3d\n", Yint, Cbint, Crint);
  }

  return BT709_convertNormalizedYCbCrToRGB(Yn, Cbn, Crn, RPtr, GPtr, BPtr, 1);
}

// Convert from BT.709 YCbCr to linear RGB as a normalized float

static inline
int BT709_convertYCbCrToLinearRGB(
                             int Y,
                             int Cb,
                             int Cr,
                             float *RPtr,
                             float *GPtr,
                             float *BPtr,
                             int applyGammaMap)
{
  const int debug = 0;
  
  BT709_convertYCbCrToNonLinearRGB(Y, Cb, Cr, RPtr, GPtr, BPtr);
  
  float Rn = *RPtr;
  float Gn = *GPtr;
  float Bn = *BPtr;
  
  // Gamma adjustment for RGB components after matrix transform
  
  if (applyGammaMap) {
    if (debug) {
      printf("pre  to linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    }
    
    Rn = BT709_nonLinearNormToLinear(Rn);
    Gn = BT709_nonLinearNormToLinear(Gn);
    Bn = BT709_nonLinearNormToLinear(Bn);
    
    if (debug) {
      printf("post to linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    }
  }
  
  *RPtr = Rn;
  *GPtr = Gn;
  *BPtr = Bn;
  
  return 0;
}

static inline
int BT709_convertYCbCrToRGB(
                            int Y,
                            int Cb,
                            int Cr,
                            int *RIntPtr,
                            int *GIntPtr,
                            int *BIntPtr,
                            int applyGammaMap)
{
  const int debug = 0;
  
  float Rn;
  float Gn;
  float Bn;
  
  BT709_convertYCbCrToLinearRGB(Y, Cb, Cr, &Rn, &Gn, &Bn, applyGammaMap);
  
  // Round to nearest int value in range [0, 255]
  
  int R = (int) round(Rn * 255.0f);
  int G = (int) round(Gn * 255.0f);
  int B = (int) round(Bn * 255.0f);
  
  if (debug) {
    printf("scaled up to byte range:\n");
    printf("R %.4f\n", Rn * 255.0f);
    printf("G %.4f\n", Gn * 255.0f);
    printf("B %.4f\n", Bn * 255.0f);
    
    printf("rounded to int:\n");
    printf("R %3d\n", R);
    printf("G %3d\n", G);
    printf("B %3d\n", B);
  }
  
#if defined(DEBUG)
  assert(R >= 0 && R <= 255);
  assert(G >= 0 && G <= 255);
  assert(B >= 0 && B <= 255);
#endif // DEBUG
  
  *RIntPtr = R;
  *GIntPtr = G;
  *BIntPtr = B;
  
  return 0;
}

// Convert sRGB directly to BT.709 by first converting
// to linear RGB and then to YCbCr.

static inline
int BT709_from_sRGB_convertRGBToYCbCr(
                                    int R,
                                    int G,
                                    int B,
                                    int *YPtr,
                                    int *CbPtr,
                                    int *CrPtr,
                                    int applyGammaMap)
{
  const int debug = 0;
  
#if defined(DEBUG)
  assert(YPtr);
  assert(CbPtr);
  assert(CrPtr);
  
  assert(R >= 0 && R <= 255);
  assert(G >= 0 && G <= 255);
  assert(B >= 0 && B <= 255);
#endif // DEBUG
  
  if (debug) {
    printf("sRGB in : R G B : %3d %3d %3d\n", R, G, B);
  }
  
  // Intermediate rep must use float to avoid dark precision loss
  // https://blog.demofox.org/2018/03/10/dont-convert-srgb-u8-to-linear-u8/
  
  float Rn = byteNorm(R);
  float Gn = byteNorm(G);
  float Bn = byteNorm(B);
  
  // Convert non-linear sRGB to linear
  
  if (applyGammaMap) {
    if (debug) {
      printf("pre  to linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
      
      printf("byte range     Rn Gn Bn : %.4f %.4f %.4f\n", Rn*255.0f, Gn*255.0f, Bn*255.0f);
    }
    
    Rn = sRGB_nonLinearNormToLinear(Rn);
    Gn = sRGB_nonLinearNormToLinear(Gn);
    Bn = sRGB_nonLinearNormToLinear(Bn);
    
    if (debug) {
      printf("post to linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
      
      printf("byte range     Rn Gn Bn : %.4f %.4f %.4f\n", Rn*255.0f, Gn*255.0f, Bn*255.0f);
    }
  }
  
  return BT709_convertLinearRGBToYCbCr(Rn, Gn, Bn, YPtr, CbPtr, CrPtr, applyGammaMap);
}

// Convert BT.709 to sRGB in non-linear space

static inline
int BT709_to_sRGB_convertYCbCrToRGB(
                                    int Y,
                                    int Cb,
                                    int Cr,
                                    int *RPtr,
                                    int *GPtr,
                                    int *BPtr,
                                    int applyGammaMap)
{
  const int debug = 0;
  
#if defined(DEBUG)
  assert(RPtr);
  assert(GPtr);
  assert(BPtr);
#endif // DEBUG
  
  if (debug) {
    printf("Y Cb Cr : %3d %3d %3d\n", Y, Cb, Cr);
  }
  
  float Rn, Gn, Bn;
  BT709_convertYCbCrToLinearRGB(Y, Cb, Cr, &Rn, &Gn, &Bn, applyGammaMap);
  
  // Convert linear RGB to non-linear sRGB

  if (applyGammaMap) {
    if (debug) {
      printf("pre  to non-linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    }
    
    Rn = sRGB_linearNormToNonLinear(Rn);
    Gn = sRGB_linearNormToNonLinear(Gn);
    Bn = sRGB_linearNormToNonLinear(Bn);
    
    if (debug) {
      printf("post to non-linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    }
  }
  
  // Write RGB values as int in byte range [0 255]
  
  int R = (int) round(Rn * 255.0f);
  int G = (int) round(Gn * 255.0f);
  int B = (int) round(Bn * 255.0f);
  
  if (debug) {
    printf("scaled up to byte range:\n");
    printf("R %.4f\n", Rn * 255.0f);
    printf("G %.4f\n", Gn * 255.0f);
    printf("B %.4f\n", Bn * 255.0f);
    
    printf("rounded to int:\n");
    printf("R %3d\n", R);
    printf("G %3d\n", G);
    printf("B %3d\n", B);
  }
  
#if defined(DEBUG)
  assert(R >= 0 && R <= 255);
  assert(G >= 0 && G <= 255);
  assert(B >= 0 && B <= 255);
#endif // DEBUG
  
  *RPtr = R;
  *GPtr = G;
  *BPtr = B;
  
  return 0;
}

// Apple specific gamma encoding curve from sRGB to 1.96
// like encoding that can be exactly inverted with CoreVideo.

static inline
int Apple196_from_sRGB_convertRGBToYCbCr(
                                      int R,
                                      int G,
                                      int B,
                                      int *YPtr,
                                      int *CbPtr,
                                      int *CrPtr)
{
  const int debug = 0;
  
#if defined(DEBUG)
  assert(YPtr);
  assert(CbPtr);
  assert(CrPtr);
  
  assert(R >= 0 && R <= 255);
  assert(G >= 0 && G <= 255);
  assert(B >= 0 && B <= 255);
#endif // DEBUG
  
  if (debug) {
    printf("sRGB in : R G B : %3d %3d %3d\n", R, G, B);
  }
  
  // Intermediate rep must use float to avoid dark precision loss
  // https://blog.demofox.org/2018/03/10/dont-convert-srgb-u8-to-linear-u8/
  
  float Rn = byteNorm(R);
  float Gn = byteNorm(G);
  float Bn = byteNorm(B);
  
  // Boosted encoding of linear RGB values, encode with an inverse
  // of the Apple decoding gamma so that sRGB values will come out
  // exactly the same as the original inputs when generated from
  // RGB values. This differs from camera recorded video since
  // a dark room boost of 1.2 and the BT.709 encoding are automatically
  // applied in that situation.

  if (1) {
    if (debug) {
      printf("pre  to linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);

      printf("byte range     Rn Gn Bn : %.4f %.4f %.4f\n", Rn*255.0f, Gn*255.0f, Bn*255.0f);
    }

    Rn = sRGB_nonLinearNormToLinear(Rn);
    Gn = sRGB_nonLinearNormToLinear(Gn);
    Bn = sRGB_nonLinearNormToLinear(Bn);

    if (debug) {
      printf("post to linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);

      printf("byte range     Rn Gn Bn : %.4f %.4f %.4f\n", Rn*255.0f, Gn*255.0f, Bn*255.0f);
    }
  }
  
  if (1) {
    if (debug) {
      printf("pre  to non-linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
      printf("byte range     Rn Gn Bn : %.4f %.4f %.4f\n", Rn*255.0f, Gn*255.0f, Bn*255.0f);
    }
    
    Rn = Apple196_linearNormToNonLinear(Rn);
    Gn = Apple196_linearNormToNonLinear(Gn);
    Bn = Apple196_linearNormToNonLinear(Bn);
    
    if (debug) {
      printf("post to non-linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
      printf("byte range     Rn Gn Bn : %.4f %.4f %.4f\n", Rn*255.0f, Gn*255.0f, Bn*255.0f);
    }
  }
  
  return BT709_convertNonLinearRGBToYCbCr(Rn, Gn, Bn, YPtr, CbPtr, CrPtr);
}

// Convert from Apple 1.96 gamma encoded value to sRGB

static inline
int Apple196_to_sRGB_convertYCbCrToRGB(
                                    int Y,
                                    int Cb,
                                    int Cr,
                                    int *RPtr,
                                    int *GPtr,
                                    int *BPtr,
                                    int applyGammaMap)
{
  const int debug = 0;
  
#if defined(DEBUG)
  assert(RPtr);
  assert(GPtr);
  assert(BPtr);
#endif // DEBUG
  
  if (debug) {
    printf("Y Cb Cr : %3d %3d %3d\n", Y, Cb, Cr);
  }
  
  float Rn, Gn, Bn;
    
  BT709_convertYCbCrToNonLinearRGB(Y, Cb, Cr, &Rn, &Gn, &Bn);
  
  // Convert non-linear RGB to linear RGB
  
  if (applyGammaMap) {
    if (debug) {
      printf("pre  to linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    }

    Rn = Apple196_nonLinearNormToLinear(Rn);
    Gn = Apple196_nonLinearNormToLinear(Gn);
    Bn = Apple196_nonLinearNormToLinear(Bn);

    if (debug) {
      printf("post to linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    }
  }

  // Convert linear RGB values to non-linear sRGB
  
  if (applyGammaMap) {
    if (debug) {
      printf("pre  to non-linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    }
    
    Rn = sRGB_linearNormToNonLinear(Rn);
    Gn = sRGB_linearNormToNonLinear(Gn);
    Bn = sRGB_linearNormToNonLinear(Bn);
    
    if (debug) {
      printf("post to non-linear Rn Gn Bn : %.4f %.4f %.4f\n", Rn, Gn, Bn);
    }
  }
  
  // Write RGB values as int in byte range [0 255]
  
  int R = (int) round(Rn * 255.0f);
  int G = (int) round(Gn * 255.0f);
  int B = (int) round(Bn * 255.0f);
  
  if (debug) {
    printf("scaled up to byte range:\n");
    printf("R %.4f\n", Rn * 255.0f);
    printf("G %.4f\n", Gn * 255.0f);
    printf("B %.4f\n", Bn * 255.0f);
    
    printf("rounded to int:\n");
    printf("R %3d\n", R);
    printf("G %3d\n", G);
    printf("B %3d\n", B);
  }
  
#if defined(DEBUG)
  assert(R >= 0 && R <= 255);
  assert(G >= 0 && G <= 255);
  assert(B >= 0 && B <= 255);
#endif // DEBUG
  
  *RPtr = R;
  *GPtr = G;
  *BPtr = B;
  
  return 0;
}

// When input RGB data is already encoded in sRGB colorspace
// then the normalized float values can be passed directly
// into YCbCr matrix transform.

static inline
int sRGB_from_sRGB_convertRGBToYCbCr(
                                         int R,
                                         int G,
                                         int B,
                                         int *YPtr,
                                         int *CbPtr,
                                         int *CrPtr)
{
  const int debug = 0;
  
#if defined(DEBUG)
  assert(YPtr);
  assert(CbPtr);
  assert(CrPtr);
  
  assert(R >= 0 && R <= 255);
  assert(G >= 0 && G <= 255);
  assert(B >= 0 && B <= 255);
#endif // DEBUG
  
  if (debug) {
    printf("sRGB in : R G B : %3d %3d %3d\n", R, G, B);
  }
  
  float Rn = byteNorm(R);
  float Gn = byteNorm(G);
  float Bn = byteNorm(B);
  
  return BT709_convertNonLinearRGBToYCbCr(Rn, Gn, Bn, YPtr, CbPtr, CrPtr);
}

// Convert from YCbCr encoded with sRGB gamma curve back to sRGB

static inline
int sRGB_to_sRGB_convertYCbCrToRGB(
                                       int Y,
                                       int Cb,
                                       int Cr,
                                       int *RPtr,
                                       int *GPtr,
                                       int *BPtr,
                                       int applyGammaMap)
{
  const int debug = 0;
  
#if defined(DEBUG)
  assert(RPtr);
  assert(GPtr);
  assert(BPtr);
#endif // DEBUG
  
  if (debug) {
    printf("Y Cb Cr : %3d %3d %3d\n", Y, Cb, Cr);
  }
  
  float Rn, Gn, Bn;
  
  BT709_convertYCbCrToNonLinearRGB(Y, Cb, Cr, &Rn, &Gn, &Bn);
  
  // Write RGB values as int in byte range [0 255]
  
  int R = (int) round(Rn * 255.0f);
  int G = (int) round(Gn * 255.0f);
  int B = (int) round(Bn * 255.0f);
  
  if (debug) {
    printf("scaled up to byte range:\n");
    printf("R %.4f\n", Rn * 255.0f);
    printf("G %.4f\n", Gn * 255.0f);
    printf("B %.4f\n", Bn * 255.0f);
    
    printf("rounded to int:\n");
    printf("R %3d\n", R);
    printf("G %3d\n", G);
    printf("B %3d\n", B);
  }
  
#if defined(DEBUG)
  assert(R >= 0 && R <= 255);
  assert(G >= 0 && G <= 255);
  assert(B >= 0 && B <= 255);
#endif // DEBUG
  
  *RPtr = R;
  *GPtr = G;
  *BPtr = B;
  
  return 0;
}

// Average 4 linear component values (R G B)
// encoded with sRGB gamma curve.

static inline
int sRGB_Component_average_linear(
                               int C1,
                               int C2,
                               int C3,
                               int C4
                               )
{
#if defined(DEBUG)
  assert(C1 >= 0 && C1 <= 255);
  assert(C2 >= 0 && C2 <= 255);
  assert(C3 >= 0 && C3 <= 255);
  assert(C4 >= 0 && C4 <= 255);
#endif // DEBUG

  float C1n = byteNorm(C1);
  float C2n = byteNorm(C2);
  float C3n = byteNorm(C3);
  float C4n = byteNorm(C4);

  C1n = sRGB_nonLinearNormToLinear(C1n);
  C2n = sRGB_nonLinearNormToLinear(C2n);
  C3n = sRGB_nonLinearNormToLinear(C3n);
  C4n = sRGB_nonLinearNormToLinear(C4n);

  return (int) round((C1n + C2n + C3n + C4n) / 4.0f);
}

// Given a pixel component (R G B), map the pixel value
// into a linear normalized float component and then
// generate YCbCr component portions based on linear
// values as opposed to non-linear (gamma encoded) values.

static inline
void sRGB_ycbcr_tolinearNorm(
                              int R,
                              int G,
                              int B,
                              float *YPtr,
                              float *CbPtr,
                              float *CrPtr
                              )
{
  const BOOL debug = FALSE;

#if defined(DEBUG)
  assert(R >= 0 && R <= 255);
  assert(G >= 0 && G <= 255);
  assert(B >= 0 && B <= 255);
#endif // DEBUG

  if (debug) {
    printf("R G B : %3d %3d %3d\n", R, G, B);
  }

  float Rn = byteNorm(R);
  float Gn = byteNorm(G);
  float Bn = byteNorm(B);

  Rn = sRGB_nonLinearNormToLinear(Rn);
  Gn = sRGB_nonLinearNormToLinear(Gn);
  Bn = sRGB_nonLinearNormToLinear(Bn);

  if (debug) {
    printf("Rn Gn Bn (linear) : %.4f %.4f %.4f\n", Rn, Gn, Bn);
  }

  // Generate YCbCr from linear values, this split generates
  // a Cb and Cr pair that is linear and can be averaged.

  float Yn = (BT709_Kr * Rn) + (BT709_Kg * Gn) + (BT709_Kb * Bn);
  float Cbn = (Bn - Yn) / BT709_Eb_minus_Ey_Range;
  float Crn = (Rn - Yn) / BT709_Er_minus_Ey_Range;

  if (debug) {
    printf("Y Cb Cr : %.4f %.4f %.4f\n", Yn, Cbn, Crn);
    printf("Y Cb Cr percentages : %.4f %.4f %.4f\n", Yn*100.0f, Cbn*100.0f, Crn*100.0f);
    printf("Y Cb Cr byte : %.4f %.4f %.4f\n", Yn*255.0f, Cbn*255.0f, Crn*255.0f);
  }

  *YPtr = Yn;
  *CbPtr = Cbn;
  *CrPtr = Crn;

  return;
}

// Convert sRGB gamma encoded value to linear normalized float value.
// the inputGamma argument indicates the gamma encoding.

static inline
void BT709_tolinearNorm(
                             int R,
                             int G,
                             int B,
                             float *RnPtr,
                             float *GnPtr,
                             float *BnPtr,
                             BT709Gamma inputGamma
                             )
{
  const int debug = 0;

#if defined(DEBUG)
  assert(R >= 0 && R <= 255);
  assert(G >= 0 && G <= 255);
  assert(B >= 0 && B <= 255);
#endif // DEBUG

  if (debug) {
    printf("R G B : %3d %3d %3d\n", R, G, B);
  }

  float Rn = byteNorm(R);
  float Gn = byteNorm(G);
  float Bn = byteNorm(B);

  if (inputGamma == BT709GammaSrgb) {
    Rn = sRGB_nonLinearNormToLinear(Rn);
    Gn = sRGB_nonLinearNormToLinear(Gn);
    Bn = sRGB_nonLinearNormToLinear(Bn);
  } else if (inputGamma == BT709GammaApple) {
    Rn = Apple196_nonLinearNormToLinear(Rn);
    Gn = Apple196_nonLinearNormToLinear(Gn);
    Bn = Apple196_nonLinearNormToLinear(Bn);
  } else if (inputGamma == BT709GammaLinear) {
    // nop
  } else {
    assert(0);
  }

  if (debug) {
    printf("Rn Gn Bn (linear) : %.4f %.4f %.4f\n", Rn, Gn, Bn);
  }

  *RnPtr = Rn;
  *GnPtr = Gn;
  *BnPtr = Bn;

  return;
}

static inline
int BT709_from_linear(float Cn,
                      const BT709Gamma outputGamma)
{
  float nonLinear;

  if (outputGamma == BT709GammaSrgb) {
    nonLinear = sRGB_linearNormToNonLinear(Cn);
  } else if (outputGamma == BT709GammaApple) {
    nonLinear = Apple196_linearNormToNonLinear(Cn);
  } else if (outputGamma == BT709GammaLinear) {
    nonLinear = Cn;
  } else {
    assert(0);
  }

  return (int) round(nonLinear * 255.0f);
}

// Generate average values for 4 linear normalized float
// Cb or Cr values.

static inline
float BT709_average_cbcr_linear(
                              float C1n,
                              float C2n,
                              float C3n,
                              float C4n
                              )
{
  const BOOL debug = FALSE;

  float sum = (C1n + C2n + C3n + C4n);
  float ave = sum / 4.0f;

  if (debug) {
    printf("AVE = %.4f %.4f %.4f %.4f = %.4f\n", C1n, C2n, C3n, C4n, ave);
  }

  return ave;
}

// Given an input sRGB set of 4 pixels, calculate an average
// for each component by converting to linear float values
// and then convert to YCbCr for each pixel. This logic must
// convert to linear before calculating an average so that
// the gamma encoding implicit in sRGB is removed. The
// average operation cannot operate directly on a non-linear
// gamma encoded pixel value.

static inline
void sRGB_from_sRGB_average_cbcr(
                                int *R1,
                                int *G1,
                                int *B1,
                                int *R2,
                                int *G2,
                                int *B2,
                                int *R3,
                                int *G3,
                                int *B3,
                                int *R4,
                                int *G4,
                                int *B4
                                )
{
  const int debug = 0;

#if defined(DEBUG)
  assert(*R1 >= 0 && *R1 <= 255);
  assert(*G1 >= 0 && *G1 <= 255);
  assert(*B1 >= 0 && *B1 <= 255);

  assert(*R2 >= 0 && *R2 <= 255);
  assert(*G2 >= 0 && *G2 <= 255);
  assert(*B2 >= 0 && *B2 <= 255);

  assert(*R3 >= 0 && *R3 <= 255);
  assert(*G3 >= 0 && *G3 <= 255);
  assert(*B3 >= 0 && *B3 <= 255);

  assert(*R4 >= 0 && *R4 <= 255);
  assert(*G4 >= 0 && *G4 <= 255);
  assert(*B4 >= 0 && *B4 <= 255);
#endif // DEBUG

  // Generate YCbCr from linear average of the 4 pixels

  // Y Y
  // Y Y
  //
  // Y+Y+Y+Y / 4 = ave

  float Y1, Cb1, Cr1;
  float Y2, Cb2, Cr2;
  float Y3, Cb3, Cr3;
  float Y4, Cb4, Cr4;

  sRGB_ycbcr_tolinearNorm(*R1, *G1, *B1, &Y1, &Cb1, &Cr1);
  sRGB_ycbcr_tolinearNorm(*R2, *G2, *B2, &Y2, &Cb2, &Cr2);
  sRGB_ycbcr_tolinearNorm(*R3, *G3, *B3, &Y3, &Cb3, &Cr3);
  sRGB_ycbcr_tolinearNorm(*R4, *G4, *B4, &Y4, &Cb4, &Cr4);

  // Generate average for Cb and Cr for the 4 pixels

  float CbAve, CrAve;

  CbAve = BT709_average_cbcr_linear(Cb1, Cb2, Cb3, Cb4);
  CrAve = BT709_average_cbcr_linear(Cr1, Cr2, Cr3, Cr4);

  if (debug) {
    printf("CbAve %.4f\n", CbAve);
    printf("CrAve %.4f\n", CrAve);
  }

  // Map Y Cb Cr back to sRGB values

  float Rn1, Gn1, Bn1;
  float Rn2, Gn2, Bn2;
  float Rn3, Gn3, Bn3;
  float Rn4, Gn4, Bn4;

  int result;

  result = BT709_convertNormalizedYCbCrToRGB(Y1, CbAve, CrAve, &Rn1, &Gn1, &Bn1, 0);
  assert(result == 0);
  result = BT709_convertNormalizedYCbCrToRGB(Y2, CbAve, CrAve, &Rn2, &Gn2, &Bn2, 0);
  assert(result == 0);
  result = BT709_convertNormalizedYCbCrToRGB(Y3, CbAve, CrAve, &Rn3, &Gn3, &Bn3, 0);
  assert(result == 0);
  result = BT709_convertNormalizedYCbCrToRGB(Y4, CbAve, CrAve, &Rn4, &Gn4, &Bn4, 0);
  assert(result == 0);

  // Convert linear RGB values to sRGB and return

  *R1 = BT709_from_linear(Rn1, BT709GammaSrgb);
  *G1 = BT709_from_linear(Gn1, BT709GammaSrgb);
  *B1 = BT709_from_linear(Bn1, BT709GammaSrgb);

  if (debug) {
    printf("R1 G1 B1 : %3d %3d %3d\n", *R1, *G1, *B1);
  }

  *R2 = BT709_from_linear(Rn2, BT709GammaSrgb);
  *G2 = BT709_from_linear(Gn2, BT709GammaSrgb);
  *B2 = BT709_from_linear(Bn2, BT709GammaSrgb);

  if (debug) {
    printf("R2 G2 B2 : %3d %3d %3d\n", *R2, *G2, *B2);
  }

  *R3 = BT709_from_linear(Rn3, BT709GammaSrgb);
  *G3 = BT709_from_linear(Gn3, BT709GammaSrgb);
  *B3 = BT709_from_linear(Bn3, BT709GammaSrgb);

  if (debug) {
    printf("R3 G3 B3 : %3d %3d %3d\n", *R3, *G3, *B3);
  }

  *R4 = BT709_from_linear(Rn4, BT709GammaSrgb);
  *G4 = BT709_from_linear(Gn4, BT709GammaSrgb);
  *B4 = BT709_from_linear(Bn4, BT709GammaSrgb);

  if (debug) {
    printf("R4 G4 B4 : %3d %3d %3d\n", *R4, *G4, *B4);
  }

  return;
}

// Calc pixel delta in 3 Dimensions

typedef struct {
  float R;
  float G;
  float B;
} sRGB_FPix3;

static inline
float fpix3_delta(sRGB_FPix3 origP3, sRGB_FPix3 p3)
{
  const int debug = 0;

  float delta = 0.0f;

  delta += fabs(p3.R - origP3.R);
  delta += fabs(p3.G - origP3.G);
  delta += fabs(p3.B - origP3.B);

  if (debug) {
    printf("RGBForY %.3f %.3f %.3f : %.3f %.3f %.3f\n", p3.R, p3.G, p3.B, origP3.R, origP3.G, origP3.B);
  }

  return delta;
}

// Generate an average of 4 RGB pixel values, this logic
// creates an average of sRGB pixel values as linear values.

static inline
void BT709_average_pixel_values(
                               int R1,
                               int G1,
                               int B1,
                               int R2,
                               int G2,
                               int B2,
                               int R3,
                               int G3,
                               int B3,
                               int R4,
                               int G4,
                               int B4,
                               int *Y1,
                               int *Y2,
                               int *Y3,
                               int *Y4,
                               int *Cb,
                               int *Cr,
                                const BT709Gamma inputGamma,
                                const BT709Gamma outputGamma
                               )
{
  const int debug = 0;

#if defined(DEBUG)
  assert(R1 >= 0 && R1 <= 255);
  assert(G1 >= 0 && G1 <= 255);
  assert(B1 >= 0 && B1 <= 255);

  assert(R2 >= 0 && R2 <= 255);
  assert(G2 >= 0 && G2 <= 255);
  assert(B2 >= 0 && B2 <= 255);

  assert(R3 >= 0 && R3 <= 255);
  assert(G3 >= 0 && G3 <= 255);
  assert(B3 >= 0 && B3 <= 255);

  assert(R4 >= 0 && R4 <= 255);
  assert(G4 >= 0 && G4 <= 255);
  assert(B4 >= 0 && B4 <= 255);
#endif // DEBUG

  float Rn1, Gn1, Bn1;
  float Rn2, Gn2, Bn2;
  float Rn3, Gn3, Bn3;
  float Rn4, Gn4, Bn4;

  // Input can be in sRGB, BT.709, or linear gamma encoding

  BT709_tolinearNorm(R1, G1, B1, &Rn1, &Gn1, &Bn1, inputGamma);
  BT709_tolinearNorm(R2, G2, B2, &Rn2, &Gn2, &Bn2, inputGamma);
  BT709_tolinearNorm(R3, G3, B3, &Rn3, &Gn3, &Bn3, inputGamma);
  BT709_tolinearNorm(R4, G4, B4, &Rn4, &Gn4, &Bn4, inputGamma);

  // Average (R G B) as 4 linear values

  float Rave = BT709_average_cbcr_linear(Rn1, Rn2, Rn3, Rn4);
  float Gave = BT709_average_cbcr_linear(Gn1, Gn2, Gn3, Gn4);
  float Bave = BT709_average_cbcr_linear(Bn1, Bn2, Bn3, Bn4);

  // Map linear RGB values into sRGB so that gamma encoded values
  // are passed through YCbCr matrix to generate average Cb and Cr.

  int RAveGammaEncoded = BT709_from_linear(Rave, outputGamma);
  int GaveGammaEncoded = BT709_from_linear(Gave, outputGamma);
  int BaveGammaEncoded = BT709_from_linear(Bave, outputGamma);

  int Yave, CbAve, CrAve;

  // Note that this YCbCr encoding method works for either gamma encoding

  sRGB_from_sRGB_convertRGBToYCbCr(RAveGammaEncoded, GaveGammaEncoded, BaveGammaEncoded, &Yave, &CbAve, &CrAve);

  int Y1ForCorners[4] = { -1, -1, -1, -1 };

  for (int i = 0; i < 4; i++) {
    int origR, origG, origB;
    float origRn, origGn, origBn;

    int origY, origCb, origCr;

    if (i == 0) {
      origR = R1;
      origG = G1;
      origB = B1;
      origRn = Rn1;
      origGn = Gn1;
      origBn = Bn1;
    } else if (i == 1) {
      origR = R2;
      origG = G2;
      origB = B2;
      origRn = Rn2;
      origGn = Gn2;
      origBn = Bn2;
    } else if (i == 2) {
      origR = R3;
      origG = G3;
      origB = B3;
      origRn = Rn3;
      origGn = Gn3;
      origBn = Bn3;
    } else if (i == 3) {
      origR = R4;
      origG = G4;
      origB = B4;
      origRn = Rn4;
      origGn = Gn4;
      origBn = Bn4;
    } else {
#if defined(DEBUG)
      assert(0);
#endif
    }

    // Encode to output gamma curve and pass through BT.709 matrix transform

    int origRGammaEncoded = BT709_from_linear(origRn, outputGamma);
    int origGGammaEncoded = BT709_from_linear(origGn, outputGamma);
    int origBGammaEncoded = BT709_from_linear(origBn, outputGamma);

    sRGB_from_sRGB_convertRGBToYCbCr(origRGammaEncoded, origGGammaEncoded, origBGammaEncoded, &origY, &origCb, &origCr);

    if (debug) {
      printf("original corner pixel R G B : %3d %3d %3d : per %.2f %.2f %.2f -> -> Y Cb Cr %3d %3d %3d\n", origR, origG, origB, origRn, origGn, origBn, origY, origCb, origCr);
    }

    int minY = origY;

    Y1ForCorners[i] = minY;
  }

  if (debug) {
  printf("Y1 Y2 Y3 Y4 : %3d %3d %3d %3d\n", Y1ForCorners[0], Y1ForCorners[1], Y1ForCorners[2], Y1ForCorners[3]);
  }

  assert(Y1ForCorners[0] != -1);
  assert(Y1ForCorners[1] != -1);
  assert(Y1ForCorners[2] != -1);
  assert(Y1ForCorners[3] != -1);

  // Write sRGB encoded Y Cb Cr back to callers

  *Y1 = Y1ForCorners[0];
  *Y2 = Y1ForCorners[1];
  *Y3 = Y1ForCorners[2];
  *Y4 = Y1ForCorners[3];

  if (debug) {
    printf("Cb Cr : %3d %3d\n", CbAve, CrAve);
  }

  *Cb = CbAve;
  *Cr = CrAve;
}

#endif // _BT709_H
