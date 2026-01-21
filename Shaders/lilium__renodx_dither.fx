#include "lilium__include/include_main.fxh"

#if ACTUAL_COLOUR_SPACE == CSP_SCRGB || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)

// ReShadeUI ///////////////////////////////////////////////////////////////////////////////////////
// uniform int DecodeGamma
// <
//   ui_category = "Decode";
//   ui_label    = "Gamma";
//   ui_type     = "combo";
//   ui_items    = "sRGB\0"
//                 "2.2\0";
//   ui_tooltip = "Decode the formerly SDR-intended image.\nUsually it is sRGB, but it must be confirmed in shader code.";
// > = 0;

uniform float swap_chain_output_dither_bits <
  ui_type = "slider";
  ui_category = "Dither";
  ui_label = "Bits";
  ui_tooltip = "Bit depth to dither to.";
  ui_min = 1;
  ui_max = 32;
  ui_step = 1.f;
> = 12;

uniform float swap_chain_output_dither_amplitude <
  ui_type = "slider";
  ui_category = "Dither";
  ui_label = "Amplitude";
  ui_tooltip = "Strength relative to dither bits.";
  ui_min = 0;
  ui_max = 2;
  ui_step = 0.001f;
> = 1.2;


// uniform bool EOTFEmuBT2020 <
//     ui_category = "EOTF / Gamma Correction";
//     ui_label = "Wide Color Gamut Boost";
//     ui_tooltip = "Enocode to BT2020 before gamma correction, pushing out colors to WCG.";
// > = false;

uniform int RANDOM
<
  source = "random";
  min    = 0;
  max    = 100000;
>;

float Permute(float X)
{
  X = (34.f * X + 1.f) * X;
  return frac(X * 1.f / 289.f) * 289.f;
}

float Rand(inout float State)
{
  State = Permute(State);
  return frac(State * 1.f / 41.f);
}

// https://web.archive.org/web/20080211204527/http://lumina.sourceforge.net/Tutorials/Noise.html
float Generate(float2 uv) {
  return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

///////////////////////////////////////////////////////////////////////////////////
//https://github.com/Filoppi/Luma-Framework/blob/main/Shaders/Includes/Math.hlsl
float3 Sign_UltraFast(float3 x) {return asfloat((asuint(x) & 0x80000000u) | 0x3F800000u);}

float SafeDivision(float a, float b, float f = 0) { return b != 0.f ? a / b : f; }
///////////////////////////////////////////////////////////////////////////////////

float4 PS_Main(in float4 Position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target0 {
  float4 color = tex2Dfetch(SamplerBackBuffer, int2(Position.xy));

  float3 m     = float3(texcoord, RANDOM / 100000.f) + 1.f;
  float  state = Permute(Permute(m.x) + m.y) + m.z;
  // float p = 0.95f * Rand(state) + 0.025f;
  // float q = p - 0.5f;
  // float r = q * q;
  // float random_number = r;
  float random_number = Generate(texcoord + state);

  float maxValue = exp2(swap_chain_output_dither_bits) - 1.0;
  float dither_strength = exp2(swap_chain_output_dither_amplitude * swap_chain_output_dither_bits) - 1.0;
  // ie: 12bit amplitude for 10bit quantization

  float3 noise = (random_number - 0.5) * (1.f / maxValue);

  float3 dithered = color.rgb * maxValue + noise * dither_strength;

  float3 rounded = round(max(0, dithered)) / maxValue;

  color = rounded;
	
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
  ui_label = "Lilium's RenoDX Dither";
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
  ui_label = "Lilium's RenoDX Dither (ERROR)";
>
VS_ERROR

#endif //(defined(IS_ANALYSIS_CAPABLE_API) && ((ACTUAL_COLOUR_SPACE == CSP_SCRGB || ACTUAL_COLOUR_SPACE == CSP_HDR10) || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)))
