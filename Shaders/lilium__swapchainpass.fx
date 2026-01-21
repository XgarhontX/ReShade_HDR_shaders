#include "lilium__include/include_main.fxh"

#if ACTUAL_COLOUR_SPACE == CSP_SCRGB || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)

// ReShadeUI ///////////////////////////////////////////////////////////////////////////////////////
uniform int DecodeGamma
<
  ui_category = "Decode";
  ui_label    = "Gamma";
  ui_type     = "combo";
  ui_items    = "sRGB\0"
                "2.2\0";
  ui_tooltip = "Decode the formerly SDR-intended image.\nUsually it is sRGB, but it must be confirmed in shader code.";
> = 0;

uniform float DecodeUIBrightness <
  ui_type = "slider";
  ui_category = "Decode";
  ui_label = "UI Brightness (Read Tooltip!)";
  ui_tooltip = "If UI Brightness is set beforehand, this can inverse the scaling multiplier to only change UI.\nElse, this will just be paper white scaling.";
  ui_min = 20;
  ui_max = 500;
  ui_step = 1.f;
> = 203;

uniform float EOTFEmuThres <
  ui_type = "slider";
  ui_category = "EOTF / Gamma Correction";
  ui_label = "Threshold (Paper White)";
  ui_tooltip = "Move the influence range given the target paper white.\n0 to disable.";
  ui_min = 0;
  ui_max = 500;
  ui_step = 1.f;
> = 203;

uniform bool EOTFEmuBT2020 <
    ui_category = "EOTF / Gamma Correction";
    ui_label = "Wide Color Gamut Boost";
    ui_tooltip = "Enocode to BT2020 before gamma correction, pushing out colors to WCG.";
> = false;

///////////////////////////////////////////////////////////////////////////////////
//https://github.com/Filoppi/Luma-Framework/blob/main/Shaders/Includes/Math.hlsl
float3 Sign_UltraFast(float3 x)
{
  return asfloat((asuint(x) & 0x80000000u) | 0x3F800000u);
}

float SafeDivision(float a, float b, float f = 0) { return b != 0.f ? a / b : f; }

float3 EOTFEmulate(float3 color, float gamma) {
  if (EOTFEmuThres <= 0) return color;

  const float scale = EOTFEmuThres / 80.f;
  color /= scale;

  float3 colorS = Sign_UltraFast(color);
  float3 colorA = abs(color);
  if (colorA.x < 1) color.x = colorS.x * pow(Csp::Trc::Linear_To::sRGB(colorA.x), gamma);
  if (colorA.y < 1) color.y = colorS.y * pow(Csp::Trc::Linear_To::sRGB(colorA.y), gamma);
  if (colorA.z < 1) color.z = colorS.z * pow(Csp::Trc::Linear_To::sRGB(colorA.z), gamma);

  color *= scale;

  return color;
}
///////////////////////////////////////////////////////////////////////////////////

float4 PS_Main(in float4 Position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target0 {
  float4 color = tex2Dfetch(SamplerBackBuffer, int2(Position.xy));
	
  //not scRGB
  #if ACTUAL_COLOUR_SPACE != CSP_SCRGB
    return color;
  #endif

  //Decode (in BT709)
  float3 cS = Sign_UltraFast(color.xyz);
  float3 cA = abs(color.xyz);
  color.xyz = cS * (DecodeGamma == 0 ? Csp::Trc::sRGB_To::Linear(cA) : pow(cA, 2.2));
	
  //UI Brightness
  color.xyz *= DecodeUIBrightness / 80;
	
  //color.xyz = max(0, color.xyz);
  if (EOTFEmuBT2020) color.xyz = Csp::Mat::BT709_To::BT2020(color.xyz);

  //EOTF Emulate
  color.xyz = EOTFEmulate(color.xyz, 2.2);

  //Out WORKINGCS (to BT709)
  if (EOTFEmuBT2020) color.xyz = Csp::Mat::BT2020_To::BT709(color.xyz);

  return color;
}

// // Vertex shader generating a triangle covering the entire screen
// void VS_PostProcess(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
// {
// 	texcoord.x = (id == 2) ? 2.0 : 0.0;
// 	texcoord.y = (id == 1) ? 2.0 : 0.0;
// 	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
// }

technique lilium__SwapchainPass
<
  ui_label = "Lilium's Swapchain Pass (Gamma to scRGB)";
>
{
	pass Final {
		VertexShader = VS_PostProcess; //default
		PixelShader = PS_Main;
	}
}

#else //(defined(IS_ANALYSIS_CAPABLE_API) && ((ACTUAL_COLOUR_SPACE == CSP_SCRGB || ACTUAL_COLOUR_SPACE == CSP_HDR10) || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)))

ERROR_STUFF

technique lilium__SwapchainPass
<
  ui_label = "Lilium's Swapchain Pass (Gamma to scRGB) (ERROR)";
>
VS_ERROR

#endif //(defined(IS_ANALYSIS_CAPABLE_API) && ((ACTUAL_COLOUR_SPACE == CSP_SCRGB || ACTUAL_COLOUR_SPACE == CSP_HDR10) || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)))
