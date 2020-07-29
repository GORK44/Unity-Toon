#ifndef Shared
#define Shared

// We don't have "UnityCG.cginc" in SRP/URP's package anymore, so:
// Including the following two hlsl files is enough for shading with Universal Pipeline. Everything is included in them.
// Core.hlsl will include SRP shader library, all constant buffers not related to materials (perobject, percamera, perframe).
// It also includes matrix/space conversion functions and fog.
// Lighting.hlsl will include the light functions/data to abstract light constants. You should use GetMainLight and GetLight functions
// that initialize Light struct. Lighting.hlsl also include GI, Light BDRF functions. It also includes Shadows.

// Required by all Universal Render Pipeline shaders.
// It will include Unity built-in shader variables (except the lighting variables)
// (https://docs.unity3d.com/Manual/SL-UnityShaderVariables.html
// It will also include many utilitary functions. 
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// Include this if you are doing a lit shader. This includes lighting shader variables,
// lighting and shadow functions
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// Material shader variables are not defined in SRP or URP shader library.
// This means _BaseColor, _BaseMap, _BaseMap_ST, and all variables in the Properties section of a shader
// must be defined by the shader itself. If you define all those properties in CBUFFER named
// UnityPerMaterial, SRP can cache the material properties between frames and reduce significantly the cost
// of each drawcall.
// In this case, although URP's LitInput.hlsl contains the CBUFFER for the material
// properties defined above. As one can see this is not part of the ShaderLibrary, it specific to the
// URP Lit shader.
// So we are not going to use LitInput.hlsl, we will implement everything by ourself.
//#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

//note:
//subfix OS means object space (e.g. positionOS = position object space)
//subfix WS means world space (e.g. positionWS = position world space)

// all pass will share this Attributes struct (define data needed from Unity app to our vertex shader)
struct Attributes
{
    float3 positionOS   : POSITION;
    half3 normalOS     : NORMAL;
    half4 tangentOS    : TANGENT;
    float2 uv           : TEXCOORD0;
};

// all pass will share this Varyings struct (define data needed from our vertex shader to our fragment shader)
struct Varyings
{
    float2 uv                       : TEXCOORD0;
    float4 positionWSAndFogFactor   : TEXCOORD2; // xyz: positionWS, w: vertex fog factor
    half3 normalWS                 : TEXCOORD3;

#ifdef _MAIN_LIGHT_SHADOWS
    float4 shadowCoord              : TEXCOORD6; // compute shadow coord per-vertex for the main light
#endif
    float4 positionCS               : SV_POSITION;
};

///////////////////////////////////////////////////////////////////////////////////////
// CBUFFER and Uniforms 
// (you should put all uniforms of all passes inside this single UnityPerMaterial CBUFFER! else SRP batching is not possible!)
///////////////////////////////////////////////////////////////////////////////////////

// all sampler2D don't need to put inside CBUFFER 
sampler2D _BaseMap; 
sampler2D _EmissionMap;
sampler2D _BaseMaskMap;
sampler2D _NormalMap;
sampler2D _RimMaskMap;

// put all your uniforms(usually things inside properties{} at the start of .shader file) inside this CBUFFER, in order to make SRP batcher compatible
CBUFFER_START(UnityPerMaterial)


    // base color
    float4 _BaseMap_ST;
    half4 _BaseColor;
    half4 _RimColor;
    float _UseBaseMask;//使用遮罩
    //sampler2D _BaseMaskMap;

    float _UseNormalMap;//使用法线贴图
    half _NormalScale;

    //rim
    half _RimMidPoint;
    half _RimSoftness;
    //half _RimSmooth;


    float _UseRimMask;//使用遮罩

    // alpha
    float _UseAlphaClipping;
    half _Cutoff;

    //lighting
    half3 _IndirectLightConstColor;
    half _IndirectLightMultiplier;
    half _DirectLightMultiplier;
    half _CelShadeMidPoint;
    half _CelShadeSoftness;

    // shadow mapping
    half _ReceiveShadowMappingAmount;

    //emission
    float _UseEmission;
    half3 _EmissionColor;
    half3 _EmissionMapChannelMask;

    // outline
    float _OutlineWidth;
    half3 _OutlineColor;

CBUFFER_END

//a special uniform for applyShadowBiasFixToHClipPos() only, it is not a per material uniform, 
//so it is fine to write it outside our UnityPerMaterial CBUFFER
half3 _LightDirection;

struct SurfaceData
{
    half3 albedo;
    half  alpha;
    half3 emission;
};
struct LightingData
{
    half3 normalWS;
    float3 positionWS;
    half3 viewDirectionWS;
    float4 shadowCoord;
};




#endif
