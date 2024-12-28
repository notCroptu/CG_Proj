Shader "Custom/RevealingShader"
{
    Properties
    {
        _MainTex ("Texture to be Revealed", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            Name "DepthPass"
            Tags { "LightMode"="UniversalForward" }
            
            ZWrite On      // Write depth
            ZTest LEqual   // Test against depth buffer
            ColorMask 0    // Don't write color, only depth

            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragDepth
            #pragma target 3.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct VertexInput
            {
                float4 vertex : POSITION;
            };

            struct VertexOutput
            {
                float4 pos : SV_POSITION;
            };

            // Depth pass fragment shader (no color output)
            float4 fragDepth(VertexOutput i) : SV_Target
            {
                return float4(1, 0, 0, 0); // Ensures depth is written
            }

            VertexOutput vert(VertexInput v)
            {
                VertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                return o;
            }

            ENDHLSL
        }

        Pass
        {
            Name "NormalPass"
            Tags { "RenderType"="Transparent" "Queue"="Overlay" }
            ZWrite Off
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
            

            #define MAX_ADDITIONAL_LIGHTS 8

            uniform float _LightRange;
            uniform half3 _LightColor;
            uniform float3 _SpotLightDir;
            uniform float _LightStrengthIntensity;
            uniform float _InnerSpotAngle;
            uniform float _OuterSpotAngle;
            uniform float _Lighted;
            uniform float3 _SpotLightPos;
            uniform float4x4 _SpotlightViewMatrix;
            uniform float4x4 _SpotlightProjectionMatrix;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            half4 _Color;

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct VertexOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
            };

            // Calculate normalized distance from the light position
            float NormalizedDistance(float3 worldPos)
            {
                float dist = distance(worldPos, _SpotLightPos);
                return dist / _LightRange;
            }
            
            // Inverse square falloff based on distance
            float InverseSquareFalloff(float normalDist)
            {
                return 1.0f / (1.0f + _LightStrengthIntensity * normalDist * normalDist);
            }
            
            // Smooth range falloff for more control over light intensity
            float SmoothRange(float normalDist)
            {
                return saturate((1.0f - normalDist) * 5.0f);
            }

            // Calculate angle-based attenuation for the spotlight
            float AngleAttenuation(float3 lightDir)
            {
                lightDir = normalize(lightDir);
                float angle = dot(lightDir, normalize(_SpotLightDir));
                return smoothstep(_OuterSpotAngle, _InnerSpotAngle, angle);
            }

            uniform int _LightIndex;

            // Sample depth from the camera's depth texture
            half SampleDepth(float3 worldPos, float3 normal)
            {
                half shadowDepth = 0.0f; // Accumulate weighted shadow depth
                // int additionalLightCount = GetAdditionalLightsCount();
            
                float bestMatchWeight = 0.0f; // Keep track of the strongest matching weight

                // Fade not working, to fix acne
                // float biased = ApplyShadowBias(worldPos, normal, normalize(_SpotLightDir));
            
                for (int i = 0; i < 8; i++)
                {
                    // Fetch light properties
                    Light light = GetAdditionalPerObjectLight(i, worldPos);
                    float3 lightDir = normalize(light.direction);
            
                    // Compute direction similarity (dot product, higher is better)
                    float matchWeight = saturate(dot(lightDir, normalize(_SpotLightDir)));
            
                    // Track the best match (optional if you want a single match result)
                    if (matchWeight > bestMatchWeight)
                    {
                        bestMatchWeight = matchWeight;
                        shadowDepth = AdditionalLightRealtimeShadow(i, worldPos);
                    }
                }

                shadowDepth = saturate(shadowDepth);
                
                // Fade not working, to fix acne
                // half shadowFade = GetAdditionalLightShadowFade(worldPos);
                // shadowDepth *= shadowFade;
                // shadowDepth = max(shadowDepth, 0.2f);
            
                // Optionally, return shadow depth from the best match only
                return shadowDepth;
            }

            // Vertex shader: transforms position and calculates shadow coordinates
            VertexOutput vert(VertexInput v)
            {
                VertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.normalWS = normalize(mul((float3x3)unity_ObjectToWorld, v.normalOS));
                o.shadowCoord = mul(_SpotlightProjectionMatrix, mul(_SpotlightViewMatrix, float4(o.worldPos, 1.0f)));
                return o;
            }

            // Fragment shader: calculates lighting and shadow effect
            float4 frag(VertexOutput i) : SV_TARGET
            {
                float3 toLight = normalize(_SpotLightPos - i.worldPos);

                float normalizedDist = NormalizedDistance(i.worldPos);
                float rangeAttenuation = saturate(InverseSquareFalloff(normalizedDist) * SmoothRange(normalizedDist));
                float angleAttenuation = AngleAttenuation(toLight);

                half shadowDepth = SampleDepth(i.worldPos, i.normalWS);

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                texColor.a *= shadowDepth * rangeAttenuation * angleAttenuation * _Lighted;

                return texColor;
            }
            ENDHLSL
        }
    }
    FallBack "Diffuse"
}
