#include "lilium__include/include_main.fxh"


#if (defined(IS_HDR_CSP))

uniform float ToneMapPeak <
    ui_type = "slider";
    ui_category = "Tone Map";
    ui_label = "Peak";
    ui_min = 203;
    ui_max = 4000;
    ui_step = 1;
> = 1000;
// uniform float ToneMapPaperWhite <
//     ui_type = "slider";
//     ui_category = "Tone Map";
//     ui_label = "Paper White";
//     ui_min = 203;
//     ui_max = 500;
//     ui_step = 1;
// > = 203;
uniform float ToneMapShoulder <
    ui_type = "slider";
    ui_category = "Tone Map";
    ui_label = "Shoulder Start";
    ui_min = 1;
    ui_max = 500;
    ui_step = 1;
> = 36;
uniform float ToneMapWhiteMax <
    ui_type = "slider";
    ui_category = "Tone Map";
    ui_label = "Expected Max";
    ui_min = 1000;
    ui_max = 10000;
    ui_step = 1;
> = 10000;

#ifndef IS_HDR10_LIKE_CSP
uniform int ToneMapWorkingCS
<
  ui_category = "Tone Map";
  ui_label    = "Working Color Space";
  ui_type     = "combo";
  ui_items    = "BT709\0"
                "BT2020\0";
> = 1;
#endif

///////////////////////////////////////////////////////////////////////////////////
float SafeDivision(float a, float b, float f = 0) { return b != 0.f ? a / b : f; }
///////////////////////////////////////////////////////////////////////////////////
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

///////////////////////////////////////////////////////////////////////////////////

float4 PS_Main(in float4 Position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target0 {
	float4 color = tex2Dfetch(SamplerBackBuffer, int2(Position.xy));
  float3 x = color.xyz;

  #ifndef IS_HDR10_LIKE_CSP
    if (ToneMapWorkingCS == 1) x = Csp::Mat::BT709_To::BT2020(x);
  #endif

  const float peak = ToneMapPeak / 80.; //TODO HDR10
  const float shoulder = ToneMapShoulder / 80.; //TODO HDR10

  x = Reinhard::ReinhardPiecewiseExtended(x, ToneMapWhiteMax / 80., peak, shoulder);

  #ifndef IS_HDR10_LIKE_CSP
    if (ToneMapWorkingCS == 1) x = Csp::Mat::BT2020_To::BT709(x);
  #endif

	return float4(x, color.a);
}

technique lilium__RenoDX_ColorGrading 
<
  ui_label = "Lilium's Tone Mapping Alt. (scRGB)";
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
  ui_label = "Lilium's Tone Mapping Alt. (scRGB) (ERROR)";
>
VS_ERROR

#endif //(defined(IS_ANALYSIS_CAPABLE_API) && ((ACTUAL_COLOUR_SPACE == CSP_SCRGB || ACTUAL_COLOUR_SPACE == CSP_HDR10) || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)))
