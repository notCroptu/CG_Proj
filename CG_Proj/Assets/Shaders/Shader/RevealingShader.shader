Shader "Custom/RevealingShader"
{
    Properties
    {
        _MainTex ("Texture to be Revealed", 2D) = "white" {}
        _Green ("Green - Phosphorescence", Range(0, 1)) = 1
        _Blue ("Blue - Fluorescence", Range(0, 1)) = 1
        _AlphaClip ("Alpha Clip", Range(0, 1)) = 0.01
        _Emission ("Emission", Range(0, 100)) = 4.0
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "UniversalMaterialType" = "Lit"
            "Queue" = "Transparent"
        }
        Pass
        {
            Name "NormalPass"
            Tags { "LightMode" = "UniversalForward" }
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha
            ZTest LEqual
            ZWrite Off
            

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #pragma multi_compile_fog
            
            #define MAX_ADDITIONAL_LIGHTS 4

            uniform float _LightRange;
            uniform float3 _SpotLightDir;
            uniform float _LightStrengthIntensity;
            uniform float _InnerSpotAngle;
            uniform float _OuterSpotAngle;
            uniform float _Lighted;
            uniform float3 _SpotLightPos;

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_AlphaDelay);
            SAMPLER(sampler_AlphaDelay);
            half _Green;
            half _Blue;
            float _AlphaClip;
            half _Emission;


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
                float4 screenPos : TEXCOORD3;
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
            float AngleAttenuation(float3 lightDir, float outer, float inner)
            {
                lightDir = normalize(lightDir);
                float angle = dot(lightDir, normalize(_SpotLightDir));
                return smoothstep(outer, inner, angle);
            }
            
            // Sample depth from URP Additional Lights
            half SampleDepth(float3 worldPos, float3 normal)
            {
                half shadowDepth = 0.0f; // Accumulate weighted shadow depth
                half reverseShadowDepth = 0.0f;
            
                float bestMatchWeight = 0.0f; // Keep track of the strongest matching weight, and give it a minimum
            
                for (int i = 0; i < 4; i++)
                {
                    // Fetch light properties
                    Light light = GetAdditionalPerObjectLight(i, worldPos);
                    float3 lightDir = normalize(light.direction);
            
                    // Compute direction similarity (dot product, higher is better)
                    float matchWeight = saturate(dot(lightDir, normalize(_SpotLightDir)));
            
                    // Track the best match, if any
                    if (matchWeight > bestMatchWeight)
                    {
                        bestMatchWeight = matchWeight;
                        shadowDepth = AdditionalLightRealtimeShadow(i, worldPos);
                    }
                }

                shadowDepth = saturate(shadowDepth);
            
                return shadowDepth;
            }


            float4x4 _MainCameraViewProj;
            float _AlphaDelayWidth;
            float _AlphaDelayHeight;

            half CalculateDelay(half4 color)
            {
                half diff = abs(color.g - color.b);
                half rate = 1.0 - diff;
                rate = clamp(rate, 0.0, 0.999);
            
                return rate;
            }

            half4 GetColor()
            {
                return half4(0, _Green, _Blue, 1);
            }

            // Vertex shader: transforms position and calculates shadow coordinates
            VertexOutput vert(VertexInput v)
            {
                VertexOutput o;
                o.pos = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.normalWS = normalize(mul((float3x3)unity_ObjectToWorld, v.normalOS));

                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

            // Fragment shader: calculates lighting and shadow effect
            float4 frag(VertexOutput i) : SV_TARGET
            {
                float3 toLight = normalize(_SpotLightPos - i.worldPos);

                float normalizedDist = NormalizedDistance(i.worldPos);
                float rangeAttenuation =  (InverseSquareFalloff(normalizedDist) * SmoothRange(normalizedDist));
                float angleAttenuation = AngleAttenuation(toLight, _OuterSpotAngle, _InnerSpotAngle);

                half shadowDepth = SampleDepth(i.worldPos, i.normalWS);

                half4 color = GetColor();

                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * color;
                texColor.a *= shadowDepth * rangeAttenuation * angleAttenuation;

                // Unused phosphorescence and fluorescence calculations

                /*float2 adjustedUV = i.screenPos.xy / i.screenPos.x * 0.5 + 0.5;
                adjustedUV.x *= _AlphaDelayWidth / _ScreenParams.x;
                adjustedUV.y *= _AlphaDelayHeight / _ScreenParams.y;

                half4 delayedAlpha = SAMPLE_TEXTURE2D(_AlphaDelay, sampler_AlphaDelay, adjustedUV);

                half rate = CalculateDelay(color);
                // half scaled = 10 / unity_DeltaTime; // It doesn't work as expected but gives a cool flickering effect.
                half newRate = 100000000000000.0 / 0.016 * (exp(delayedAlpha.a * rate) -1.0);
                texColor.a += newRate;

                // texColor.r += 1 - delayedAlpha.a;

                // texColor.a = delayedAlpha.a;

                // Delayed alpha screen position debug
                if (delayedAlpha.a > 0.2)
                    texColor = half4(1,0,0,1);*/

                texColor.a = saturate(texColor.a);

                texColor.rgb *= pow( _Emission, texColor.a) -1;

                return texColor;
            }
            ENDHLSL
        }
    }
}
