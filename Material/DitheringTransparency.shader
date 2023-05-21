<<<<<<< HEAD
﻿Shader "TARARO/DitheringTransparency"
{
	Properties
    {
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,1)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.1
            _Specular("Specular", Range(0.0, 1.0)) = 0.5
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 50
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.2
        [Header(Dithering)]
            _Size ("Size", Range(0.0, 1.0)) = 0.25
            _NearClip ("Near Clip", Float) = 0.2
            _FarClip ("Far Clip", Float) = 3
	}

    CGINCLUDE
    #pragma target 3.0
    #pragma vertex vert
    #pragma fragment frag

    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"

    float4 _Color;
    float _Ambient;
    float _Specular;
    float _SpecularPow;
    float _Reflect;
    float _Size;
    float _NearClip;
    float _FarClip;

    float isEqual(float x, float y)
    {
        return step(x, y) * step(y, x);
    }

    // Box Projectionを考慮した反射ベクトルを取得
    float3 boxProjection(float3 normalizedDir, float3 worldPosition, float4 probePosition, float3 boxMin, float3 boxMax)
    {
        // GraphicsSettingsのReflection Probes Box Projectionが有効な場合のみtrue
        #if UNITY_SPECCUBE_BOX_PROJECTION
            // Box Projectionが有効な場合はprobePosition.w > 0となる
            if (probePosition.w > 0) {
                float3 magnitudes = ((normalizedDir > 0 ? boxMax : boxMin) - worldPosition) / normalizedDir;
                float magnitude = min(min(magnitudes.x, magnitudes.y), magnitudes.z);
                normalizedDir = normalizedDir * magnitude + (worldPosition - probePosition);
            }
        #endif

        return normalizedDir;
    }

    // Reflection Probeから反射色を取得
    float4 refProbe(float3 reflectDirection, float3 worldPosition)
    {
        // Box Projection
        half3 refDir0 = boxProjection(reflectDirection, worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        half3 refDir1 = boxProjection(reflectDirection, worldPosition, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
        // SpecCube0
        float4 refColor0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, refDir0, 0);
        refColor0.rgb = DecodeHDR(refColor0, unity_SpecCube0_HDR);
        // SpecCube1
        float4 refColor1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, refDir1, 0);
        refColor1.rgb = DecodeHDR(refColor1, unity_SpecCube1_HDR);

        // unity_SpecCube0_BoxMin.w にブレンド率が入ってくる
        return lerp(refColor1, refColor0, unity_SpecCube0_BoxMin.w);
    }

    float bayerMatrix(float2 uv)
    {
        float bayer = 
            ( 1.0 / 17.0) * isEqual(uv.x, 0) * isEqual(uv.y, 0) +
            ( 9.0 / 17.0) * isEqual(uv.x, 1) * isEqual(uv.y, 0) +
            ( 3.0 / 17.0) * isEqual(uv.x, 2) * isEqual(uv.y, 0) +
            (11.0 / 17.0) * isEqual(uv.x, 3) * isEqual(uv.y, 0) +
            (13.0 / 17.0) * isEqual(uv.x, 0) * isEqual(uv.y, 1) +
            ( 5.0 / 17.0) * isEqual(uv.x, 1) * isEqual(uv.y, 1) +
            (15.0 / 17.0) * isEqual(uv.x, 2) * isEqual(uv.y, 1) +
            ( 7.0 / 17.0) * isEqual(uv.x, 3) * isEqual(uv.y, 1) +
            ( 4.0 / 17.0) * isEqual(uv.x, 0) * isEqual(uv.y, 2) +
            (12.0 / 17.0) * isEqual(uv.x, 1) * isEqual(uv.y, 2) +
            ( 2.0 / 17.0) * isEqual(uv.x, 2) * isEqual(uv.y, 2) +
            (10.0 / 17.0) * isEqual(uv.x, 3) * isEqual(uv.y, 2) +
            (16.0 / 17.0) * isEqual(uv.x, 0) * isEqual(uv.y, 3) +
            ( 8.0 / 17.0) * isEqual(uv.x, 1) * isEqual(uv.y, 3) +
            (14.0 / 17.0) * isEqual(uv.x, 2) * isEqual(uv.y, 3) +
            ( 6.0 / 17.0) * isEqual(uv.x, 3) * isEqual(uv.y, 3);
        return bayer;
    }

    struct appdata
    {
        float4 vertex : POSITION;
        half3 normal : NORMAL;
    };

    struct v2f
    {
        float4 pos : SV_POSITION;
        half3 normal : TEXCOORD0;
        float4 worldPos : TEXCOORD1;
        float4 scrPos : TEXCOORD2;
    };

    ENDCG
	
	SubShader
	{
		Tags
        {
            "RenderType" = "Opaque"
        }
		LOD 100
		Pass
		{
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            Cull Off
			CGPROGRAM

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.scrPos = ComputeScreenPos(o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 法線
                float3 normal = i.normal;
                // 視線の向き
                float3 cameraPos = _WorldSpaceCameraPos;
                #if defined(USING_STEREO_MATRICES)
                    cameraPos = (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * 0.5;
                #endif
                float3 eyeDir = normalize(i.worldPos - cameraPos);
                // 光源
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 lightColor = _LightColor0;
                if(isnan(lightDir.x))
                {
                    lightDir = normalize(float3(1, 1, 1));
                    lightColor = float3(1, 1, 1);
                }

                // ディザ抜き
                float2 size = float2(_Size * 0.01, _Size * 0.01);
                size.y *= _ScreenParams.x / _ScreenParams.y;
                float2 scrUv = i.scrPos.xy / i.scrPos.w;
                float2 ditUv = floor(fmod(scrUv/size,4));
                float bayer = bayerMatrix(ditUv);
                // 距離からclip
                float dist = length(i.worldPos - cameraPos);
                dist = smoothstep(_NearClip, _NearClip + 1, dist) * (1 - smoothstep(_FarClip, _FarClip + 1, dist));
                clip(dist - bayer);

                // 環境光
                half3 ambColor = ShadeSH9(half4(normal, 1));
                // ランバート反射
                float3 difColor = saturate(dot(normal, lightDir)) * lightColor;
                // フォン鏡面反射
                float3 refLightVec = reflect(lightDir, normal);
                float3 speColor = pow(saturate(dot(refLightVec, eyeDir)), _SpecularPow) * lightColor;
                // 反射
                float3 refViewVec = normalize(reflect(eyeDir, normal));
                float4 refColor = refProbe(refViewVec, i.worldPos);

                // 出力色
                fixed4 fragColor = fixed4(0,0,0,1);
                fragColor.rgb = _Color * lerp(difColor, ambColor, _Ambient);
                fragColor.rgb += ambColor * _Ambient;
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, _Reflect);
                fragColor.rgb += speColor  * _Specular;

                return fragColor;
            }
			ENDCG
		}
	}
=======
﻿Shader "TARARO/DitheringTransparency"
{
	Properties
    {
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,1)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.1
            _Specular("Specular", Range(0.0, 1.0)) = 0.5
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 50
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.2
        [Header(Dithering)]
            _Size ("Size", Range(0.0, 1.0)) = 0.25
            _NearClip ("Near Clip", Float) = 0.2
            _FarClip ("Far Clip", Float) = 3
	}

    CGINCLUDE
    #pragma target 3.0
    #pragma vertex vert
    #pragma fragment frag

    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"

    float4 _Color;
    float _Ambient;
    float _Specular;
    float _SpecularPow;
    float _Reflect;
    float _Size;
    float _NearClip;
    float _FarClip;

    float isEqual(float x, float y)
    {
        return step(x, y) * step(y, x);
    }

    // Box Projectionを考慮した反射ベクトルを取得
    float3 boxProjection(float3 normalizedDir, float3 worldPosition, float4 probePosition, float3 boxMin, float3 boxMax)
    {
        // GraphicsSettingsのReflection Probes Box Projectionが有効な場合のみtrue
        #if UNITY_SPECCUBE_BOX_PROJECTION
            // Box Projectionが有効な場合はprobePosition.w > 0となる
            if (probePosition.w > 0) {
                float3 magnitudes = ((normalizedDir > 0 ? boxMax : boxMin) - worldPosition) / normalizedDir;
                float magnitude = min(min(magnitudes.x, magnitudes.y), magnitudes.z);
                normalizedDir = normalizedDir * magnitude + (worldPosition - probePosition);
            }
        #endif

        return normalizedDir;
    }

    // Reflection Probeから反射色を取得
    float4 refProbe(float3 reflectDirection, float3 worldPosition)
    {
        // Box Projection
        half3 refDir0 = boxProjection(reflectDirection, worldPosition, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        half3 refDir1 = boxProjection(reflectDirection, worldPosition, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
        // SpecCube0
        float4 refColor0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, refDir0, 0);
        refColor0.rgb = DecodeHDR(refColor0, unity_SpecCube0_HDR);
        // SpecCube1
        float4 refColor1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, refDir1, 0);
        refColor1.rgb = DecodeHDR(refColor1, unity_SpecCube1_HDR);

        // unity_SpecCube0_BoxMin.w にブレンド率が入ってくる
        return lerp(refColor1, refColor0, unity_SpecCube0_BoxMin.w);
    }

    float bayerMatrix(float2 uv)
    {
        float bayer = 
            ( 1.0 / 17.0) * isEqual(uv.x, 0) * isEqual(uv.y, 0) +
            ( 9.0 / 17.0) * isEqual(uv.x, 1) * isEqual(uv.y, 0) +
            ( 3.0 / 17.0) * isEqual(uv.x, 2) * isEqual(uv.y, 0) +
            (11.0 / 17.0) * isEqual(uv.x, 3) * isEqual(uv.y, 0) +
            (13.0 / 17.0) * isEqual(uv.x, 0) * isEqual(uv.y, 1) +
            ( 5.0 / 17.0) * isEqual(uv.x, 1) * isEqual(uv.y, 1) +
            (15.0 / 17.0) * isEqual(uv.x, 2) * isEqual(uv.y, 1) +
            ( 7.0 / 17.0) * isEqual(uv.x, 3) * isEqual(uv.y, 1) +
            ( 4.0 / 17.0) * isEqual(uv.x, 0) * isEqual(uv.y, 2) +
            (12.0 / 17.0) * isEqual(uv.x, 1) * isEqual(uv.y, 2) +
            ( 2.0 / 17.0) * isEqual(uv.x, 2) * isEqual(uv.y, 2) +
            (10.0 / 17.0) * isEqual(uv.x, 3) * isEqual(uv.y, 2) +
            (16.0 / 17.0) * isEqual(uv.x, 0) * isEqual(uv.y, 3) +
            ( 8.0 / 17.0) * isEqual(uv.x, 1) * isEqual(uv.y, 3) +
            (14.0 / 17.0) * isEqual(uv.x, 2) * isEqual(uv.y, 3) +
            ( 6.0 / 17.0) * isEqual(uv.x, 3) * isEqual(uv.y, 3);
        return bayer;
    }

    struct appdata
    {
        float4 vertex : POSITION;
        half3 normal : NORMAL;
    };

    struct v2f
    {
        float4 pos : SV_POSITION;
        half3 normal : TEXCOORD0;
        float4 worldPos : TEXCOORD1;
        float4 scrPos : TEXCOORD2;
    };

    ENDCG
	
	SubShader
	{
		Tags
        {
            "RenderType" = "Opaque"
        }
		LOD 100
		Pass
		{
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            Cull Off
			CGPROGRAM

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.scrPos = ComputeScreenPos(o.pos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 法線
                float3 normal = i.normal;
                // 視線の向き
                float3 cameraPos = _WorldSpaceCameraPos;
                #if defined(USING_STEREO_MATRICES)
                    cameraPos = (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * 0.5;
                #endif
                float3 eyeDir = normalize(i.worldPos - cameraPos);
                // 光源
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 lightColor = _LightColor0;
                if(isnan(lightDir.x))
                {
                    lightDir = normalize(float3(1, 1, 1));
                    lightColor = float3(1, 1, 1);
                }

                // ディザ抜き
                float2 size = float2(_Size * 0.01, _Size * 0.01);
                size.y *= _ScreenParams.x / _ScreenParams.y;
                float2 scrUv = i.scrPos.xy / i.scrPos.w;
                float2 ditUv = floor(fmod(scrUv/size,4));
                float bayer = bayerMatrix(ditUv);
                // 距離からclip
                float dist = length(i.worldPos - cameraPos);
                dist = smoothstep(_NearClip, _NearClip + 1, dist) * (1 - smoothstep(_FarClip, _FarClip + 1, dist));
                clip(dist - bayer);

                // 環境光
                half3 ambColor = ShadeSH9(half4(normal, 1));
                // ランバート反射
                float3 difColor = saturate(dot(normal, lightDir)) * lightColor;
                // フォン鏡面反射
                float3 refLightVec = reflect(lightDir, normal);
                float3 speColor = pow(saturate(dot(refLightVec, eyeDir)), _SpecularPow) * lightColor;
                // 反射
                float3 refViewVec = normalize(reflect(eyeDir, normal));
                float4 refColor = refProbe(refViewVec, i.worldPos);

                // 出力色
                fixed4 fragColor = fixed4(0,0,0,1);
                fragColor.rgb = _Color * lerp(difColor, ambColor, _Ambient);
                fragColor.rgb += ambColor * _Ambient;
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, _Reflect);
                fragColor.rgb += speColor  * _Specular;

                return fragColor;
            }
			ENDCG
		}
	}
>>>>>>> origin/main
}