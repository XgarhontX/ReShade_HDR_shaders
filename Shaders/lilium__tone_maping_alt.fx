#include "lilium__include/include_main.fxh"


#if (defined(IS_HDR_CSP))

#ifndef TONEMAP_TYPE
  #define TONEMAP_TYPE 2
#endif
#if TONEMAP_TYPE == 0
  #define TONEMAP_TYPE_STRING " - Type (0/3): Reinhard (Gradual)"
#elif  TONEMAP_TYPE == 1
  #define TONEMAP_TYPE_STRING " - Type (1/3): Exponential Rolloff (Aggressive)"
#elif  TONEMAP_TYPE == 2
  #define TONEMAP_TYPE_STRING " - Type (2/3): Hermite Spline (Scalable)"
#elif  TONEMAP_TYPE == 3
  #define TONEMAP_TYPE_STRING " - Type (2/3): NeuTwo"
#else 
  #define TONEMAP_TYPE_STRING " - Type (?/3): Error"
#endif

#ifndef TONEMAP_MODE
  #define TONEMAP_MODE 1
#endif
#if TONEMAP_MODE == 0
  #define TONEMAP_MODE_STRING " - Mode (0/1): Per-Channel"
#elif TONEMAP_MODE == 1
  #define TONEMAP_MODE_STRING " - Mode (1/1): Luminance"
#else 
  #define TONEMAP_MODE_STRING " - Mode (?/1): Error"
#endif

#ifndef TONEMAP_COLORSPACE
  #define TONEMAP_COLORSPACE 0
#endif
#if TONEMAP_COLORSPACE == 0
  #define TONEMAP_COLORSPACE_STRING " - Color Space (0/2): BT709"
#elif TONEMAP_COLORSPACE == 1
  #define TONEMAP_COLORSPACE_STRING " - Color Space (1/2): DCI-P3"
#elif TONEMAP_COLORSPACE == 2
  #define TONEMAP_COLORSPACE_STRING " - Color Space (2/2): BT2020"
#else 
  #define TONEMAP_COLORSPACE_STRING " - Color Space (?/2): Error"
#endif

#ifndef TONEMAP_CLAMP
  #define TONEMAP_CLAMP 0
#endif
#if TONEMAP_CLAMP == 0
  #define TONEMAP_CLAMP_STRING " - Color Space Clamp (0/1): Clamp"
#elif  TONEMAP_CLAMP == 1
  #define TONEMAP_CLAMP_STRING " - Color Space Clamp (1/1): Mirror (Preserve but weird?)"
#else 
  #define TONEMAP_CLAMP_STRING " - Color Space Clamp (?/1): Error"
#endif

uniform float ToneMapPeak <
    // ui_type = "slider";
    ui_category = "Tone Map";
    ui_label = "Peak";
    ui_tooltip = "Set to your display max.";
    ui_min = 203;
    ui_max = 4000;
    ui_step = 1;
> = 1000;

#if TONEMAP_TYPE == 0 || TONEMAP_TYPE == 1
  uniform float ToneMapShoulder <
      ui_type = "slider";
      ui_category = "Tone Map";
      ui_label = "Shoulder Start";
      ui_tooltip = "When should the shoulder/roll-off begin?";
      ui_min = 1;
      ui_max = 500;
      ui_step = 1;
  > = 36;
  #define TONEMAP_PARAMS_SHOULDER
#endif

#if TONEMAP_TYPE == 0 || TONEMAP_TYPE == 2
  uniform float ToneMapWhiteMax <
      ui_type = "drag";
      ui_category = "Tone Map";
      ui_label = "Expected Max";
      ui_tooltip = "Expected max for the tonemapper.\nReduce to white clip.";
      ui_min = 100;
      ui_max = 1000000;
      ui_step = 1;
  > = 10000;
  #define TONEMAP_PARAMS_WHITEMAX
#endif

#if TONEMAP_MODE == 1
  uniform bool IsMaxChannelScaleDown
  <
    ui_category = "Tone Map";
    ui_label    = "MaxCLL Scale Down";
    ui_type     = "combo";
    ui_items    = "Off\0"
                  "On\0";
    ui_tooltip = "There is peak overshoot by scaling from luma.\nThis will scale down those overshoot while retaining it's saturation,\nthough it may be unnatural.";
  > = 0;
#else
  #define IsMaxChannelScaleDown false
#endif

uniform float ToneMapExposure <
    ui_type = "slider";
    ui_category = "Tone Map";
    ui_label = "Exposure";
    ui_tooltip = "Just a multiplier on color before tonemapping.";
    ui_min = 0;
    ui_max = 3;
    ui_step = 0.001;
> = 1;

uniform int GLOBAL_INFO_3
<
  ui_category = "Tone Map Info";
  ui_label    = " ";
  ui_type     = "radio";
  ui_text     = TONEMAP_CLAMP_STRING;
  nosave      = true;
>;
uniform int GLOBAL_INFO_2
<
  ui_category = "Tone Map Info";
  ui_label    = " ";
  ui_type     = "radio";
  ui_text     = TONEMAP_COLORSPACE_STRING;
  nosave      = true;
>;
uniform int GLOBAL_INFO_1
<
  ui_category = "Tone Map Info";
  ui_label    = " ";
  ui_type     = "radio";
  ui_text     = TONEMAP_MODE_STRING;
  nosave      = true;
>;
uniform int GLOBAL_INFO_0
<
  ui_category = "Tone Map Info";
  ui_label    = " ";
  ui_type     = "radio";
  ui_text     = TONEMAP_TYPE_STRING;
  nosave      = true;
>;

///////////////////////////////////////////////////////////////////////////////////
float SafeDivision(float a, float b, float f = 0) { return b != 0.f ? a / b : f; }
float3 Sign_UltraFast(float3 x) { return asfloat((asuint(x) & 0x80000000u) | 0x3F800000u); }
float Rescale(float x, float x_min, float x_max, float y_min = 0, float y_max = 1, bool clamp = false) {
  float value = lerp(y_min, y_max, (x - x_min) / (x_max - x_min));
  if (clamp) value = saturate(value);
  return value;
}

float Rescale(float x, float x_min, float x_max, bool clamp) {
  return Rescale(x, x_min, x_max, 0.f, 1.f, clamp);
}

float3 Rescale(float3 x, float3 x_min, float3 x_max, float3 y_min = float3(0, 0, 0), float3 y_max = float3(1, 1, 1), bool clamp = false) {
  float3 value = lerp(y_min, y_max, (x - x_min) / (x_max - x_min));
  if (clamp) value = saturate(value);
  return value;
}

float3 Rescale(float3 x, float3 x_min, float3 x_max, bool clamp) {
  return Rescale(x, x_min, x_max, float3(0, 0, 0), float3(1, 1, 1), clamp);
}

bool IsWorkingBT2020() {
  #ifdef IS_HDR10_LIKE_CSP
    return true;
  #else
    #if TONEMAP_COLORSPACE == 0
      return false;
    #else
      return true;
    #endif
  #endif
}

float GetLuminanceWorking(float3 x) {
  #if TONEMAP_COLORSPACE == 0
    return dot(x, Csp::Mat::BT709_To_XYZ[1]);
  #elif TONEMAP_COLORSPACE == 1
     return dot(x, Csp::Mat::DCIP3_To_XYZ[1]);
  #elif TONEMAP_COLORSPACE == 2
    return dot(x, Csp::Mat::BT2020_To_XYZ[1]);
  #endif
}

// float MapInto(float x) {
//   #if IS_HDR10_LIKE_CSP
//     return dot(x, Csp::Mat::BT2020_To_XYZ[1]);
//   #endif
// 
//   if (!isBT2020) dot(x, Csp::Mat::BT709_To_XYZ[1]);
//   return dot(x, Csp::Mat::BT2020_To_XYZ[1]);
// }

float3 MaxChannelScaleDown(float3 x, float p) {
	float m = max(x.x, max(x.y, x.z));
	if (m > p) x *= p / m;
	return x;
}

///////////////////////////////////////////////////////////////////////////////////
//HDR Tonemaps: https://github.com/clshortfuse/renodx/tree/main/src/shaders/tonemap

namespace Reinhard {
  float ComputeReinhardExtendableScale(float w, float p, float m, float x, float y) {
    return p * (w * w * y - (p * x * x)) / (w * w * x * (p - y));
  }

  float ReinhardSimple(float x, float peak = 1.0)
  {
    return x / ((x / peak) + 1.0);
  }
  float3 ReinhardSimple(float3 x, float peak = 1.0)
  {
    return x / ((x / peak) + 1.0);
  }

  float ReinhardExtended(float color, float white_max, float peak) {
    return ReinhardSimple(color, peak) * (1.f + (peak * color) / (white_max * white_max));
  }
  float3 ReinhardExtended(float3 color, float white_max, float peak) {
    return ReinhardSimple(color, peak) * (1.f + (peak * color) / (white_max * white_max));
  }

  float ReinhardPiecewiseExtended(float x, float white_max, float x_max = 1.f, float shoulder = 0.18f)
  {
    const float x_min = 0.f;
    float exposure = ComputeReinhardExtendableScale(white_max, x_max, x_min, shoulder, shoulder);
    float extended = ReinhardExtended(x * exposure, white_max * exposure, x_max);
    extended = min(extended, x_max);

    return lerp(x, extended, step(shoulder, x));
  }
  float3 ReinhardPiecewiseExtended(float3 x, float white_max, float x_max = 1.f, float shoulder = 0.18f)
  {
    const float x_min = 0.f;
    float exposure = ComputeReinhardExtendableScale(white_max, x_max, x_min, shoulder, shoulder);
    float3 extended = ReinhardExtended(x * exposure, white_max * exposure, x_max);
    extended = min(extended, x_max);

    return lerp(x, extended, step(shoulder, x));
  }
}

namespace ExpRoll {
  float ExponentialRollOff(float input, float rolloff_start, float output_max) { 
    float rolloff_size = (output_max - rolloff_start);
    float overage = -max((0), input - rolloff_start);
    float rolloff_value = (1.0f) - exp(overage / rolloff_size);     
    float new_overage = rolloff_size * rolloff_value + overage;
    return input + new_overage;
  }

  float3 ExponentialRollOff(float3 input, float rolloff_start, float output_max) { 
    float3 rolloff_size = (output_max - rolloff_start);
    float3 overage = -max((0), input - rolloff_start);
    float3 rolloff_value = (1.0f) - exp(overage / rolloff_size);     
    float3 new_overage = rolloff_size * rolloff_value + overage;
    return input + new_overage;
  }
}

namespace HermiteSpline {
  float HermiteSplineRolloff(float input, float target_white = 1.f, float max_white = 20.f) {
    float l_w = max_white;
    // float l_b = min_black;
    // float l_min = target_black;
    float l_max = target_white;
    float e_1 = Rescale(input, 0, l_w);
    // float min_lum = Rescale(l_min, l_b, l_w);
    float max_lum = Rescale(l_max, 0, l_w);
    float knee_start = 1.5f * max_lum - 0.5f;
    // float b = min_lum;
    float t_b = Rescale(e_1, knee_start, 1.f);

    // float p_e1 = (((2 * t_b * t_b * t_b) - (3 * t_b * t_b) + 1) * knee_start)
    //              + (((t_b * t_b * t_b) - (2 * t_b * t_b) + t_b) * (1.f - knee_start))
    //              + ((-(2 * t_b * t_b * t_b) + (3 * t_b * t_b)) * max_lum);
    float t_b_squared = t_b * t_b;
    float t_b_cubed = t_b_squared * t_b;
    float two_t_b_cubed = 2.f * t_b_cubed;
    float three_t_b_squared = 3.f * t_b_squared;
    float p_e1_h00 = (two_t_b_cubed - three_t_b_squared + 1.f);
    float p_e1_h10 = (t_b_cubed - 2.f * t_b_squared + t_b);
    float p_e1_h01 = (-two_t_b_cubed + three_t_b_squared);
    // float p_e1_h11 = (t_b_cubed - t_b_squared); // Not used since derivative is 0 at max_lum

    float p_e1 = p_e1_h00 * knee_start
                 + p_e1_h10 * (1.f - knee_start)
                 + p_e1_h01 * max_lum;

    float e_2 = (e_1 < knee_start) ? e_1 : p_e1;

    // float e_3 = e_2 + b * pow(1-e_2, 4);
    // float e_3a1 = (1 - e_2) * (1 - e_2);
    // float e_3a2 = e_3a1 * (1 - e_2);
    float e_3 = e_2;

    // Custom: clamp before lerp
    // e_3 = saturate(e_3);

    // float e_4 = lerp(l_b, l_w, e_3);
    float e_4 = l_w * e_3;

    return min(e_4, target_white);
  }

  // Hermite Spline Rolloff
  // Must be normalized between 0-1
  // https://www.itu.int/dms_pub/itu-r/opb/rep/R-REP-BT.2408-8-2024-PDF-E.pdf
  float HermiteSplineRolloff(
      float input,
      float target_white,
      float max_white,
      float target_black,
      float min_black = 0.f) {
    float l_w = max_white;
    float l_b = min_black;
    float l_min = target_black;
    float l_max = target_white;
    float e_1 = Rescale(input, l_b, l_w);
    float min_lum = Rescale(l_min, l_b, l_w);
    float max_lum = Rescale(l_max, l_b, l_w);
    float knee_start = 1.5f * max_lum - 0.5f;
    float b = min_lum;
    float t_b = Rescale(e_1, knee_start, 1.f);

    // float p_e1 = (((2 * t_b * t_b * t_b) - (3 * t_b * t_b) + 1) * knee_start)
    //              + (((t_b * t_b * t_b) - (2 * t_b * t_b) + t_b) * (1.f - knee_start))
    //              + ((-(2 * t_b * t_b * t_b) + (3 * t_b * t_b)) * max_lum);
    float t_b_squared = t_b * t_b;
    float t_b_cubed = t_b_squared * t_b;
    float two_t_b_cubed = 2.f * t_b_cubed;
    float three_t_b_squared = 3.f * t_b_squared;
    float p_e1_h00 = (two_t_b_cubed - three_t_b_squared + 1.f);
    float p_e1_h10 = (t_b_cubed - 2.f * t_b_squared + t_b);
    float p_e1_h01 = (-two_t_b_cubed + three_t_b_squared);
    // float p_e1_h11 = (t_b_cubed - t_b_squared); // Not used since derivative is 0 at max_lum

    float p_e1 = p_e1_h00 * knee_start
                 + p_e1_h10 * (1.f - knee_start)
                 + p_e1_h01 * max_lum;

    float e_2 = (e_1 < knee_start) ? e_1 : p_e1;

    // float e_3 = e_2 + b * pow(1-e_2, 4);
    float e_3a1 = (1 - e_2) * (1 - e_2);
    float e_3a2 = e_3a1 * (1 - e_2);
    float e_3 = e_2 + (b * e_3a2);

    // Custom: clamp before lerp
    e_3 = saturate(e_3);

    float e_4 = lerp(l_b, l_w, e_3);
    return e_4;
  }

  float HermiteSplineRolloffCool(float luminance, float target_white = 1.f, float max_white = 20.f) {
   if (luminance == 0) return 0;
   return exp2(HermiteSplineRolloff(log2(luminance), log2(target_white), log2(max_white)));
  }

  float3 HermiteSplineRolloffCool(float3 input, float target_white = 1.f, float max_white = 20.f) {
    float target_white_log2 = log2(target_white);
    float max_white_log2 = log2(max_white);
    float3 scaled = float3(
        input.r == 0 ? 0 : exp2(HermiteSplineRolloff(log2(input.r), target_white_log2, max_white_log2)),
        input.g == 0 ? 0 : exp2(HermiteSplineRolloff(log2(input.g), target_white_log2, max_white_log2)),
        input.b == 0 ? 0 : exp2(HermiteSplineRolloff(log2(input.b), target_white_log2, max_white_log2)));
    return scaled;
  }
} 

namespace NeuTwo {
  /*
   * Copyright (C) 2026 Carlos Lopez
   * SPDX-License-Identifier: MIT
   */
  // Neutral tonemap
  // Based on power of 2 (squared/sqrt)
  // Naka-Rushton/Reinhard style tonemapper x/(x^2+k)^(1/2)
  // Newton-Raphson friendly with rsqrt (faster than division)
  // f'''(x) = 0 at x = 0.5 (half peak)
  // https://www.desmos.com/calculator/gy1edro6nd
  // Polar/Cartesian form of peak * cos(atan2(x, peak))
  // Invertible with same complexity as forward

  // f_{p}\left(x\right)=\frac{px}{\sqrt{xx+pp}}
  float3 NeuTwo(float3 x, float peak) {
    // also written as x * rhypot(x, peak)
    float p = peak;

    float3 numerator = p * x;
    float3 denominator_squared = mad(x, x, p * p);
    return numerator * rsqrt(denominator_squared);
  }
  float NeuTwo(float x, float peak) {
    // also written as x * rhypot(x, peak)
    float p = peak;

    float numerator = p * x;
    float denominator_squared = mad(x, x, p * p);
    return numerator * rsqrt(denominator_squared);
  }
}


///////////////////////////////////////////////////////////////////////////////////

float3 Tonemap(float3 x) {
  
  const float peak = ToneMapPeak / 80.; //TODO: HDR10
  #ifdef TONEMAP_PARAMS_SHOULDER
    const float shoulder = ToneMapShoulder / 80.;
  #endif
  #ifdef TONEMAP_PARAMS_WHITEMAX
    const float whitemax = ToneMapWhiteMax / 80.;
  #endif

  #if TONEMAP_CLAMP == 0
    x = max(0, x);
  #else
    float3 s = Sign_UltraFast(x);
    x = abs(x);
  #endif

  #if TONEMAP_MODE == 0 
    float3 xT = x;
  #else
    float xT = GetLuminanceWorking(x);
    if (xT <= 0) return x;
    float xTOrig = xT;
  #endif

  #if TONEMAP_TYPE == 0
    xT = Reinhard::ReinhardPiecewiseExtended(xT, whitemax, peak, shoulder);
  #elif TONEMAP_TYPE == 1
    xT = ExpRoll::ExponentialRollOff(xT, shoulder, peak);
  #elif TONEMAP_TYPE == 2
    xT = HermiteSpline::HermiteSplineRolloffCool(xT, peak, whitemax);
  #elif TONEMAP_TYPE == 3
    xT = NeuTwo::NeuTwo(xT, peak);
  #endif

  #if TONEMAP_MODE == 0 
    x = xT;
  #else
    x *= xT / xTOrig;
    if (IsMaxChannelScaleDown > 0) x = MaxChannelScaleDown(x, peak);
  #endif

  #if TONEMAP_CLAMP > 0
    x *= s;
  #endif

  return x;
}

float4 PS_Main(in float4 Position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target0 {
	float4 color = tex2Dfetch(SamplerBackBuffer, int2(Position.xy));
	float3 x = color.xyz;
	
  #if !defined(IS_HDR10_LIKE_CSP)
    #if TONEMAP_COLORSPACE == 0
      //noop
    #elif TONEMAP_COLORSPACE == 1
      x = Csp::Mat::BT709_To::DCIP3(x);
    #elif TONEMAP_COLORSPACE == 2
      x = Csp::Mat::BT709_To::BT2020(x);
    #endif
  #else
    WIP;
  #endif

  x *= ToneMapExposure;
  x = Tonemap(x);

  #if !defined(IS_HDR10_LIKE_CSP)
    #if TONEMAP_COLORSPACE == 0
      //noop
    #elif TONEMAP_COLORSPACE == 1
      x = Csp::Mat::DCIP3_To::BT709(x);
    #elif TONEMAP_COLORSPACE == 2
      x = Csp::Mat::BT2020_To::BT709(x);
    #endif
  #else 
    WIP;
  #endif

	return float4(x, color.a);
}

technique lilium__RenoDX_ColorGrading 
<
  ui_label = "Lilium's Tone Mapping RenoDX (scRGB)";
>
{
	pass Final {
		VertexShader = VS_PostProcess; //default
		PixelShader = PS_Main;
	}
}

#else //(defined(IS_ANALYSIS_CAPABLE_API) && ((ACTUAL_COLOUR_SPACE == CSP_SCRGB || ACTUAL_COLOUR_SPACE == CSP_HDR10) || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)))

ERROR_STUFF

technique lilium__RenoDX_ColorGrading
<
  ui_label = "Lilium's Tone Mapping RenoDX (scRGB) (ERROR)";
>
VS_ERROR

#endif //(defined(IS_ANALYSIS_CAPABLE_API) && ((ACTUAL_COLOUR_SPACE == CSP_SCRGB || ACTUAL_COLOUR_SPACE == CSP_HDR10) || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)))
