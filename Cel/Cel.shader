Shader "Custom/Cel" {

    Properties
    {
        

        [Header(Base Color)]
        [HDR][MainColor]_BaseColor("_BaseColor", Color) = (1,1,1,1)
        [MainTexture]_BaseMap("_BaseMap (albedo)", 2D) = "white" {}
        [Toggle]_UseBaseMask("_UseBaseMask", Float) = 0
        _BaseMaskMap("_BaseMaskMap", 2D) = "white" {}


        [Toggle]_UseMatcap("_UseMatcap", Float) = 0
        [NoScaleOffset] _Matcap("Matcap", 2D) = "white" {}

        [Toggle]_UseNormalMap("_UseNormalMap", Float) = 0
        [NoScaleOffset] _NormalMap("Normals", 2D) = "bump" {}
        _NormalScale("Normal Scale", Range(0, 1)) = 1

        [Header(RimColor)] //边缘光
        [HDR]_RimColor("_RimColor", Color) = (1,1,1,1)
        _RimMidPoint("_RimMidPoint", Range(-1,1)) = 0.7
        _RimSoftness("_RimSoftness", Range(0,1)) = 0.27
        //_RimSmooth("_RimSmooth", Range(0,10)) = 0.05
        [Toggle]_UseRimMask("_UseRimMask", Float) = 0
        _RimMaskMap("_RimMaskMap", 2D) = "white" {}

        [Header(Alpha)]
        [Toggle]_UseAlphaClipping("_UseAlphaClipping", Float) = 0
        _Cutoff("_Cutoff (Alpha Cutoff)", Range(0.0, 1.0)) = 0.5

        [Header(Lighting)]
        _IndirectLightConstColor("_IndirectLightConstColor", Color) = (0.5,0.5,0.5,1)
        _IndirectLightMultiplier("_IndirectLightMultiplier", Range(0,1)) = 1
        _DirectLightMultiplier("_DirectLightMultiplier", Range(0,1)) = 0.25
        _CelShadeMidPoint("_CelShadeMidPoint", Range(-1,1)) = -.5
        _CelShadeSoftness("_CelShadeSoftness", Range(0,1)) = 0.05

        [Header(Shadow mapping)]
        _ReceiveShadowMappingAmount("_ReceiveShadowMappingAmount", Range(0,1)) = 0.5

        [Header(Emission)]
        [Toggle]_UseEmission("_UseEmission (on/off completely)", Float) = 0
        [HDR] _EmissionColor("_EmissionColor", Color) = (0,0,0)
        _EmissionMap("_EmissionMap", 2D) = "white" {}
        _EmissionMapChannelMask("_EmissionMapChannelMask", Vector) = (1,1,1,1)

        [Header(Outline)]
        _OutlineWidth("_OutlineWidth (Object Space)", Range(0, 0.1)) = 0.0015
        _OutlineColor("_OutlineColor", Color) = (0.3,0.3,0.3,1)




    }
    SubShader
    {       
        Tags 
        {
            
            "RenderPipeline" = "UniversalRenderPipeline"
        }
        
        HLSLINCLUDE
            //#include "SimpleURPToonLitOutlineExample_Shared1.hlsl"
            //#include "SimpleURPToonLitOutlineExample_LightingEquation1.hlsl"
            #include "Shared.hlsl"
            #include "LightingEquation.hlsl"
            //所有通用渲染管线着色器均需要。将包含Unity内置的着色器变量（照明变量除外）它还将包含许多实用功能：
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            //包括照明着色器变量，灯光和阴影功能：
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

            
        ENDHLSL

        // ------------------------------------------------------------------
        // Forward pass. Shades GI, emission, fog and all lights in a single pass.
        Pass
        {               
            Name "SurfaceColor"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            //Cull Back
            Cull Off

            HLSLPROGRAM
            
            // -------------------------------------
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS //系统判断
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            // Unity defined keywords
            #pragma multi_compile_fog
            // -------------------------------------



            #pragma vertex BaseColorPassVertex
            #pragma fragment BaseColorPassFragment


            //---------------------------
            //法线贴图
            float3 DecodeNormal (float4 sample, float scale) {
            #if defined(UNITY_NO_DXT5nm)
                return UnpackNormalRGB(sample, scale);
            #else
                return UnpackNormalmapRGorAG(sample, scale);
            #endif
            }
            /*
            float3 GetNormalTS (float2 baseUV) {
                float4 map = SAMPLE_TEXTURE2D(_NormalMap, sampler_BaseMap, baseUV);
                float scaleN = INPUT_PROP(_NormalScale);
                float3 normal = DecodeNormal(map, scaleN);
                return normal;
            }
            */
            //---------------------------


            //顶点着色器（基础颜色）
            Varyings BaseColorPassVertex(Attributes input)
            {
                Varyings output;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);//Core中函数（坐标空间转换）
                VertexNormalInputs vertexNormalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);//Core中函数
                
                output.uv = TRANSFORM_TEX(input.uv,_BaseMap); //uv

                float fogFactor = ComputeFogFactor(vertexInput.positionCS.z);//雾化因子
                output.positionWSAndFogFactor = float4(vertexInput.positionWS, fogFactor);//世界空间坐标
                output.positionCS = vertexInput.positionCS;//裁剪空间坐标

                output.normalWS = vertexNormalInput.normalWS; //世界空间法线
                

                return output;
            }

            //片源着色器（基础颜色）
            half4 BaseColorPassFragment(Varyings input) : SV_TARGET
            {
                float4 baseColorFinal = tex2D(_BaseMap, input.uv) * _BaseColor; //图片*颜色
                

                //SurfaceData:
                SurfaceData surface; // albedo基础色，alpha透明度，emission发光
                surface.albedo = baseColorFinal.rgb; // albedo基础色
                surface.alpha = baseColorFinal.a;    // alpha透明度
                if(_UseAlphaClipping)  clip(surface.alpha - _Cutoff); //透明度小于_Cutoff的部分剔除
                if(_UseEmission) surface.emission = tex2D(_EmissionMap, input.uv).rgb * _EmissionColor.rgb * _EmissionMapChannelMask;
                // emission发光 = emissionMap * 颜色 * ChannelMask颜色通道遮罩。

                //LightingData:
                LightingData lightingData;//法线（世界空间），坐标（世界空间），视线向量（世界空间），阴影坐标
                lightingData.positionWS = input.positionWSAndFogFactor.xyz; //坐标（世界空间）
                lightingData.viewDirectionWS = SafeNormalize(GetCameraPositionWS() - lightingData.positionWS);//视线向量（世界空间）
                lightingData.normalWS = normalize(input.normalWS); //法线（世界空间）。内插法线不是单位向量。


                // 光照计算：
                //==========================================================================

                // Indirect lighting 间接光：
                //--------------------------------------------
                half3 averageSH = SampleSH(0); //平均环境色。一阶球谐。
                half3 indirectResult = surface.albedo * (_IndirectLightConstColor + averageSH * _IndirectLightMultiplier); 
                // 间接光 = 基础色 * （间接光定色 + 平均环境光 * 间接光乘数）
                //--------------------------------------------

                // Main light 主光：
                //--------------------------------------------
                Light mainLight = GetMainLight(); //Lighting.hlsl中函数

                half3 N = lightingData.normalWS; //世界空间法线
                half3 L = mainLight.direction;       //光照向量
                half3 V = lightingData.viewDirectionWS; //世界空间视线
                half3 H = normalize(L+V);        //半程向量
                
                half NoL = dot(N,L);  //法线·光线（世界空间）
                //half NoH = dot(N,H);
                //half halfLambert = dot(N, L) * 0.5 + 0.5;
                
                half lightAttenuation = 1;  //光照衰减
                lightAttenuation *= min(2,mainLight.distanceAttenuation); // 光衰减。最大强度= 2，如果光线太近则可以防止过亮。

                //最简单的1行cel着色，您始终可以用自己的更好的方法替换此行！
                lightAttenuation *= smoothstep(_CelShadeMidPoint-_CelShadeSoftness,_CelShadeMidPoint+_CelShadeSoftness, NoL);
                //smoothstep返回值范围【0，1】。_CelShadeMidPoint是中点，_CelShadeSoftness是中点到两端点的距离。

                
                lightAttenuation *= _DirectLightMultiplier; //直接光乘数，对卡通人物低一点。

                half3 mainLightResult = surface.albedo * mainLight.color * lightAttenuation;

                
                //-------
                //边缘光
                half f = 1 - saturate(dot(V, N)); //V·N
                
                half rim = smoothstep(_RimMidPoint-_RimSoftness,_RimMidPoint+_RimSoftness, f) * saturate(NoL);
                //_RimMidPoint控制范围，_RimSoftness控制羽化程度
                
                half3 rimColor = rim * _RimColor.rgb *  _RimColor.a;

                if(_UseRimMask) rimColor *= tex2D(_RimMaskMap, input.uv).r;
    
                mainLightResult += rimColor;
                //mainLightResult += rimColor*surface.albedo;
                
                
                
                //--------------------------------------------
                // 额外光：
                
                half3 additionalLightSumResult = 0;
               
                //面部遮罩
                float faceMask = 1; 
                if(_UseBaseMask) faceMask = tex2D(_BaseMaskMap, input.uv).r;
                

                if(faceMask == 0)
                {
                #ifdef _ADDITIONAL_LIGHTS
                    //返回影响正在渲染的对象的 光的数量。这些灯光在URP的正向渲染器中按对象剔除。
                    int additionalLightsCount = GetAdditionalLightsCount();
                    for (int i = 0; i < additionalLightsCount; ++i)
                    {
                        
                        //与GetMainLight（）类似，但是它需要一个for循环索引。 这算出
                        //每个对象的灯光索引并相应地采样灯光缓冲区以初始化 光照struct。 如果定义了_ADDITIONAL_LIGHT_SHADOWS，它还将计算阴影。
                        Light light = GetAdditionalLight(i, lightingData.positionWS);
                
                        //计算额外光。
                        additionalLightSumResult += ShadeAdditionalLight(surface, lightingData, light);
                    }
                #endif
                }
                //--------------------------------------------

                

                // emission自发光
                half3 emissionResult = surface.emission;

                // 最终颜色
                half3 color = indirectResult + mainLightResult + additionalLightSumResult + emissionResult;
                //half3 color = indirectResult + mainLightResult + emissionResult;

                //Matcap
                if(_UseMatcap){
                    float3 NtoV = TransformWorldToView(lightingData.normalWS);
                    half3 matcapLookup = tex2D(_Matcap, NtoV * 0.5 + 0.5).rgb;    //采样
                    matcapLookup += tex2D(_NormalMap, NtoV * 0.5 + 0.5).rgb;    //采样
                    color += matcapLookup;
                }
                
                // fog
                half fogFactor = input.positionWSAndFogFactor.w;
                //half fogFactor = 0.2;
                //将像素颜色与fogColor混合。 您可以选择使用MixFogColor来用自定义值重写fogColor。
                
                color = MixFog(color, fogFactor);

                half bloomMask = rim*40; //只有边缘光部分bloom，保存到color的alpha
                
                if(faceMask == 1) bloomMask += 1-color.b; 

                return half4(color, bloomMask);
                //return half4(rim,rim,rim,1);
            }

            ENDHLSL
        }
        
        
        ///*
        // ------------------------------------------------------------------
        // Outline pass. Similar to "SurfaceColor" pass, but vertex position are pushed out a bit base on normal direction, also color is darker 
        Pass 
        {
            Name "Outline"
            Tags 
            {
                //"LightMode" = "UniversalForward" // IMPORTANT: don't write this line for any custom +pass! else this outline pass will not be rendered in URP!
            }
            Cull Front // Cull Front is a must for extra pass outline method

            HLSLPROGRAM

            //copy from the first pass
            // -------------------------------------
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            // -------------------------------------
            #pragma multi_compile_fog
            // -------------------------------------


            #pragma vertex OutlinePassVertex
            #pragma fragment OutlinePassFragment

            Varyings OutlinePassVertex(Attributes input)
            {
            
                Varyings output;

                half3 nomVS = mul((float3x3)UNITY_MATRIX_IT_MV, input.tangentOS.xyz); //相机空间法线（法线已经平滑转换后存到切线空间）
                //half3 nomOS = input.tangentOS.xyz; //相机空间法线（法线已经平滑转换后存到切线空间）


                //half3 posOS = input.positionOS + normalize(nomOS) * _OutlineWidth; //描边沿着法线外拓
                
                half4 posWS = mul(unity_ObjectToWorld, float4(input.positionOS,1)); //世界空间坐标
                half4 posVS = mul(unity_MatrixV, posWS);                 //相机空间坐标
                
                posVS += half4(normalize(nomVS) * _OutlineWidth, 0); //描边沿着法线外拓
                
                posVS = float4(posVS.x, posVS.y, posVS.z - 0.003, posVS.w); //描边在相机空间z-0.001，防止内凹模型描边遮挡正面

                output.positionCS = mul(UNITY_MATRIX_P, posVS); //裁剪空间坐标

                output.color = input.vertexColor;

                return output;
                
            }

            half4 OutlinePassFragment(Varyings input) : SV_TARGET
            {
                //return half4(_OutlineColor,1);
                return input.color;
            }

            ENDHLSL
        }
        

        
        //用于渲染URP的阴影贴图
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            //we don't care about color, we just write to depth
            //不关心颜色，只写深度
            ColorMask 0

            HLSLPROGRAM

            #pragma vertex ShadowCasterPassVertex
            #pragma fragment ShadowCasterPassFragment

            #include "Shared.hlsl"

            Varyings ShadowCasterPassVertex(Attributes input)
            {
                VertexShaderWorkSetting setting = GetDefaultVertexShaderWorkSetting();

                setting.isOutline = false; //(you can delete this line, this line is just a note) the correct value is false here, else self shadow is not correct
                setting.applyShadowBiasFixToHClipPos = true;//important for shadow caster pass, else shadow artifact will appear
                //对于ShadowCaster Pass很重要，否则会出现阴影伪像
                
                return VertexShaderWork(input, setting);
            }

            half4 ShadowCasterPassFragment(Varyings input) : SV_TARGET
            {
                return BaseColorAlphaClipTest(input);
            }

            ENDHLSL
        }
       
        // Used for depth prepass
        // If depth texture is needed, we need to perform a depth prepass for this shader. 
        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            //we don't care about color, we just write to depth
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex DepthOnlyPassVertex
            #pragma fragment DepthOnlyPassFragment

            #include "Shared.hlsl"

            Varyings DepthOnlyPassVertex(Attributes input)
            {
                VertexShaderWorkSetting setting = GetDefaultVertexShaderWorkSetting();

                // set param "isOutline" to ture because outline should affect depth (e.g. handle depth of field's correctly at outline area)
                // setting "isOutline" to true = push vertex out a bit according to normal direction
                // 描边会写入深度
                setting.isOutline = true;

                return VertexShaderWork(input, setting);
            }

            half4 DepthOnlyPassFragment(Varyings input) : SV_TARGET
            {
                return BaseColorAlphaClipTest(input);
            }

            ENDHLSL
        }
    }
}