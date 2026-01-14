// #include "Reshade.fxh"
// #include "ReShadeUI.fxh"
#include "lilium__include/colour_space.fxh"

#if ACTUAL_COLOUR_SPACE == CSP_SCRGB || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)

uniform float DecodeGamma <
    ui_type = "slider";
    ui_category = "Expansion";
    ui_label = "Gamma";
    ui_min = 1.1;
    ui_max = 5.0;
    ui_step = 0.1f;
> = 2.2;

uniform float Saturation <
    ui_type = "slider";
    ui_category = "Expansion";
    ui_label = "Saturation Multiplier";
    ui_min = 0;
    ui_max = 2;
    ui_step = 0.001f;
> = 1;

uniform float CorrectionChrominance <
    ui_type = "slider";
    ui_category = "Correction / Reduction";
    ui_label = "Chrominance";
    ui_min = 0.0;
    ui_max = 1.0;
    ui_step = 0.001f;
> = 0.6;
uniform float CorrectionLuminance <
    ui_type = "slider";
    ui_category = "Correction / Reduction";
    ui_label = "Luminance";
    ui_min = 0.0;
    ui_max = 0.9;
    ui_step = 0.001f;
> = 0.5;

#ifndef CLAMP_BT2020
  #define CLAMP_BT2020 1
#endif

///////////////////////////////////////////////////////////////////////////////////
float3 Sign(float3 x) { return sign(x); }
float Sign(float x) { return sign(x); }

//https://github.com/Filoppi/Luma-Framework/blob/main/Shaders/Includes/Math.hlsl
float3 Sign_UltraFast(float3 x)
{
  return asfloat((asuint(x) & 0x80000000u) | 0x3F800000u);
}

float SafeDivision(float a, float b, float f = 0) { return b != 0.f ? a / b : f; }
///////////////////////////////////////////////////////////////////////////////////
//https://github.com/Filoppi/Luma-Framework/blob/main/Shaders/Includes/ColorGradingLUT.hlsl

// Restores the source color hue (and optionally brightness) through Oklab (this works on colors beyond SDR in brightness and gamut too).
// The strength sweet spot for a strong hue restoration seems to be 0.75, while for chrominance, going up to 1 is ok.
float3 RestoreHueAndChrominanceBT2020(float3 targetColor, float3 sourceColor, float hueStrength = 1.0, float chrominanceStrength = 1.0, float lightnessStrength = 0.0)
{
  const static float minChrominanceChange = 0;
  const static float maxChrominanceChange = asfloat(0x7F7FFFFF);
  
  // Invalid or black colors fail oklab conversions or ab blending so early out
  if (dot(targetColor, Csp::Mat::Bt2020ToXYZ[1]) <= asfloat(0x00800000))
    return targetColor; // Optionally we could blend the target towards the source, or towards black, but there's no need until proven otherwise

	const float3 sourceUcsLab = Csp::OkLab::Bt2020To::OkLab(sourceColor);
	float3 targetUcsLab = Csp::OkLab::Bt2020To::OkLab(targetColor);
   
  targetUcsLab.x = lerp(targetUcsLab.x, sourceUcsLab.x, lightnessStrength);
  
	float currentChrominance = length(targetUcsLab.yz);

  if (hueStrength != 0.0)
  {
    // First correct both hue and chrominance at the same time (oklab a and b determine both, they are the color xy coordinates basically).
    // As long as we don't restore the hue to a 100% (which should be avoided?), this will always work perfectly even if the source color is pure white (or black, any "hueless" and "chromaless" color).
    // This method also works on white source colors because the center of the oklab ab diagram is a "white hue", thus we'd simply blend towards white (but never flipping beyond it (e.g. from positive to negative coordinates)),
    // and then restore the original chrominance later (white still conserving the original hue direction, so likely spitting out the same color as the original, or one very close to it).
    const float chrominancePre = currentChrominance;
    targetUcsLab.yz = lerp(targetUcsLab.yz, sourceUcsLab.yz, hueStrength);
    const float chrominancePost = length(targetUcsLab.yz);
    // Then restore chrominance to the original one
    float chrominanceRatio = SafeDivision(chrominancePre, chrominancePost, 1);
    targetUcsLab.yz *= chrominanceRatio;
    //currentChrominance = chrominancePre; // Redundant
  }

  if (chrominanceStrength != 0.0)
  {
    const float sourceChrominance = length(sourceUcsLab.yz);
    // Scale original chroma vector from 1.0 to ratio of target to new chroma
    // Note that this might either reduce or increase the chroma.
    float targetChrominanceRatio = SafeDivision(sourceChrominance, currentChrominance, 1);
    // Optional safe boundaries (0.333x to 2x is a decent range)
    targetChrominanceRatio = clamp(targetChrominanceRatio, minChrominanceChange, maxChrominanceChange);
    targetUcsLab.yz *= lerp(1.0, targetChrominanceRatio, chrominanceStrength);
  }

  //Saturation
  targetUcsLab.yz *= Saturation;

	return Csp::OkLab::OkLabTo::Bt2020(targetUcsLab);
}
///////////////////////////////////////////////////////////////////////////////////

float4 PS_Main(in float4 Position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target0 {
  //get linear
	float4 color = tex2Dfetch(SamplerBackBuffer, int2(Position.xy));

  //HDR10 BT2020 or scRGB BT709?
  #ifndef IS_HDR10_LIKE_CSP
    float3 colorRef = Csp::Mat::Bt709To::Bt2020(color.rgb);
    float3 colorExp  = color.rgb;
  #else 
    float3 colorRef = color.rgb;
    float3 colorExp  = Csp::Mat::Bt2020To::Bt709(color.rgb);
  #endif

  //expand
  colorExp = Sign_UltraFast(colorExp) * pow(abs(colorExp), 1/DecodeGamma);
  colorExp = Csp::Mat::Bt709To::Bt2020(colorExp);
  colorExp = Sign_UltraFast(colorExp) * pow(abs(colorExp), DecodeGamma);

  //correct
  colorExp = RestoreHueAndChrominanceBT2020(colorExp, colorRef, 1.0, CorrectionChrominance, CorrectionLuminance);

  //clamp
  #if CLAMP_BT2020 > 0
    colorExp = max(0, colorExp);
  #endif

  //to scRGB BT709?
  #ifndef IS_HDR10_LIKE_CSP
    colorExp = Csp::Mat::Bt2020To::Bt709(colorExp);
  #endif 
  
  //out
  return float4(colorExp, color.w);
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
  ui_label = "Lilium's Fake WCG";
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
  ui_label = "Lilium's Fake WCG (ERROR)";
>
VS_ERROR

#endif //(defined(IS_ANALYSIS_CAPABLE_API) && ((ACTUAL_COLOUR_SPACE == CSP_SCRGB || ACTUAL_COLOUR_SPACE == CSP_HDR10) || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)))
