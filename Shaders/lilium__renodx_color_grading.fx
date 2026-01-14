// #include "Reshade.fxh"
// #include "ReShadeUI.fxh"
#include "lilium__include/colour_space.fxh"

#if (defined(IS_HDR_CSP))

#ifndef COMPILE_CONTRAST
#define COMPILE_CONTRAST 1
#endif

#ifndef COMPILE_HIGHLIGHTS
#define COMPILE_HIGHLIGHTS 1
#endif

#ifndef COMPILE_SHADOWS
#define COMPILE_SHADOWS 1
#endif

#ifndef COMPILE_SATURATION
#define COMPILE_SATURATION 1
#endif

#if COMPILE_CONTRAST > 0
uniform float CGContrast <
    ui_type = "slider";
    ui_category = "Color Grade";
    ui_label = "Contrast";
    ui_min = 0.7;
    ui_max = 1.3;
    ui_step = 0.001f;
> = 1;
uniform float CGContrastMidGray <
    ui_type = "slider";
    ui_category = "Color Grade";
    ui_label = "Contrast Mid Gray";
    ui_min = 0;
    ui_max = 1;
    ui_step = 0.001f;
> = 0.5;
#else
const static float CGContrast = 1.f;
const static float CGContrastMidGray = 1.f;
#endif

#if COMPILE_HIGHLIGHTS > 0
uniform float CGHighlightsStrength <
    ui_type = "slider";
    ui_category = "Color Grade";
    ui_label = "Highlights";
    ui_min = 0.7;
    ui_max = 1.3;
    ui_step = 0.001f;
> = 1;
uniform float CGHighlightsMidGray <
    ui_type = "slider";
    ui_category = "Color Grade";
    ui_label = "Highlights Mid Gray";
    ui_min = 0;
    ui_max = 1;
    ui_step = 0.001f;
> = 0.35;
#else
const static float CGHighlightsStrength = 1.f;
const static float CGHighlightsMidGray = 1.f;
#endif

#if COMPILE_SHADOWS > 0
uniform float CGShadowsStrength <
    ui_type = "slider";
    ui_category = "Color Grade";
    ui_label = "Shadows";
    ui_min = 0.0f;
    ui_max = 2.0f;
    ui_step = 0.001f;
> = 1;
uniform float CGShadowsMidGray <
    ui_type = "slider";
    ui_category = "Color Grade";
    ui_label = "Shadows Mid Gray";
    ui_min = 0;
    ui_max = 1;
    ui_step = 0.001f;
> = 0.35;
#else
const static float CGShadowsStrength = 1.f;
const static float CGShadowsMidGray = 1.f;
#endif

#if COMPILE_SATURATION
uniform float CGSaturation <
    ui_type = "slider";
    ui_category = "Color Grade";
    ui_label = "Saturation";
    ui_min = 0;
    ui_max = 2;
    ui_step = 0.001f;
> = 1;
#else
const static float CGSaturation = 1.f;
#endif


///////////////////////////////////////////////////////////////////////////////////
float SafeDivision(float a, float b, float f = 0) { return b != 0.f ? a / b : f; }
///////////////////////////////////////////////////////////////////////////////////
//https://github.com/clshortfuse/renodx/blob/main/src/shaders/colorgrade.hlsl

float RenoDX_Contrast(float x, float contrast, float mid_gray = 0.18f) {
  return pow(max(0, x / mid_gray), contrast) * mid_gray;
}
float3 RenoDX_Contrast(float3 x, float contrast, float mid_gray = 0.18f) {
  return pow(max(0, x / mid_gray), contrast) * mid_gray;
}
float RenoDX_Shadows(float x, float shadows, float mid_gray) {
  float value;
  // if (shadows > 1.f) {
  //   value = max(x, x * (1.f + (x * mid_gray / pow(x / mid_gray, shadows))));
  // } else if (shadows < 1.f) {
  //   value = clamp(x * (1.f - (x * mid_gray / pow(x / mid_gray, 2.f - shadows))), 0.f , x);
  // } else {
  //   value = x;
  // }
        float scaled = x / mid_gray;
    float shadowed = pow(scaled, -1.f * (shadows - 2.f));
    float lerped = lerp(shadowed, scaled, saturate(shadowed));
    float rescaled = lerped * mid_gray;
    value = rescaled;
  return value;
}
float RenoDX_Highlights(float x, float highlights, float mid_gray) {
  float value;
  if (highlights > 1.f) {
    value = max(x, lerp(x, mid_gray * pow(x / mid_gray, highlights), x));
  } else if (highlights < 1.f) {
    value = min(x, x / (1.f + mid_gray * pow(x / mid_gray, 2.f - highlights) - x));
  } else {
    value = x;
  }
  return value;
}

float3 Saturation(float3 x, float sat) {
  #ifndef IS_HDR10_LIKE_CSP
    x = Csp::OkLab::Bt709To::OkLab(x);
  #else
    x = Csp::OkLab::Bt2020To::OkLab(x);
  #endif

  x.yz *= sat;

  #ifndef IS_HDR10_LIKE_CSP
    x = Csp::OkLab::OkLabTo::Bt709(x);
  #else
    x = Csp::OkLab::OkLabTo::Bt2020(x);
  #endif

  return x;
}

float3 RenoDX_ColorGrade(
  float3 x, 
  float contrast = 1, float contrast_mid = 0.18f,
  float highlights = 1, float highlights_mid = 0.18f,
  float shadows = 1, float shadows_mid = 0.18f,
  float saturation = 1
) {
  float l = GetLuminance(x);
  float lOrig = l;

  // Contrast
  l = RenoDX_Contrast(l, contrast, contrast_mid);
  
  // Highlights
  l = RenoDX_Highlights(l, highlights, highlights_mid);

  // Shadows
  l = RenoDX_Shadows(l, shadows, shadows_mid);

  l = max(l, 0);
  x *= SafeDivision(l, lOrig, 0);

  // Saturation
  x = Saturation(x, saturation);

  return x;
}

float4 PS_Main(in float4 Position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target0 {
	float4 color = tex2Dfetch(SamplerBackBuffer, int2(Position.xy));

  //Color Grade
  color.xyz = RenoDX_ColorGrade(
    color.xyz,
    CGContrast, CGContrastMidGray,
    CGHighlightsStrength, CGHighlightsMidGray,
    CGShadowsStrength, CGShadowsMidGray,
    CGSaturation
  );

	return color;
}

// // Vertex shader generating a triangle covering the entire screen
// void VS_PostProcess(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
// {
// 	texcoord.x = (id == 2) ? 2.0 : 0.0;
// 	texcoord.y = (id == 1) ? 2.0 : 0.0;
// 	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
// }

technique lilium__RenoDX_ColorGrading 
<
  ui_label = "Lilium's RenoDX Color Grading";
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
  ui_label = "Lilium's RenoDX Color Grading (ERROR)";
>
VS_ERROR

#endif //(defined(IS_ANALYSIS_CAPABLE_API) && ((ACTUAL_COLOUR_SPACE == CSP_SCRGB || ACTUAL_COLOUR_SPACE == CSP_HDR10) || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)))
