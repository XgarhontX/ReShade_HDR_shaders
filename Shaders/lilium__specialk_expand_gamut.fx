#include "lilium__include/include_main.fxh"


#if ACTUAL_COLOUR_SPACE == CSP_SCRGB || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)


uniform float ExpandAmount <
    ui_type = "slider";
    ui_category = "Expansion";
    ui_label = "Amount";
    ui_min = 0;
    ui_max = 1.;
    ui_step = 0.0001f;
> = 0.1;

uniform float ExpandCurve <
    ui_type = "slider";
    ui_category = "Expansion";
    ui_label = "Curve";
    ui_min = 0;
    ui_max = 2;
    ui_step = 0.0001f;
> = 1;

#ifndef CLAMP_BT2020
  #define CLAMP_BT2020 1
#endif

///////////////////////////////////////////////////////////////////////////////////
float3 Sign(float3 x) { return sign(x); }
float Sign(float x) { return sign(x); }

//https://github.com/Filoppi/Luma-Framework/blob/main/Shaders/Includes/Math.hlsl
float3 Sign_UltraFast(float3 x){ return asfloat((asuint(x) & 0x80000000u) | 0x3F800000u);}

float SafeDivision(float a, float b, float f = 0) { return b != 0.f ? a / b : f; }

float GetLuminanceSpecify(float3 x, bool isBT2020) {
  if (!isBT2020) dot(x, Csp::Mat::BT709_To_XYZ[1]);
  return dot(x, Csp::Mat::BT2020_To_XYZ[1]);
}

///////////////////////////////////////////////////////////////////////////////////
//https://github.com/SpecialKO/SpecialK/blob/main/resource/shaders/HDR/common_defs.hlsl
float3 AP1_D65toRec709 (float3 linearAP1)
{
  static const float3x3 AP1_D65toXYZ = float3x3
  (
     0.64750719070434570312500000000f, 0.134379133582115173339843750000f, 0.168569594621658325195312500f,
     0.26608639955520629882812500000f, 0.675967812538146972656250000000f, 0.057945795357227325439453125f,
    -0.00544886849820613861083984375f, 0.004072095267474651336669921875f, 1.090434551239013671875000000f
  );

  static const float3x3 XYZtoRec709 = float3x3
  (
     3.240969896316528320312500000f, -1.5373831987380981445312500f, -0.4986107647418975830078125000f,
    -0.969243645668029785156250000f,  1.8759675025939941406250000f,  0.0415550582110881805419921875f,
     0.055630080401897430419921875f, -0.2039769589900970458984375f,  1.0569715499877929687500000000f
  );

  return mul (XYZtoRec709, mul (AP1_D65toXYZ, linearAP1));
}

float3 expandGamut (float3 vHDRColor, float fExpandGamut = 1.0f, float fCurve = 1.0f)
{
  if (fExpandGamut <= 0.0f) return vHDRColor;

  const float3x3 sRGB_2_AP1_D65_MAT = float3x3
  (
    0.6168509940091290, 0.334062934274955, 0.0490860717159169,
    0.0698663939791712, 0.917416678964894, 0.0127169270559354,
    0.0205490668158849, 0.107642210710817, 0.8718087224732980
  );
  const float3x3 AP1_D65_2_sRGB_MAT = float3x3
  (
     1.6926793984921500, -0.606218057156000, -0.08646134133615040,
    -0.1285739800722680,  1.137933633392290, -0.00935965332001697,
    -0.0240224650921189, -0.126211717940702,  1.15023418303282000
  );
  const float3x3 AP1_D65_2_XYZ_MAT = float3x3
  (
     0.64729265784680500, 0.13440339917805700, 0.1684710654303190,
     0.26599824508992100, 0.67608982616840700, 0.0579119287416720,
    -0.00544706303938401, 0.00407283027812294, 1.0897972045023700
  );
  const float3x3 Wide_2_AP1_D65_MAT = float3x3
  (
    0.83451690546233900, 0.1602595895494930, 0.00522350498816804,
    0.02554519357785500, 0.9731015318660700, 0.00135327455607548,
    0.00192582885428273, 0.0303727970124423, 0.96770137413327500
  );
  const float3x3 AP1_2_sRGB = float3x3 
  (
     1.70505, -0.62179, -0.08326,
    -0.13026,  1.14080, -0.01055,
    -0.02400, -0.12897,  1.15297
  );

  const float3x3 ExpandMat = mul (Wide_2_AP1_D65_MAT, AP1_D65_2_sRGB_MAT);
  float3 ColorAP1  = mul (sRGB_2_AP1_D65_MAT, vHDRColor);

  float  LumaAP1   = GetLuminanceSpecify(AP1_D65toRec709(ColorAP1), false);
  float3 ChromaAP1 = ColorAP1 / LumaAP1;

  float ChromaDistSqr = dot(ChromaAP1 - 1.0f, ChromaAP1 - 1.0f);
  ChromaDistSqr = max(abs(ChromaDistSqr), 0.000001f);
  ChromaDistSqr = pow(ChromaDistSqr, fCurve);

  float ExpandAmount  = (1.0f - exp2 (-4.0f * ChromaDistSqr)) * (1.0f - exp2 (-4.0f * fExpandGamut * LumaAP1 * LumaAP1));

  float3 ColorExpand = mul(ExpandMat, ColorAP1);
  
  ColorAP1 = lerp(ColorAP1, ColorExpand, ExpandAmount);

  vHDRColor = mul(AP1_2_sRGB, ColorAP1);
  
  return vHDRColor;
}
///////////////////////////////////////////////////////////////////////////////////

float4 PS_Main(in float4 Position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target0 {
  //get linear
	float4 color = tex2Dfetch(SamplerBackBuffer, int2(Position.xy));
  float3 x = color.rgb;

  //HDR10 BT2020 or scRGB BT709?
  #ifndef IS_HDR10_LIKE_CSP
    x = Csp::Mat::BT709_To::BT2020(color.rgb);
  #endif

  //expand
  x = expandGamut(x, ExpandAmount, ExpandCurve);

  //to scRGB BT709?
  #ifndef IS_HDR10_LIKE_CSP
    x = Csp::Mat::BT2020_To::BT709(x);
  #endif 
  
  //out
  return float4(x, color.w);
}

// // Vertex shader generating a triangle covering the entire screen
// void VS_PostProcess(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
// {
// 	texcoord.x = (id == 2) ? 2.0 : 0.0;
// 	texcoord.y = (id == 1) ? 2.0 : 0.0;
// 	position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
// }

technique lilium__RenoDX_SpecialK_Expand_Gamut
<
  ui_label = "Lilium's SpecialK Expand Gamut";
>
{
	pass Final {
		VertexShader = VS_PostProcess; //default
		PixelShader = PS_Main;
	}
}

#else //(defined(IS_ANALYSIS_CAPABLE_API) && ((ACTUAL_COLOUR_SPACE == CSP_SCRGB || ACTUAL_COLOUR_SPACE == CSP_HDR10) || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)))

ERROR_STUFF

technique lilium__RenoDX_SpecialK_Expand_Gamut
<
  ui_label = "Lilium's SpecialK Expand Gamut (ERROR)";
>
VS_ERROR

#endif //(defined(IS_ANALYSIS_CAPABLE_API) && ((ACTUAL_COLOUR_SPACE == CSP_SCRGB || ACTUAL_COLOUR_SPACE == CSP_HDR10) || defined(MANUAL_OVERRIDE_MODE_ENABLE_INTERNAL)))
