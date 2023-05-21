<<<<<<< HEAD
﻿Shader "TARARO/GridTexture"
{
	Properties
    {
        [Header(Main)]
            _BGColor("Background Color", Color) = (0,0,0,1)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.1
            _Specular("Specular", Range(0.0, 1.0)) = 0.5
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 4
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.25
        [Header(Grid)]
            _GridColor("Grid Color", Color) = (0.25,0.25,0.5,1)
            _GridSize ("Grid Size", Range(0.0, 1.0)) = 0.1
            _GridSpeed ("Grid Speed", Float) = (0.25, 0, 0.1)
            _GridWidth ("Grid Width", Range(0.0, 1.0)) = 0.02
        [Header(Dot)]
            _DotColor("Dot Color", Color) = (0.5,0.5,0.75,0.5)
            _DotSize ("Dot Size", Range(0.0, 1.0)) = 0.1
            _DotSpeed ("Dot Speed", Float) = (0.3, 0, 0.15)
            _DotDensity ("Dot Density", Range(0.0, 1.0)) = 0.5
	}

    CGINCLUDE
    #pragma target 3.0
    #pragma vertex vert
    #pragma fragment frag

    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"

    float4 _BGColor;
    float _Ambient;
    float _Specular;
    float _SpecularPow;
    float _Reflect;
    float4 _GridColor;
    float _GridSize;
    float3 _GridSpeed;
    float _GridWidth;
    float4 _DotColor;
    float _DotSize;
    float3 _DotSpeed;
    float _DotDensity;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
    }

    float3 random3 (float3 st)
    {
        st = float3(dot(st, float3(127.7, 311.9, 208.1)), dot(st, float3(269.3, 214.3, 183.1)), dot(st, float3(118.1, 153.1, 370.9)));
        return frac(sin(st) * 43758.5453123);
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

    struct appdata
    {
        float4 vertex : POSITION;
        half3 normal : NORMAL;
        half4 tangent : TANGENT;
    };

    struct v2f
    {
        float4 pos : SV_POSITION;
        half3 normal : TEXCOORD0; //法線
        half3 tangent : TEXCOORD1; //接線
        half3 binormal : TEXCOORD2; //従法線
        float4 worldPos : TEXCOORD3;
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
			CGPROGRAM

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 柄
                float3 pattern = _BGColor.rgb;
                // 重み算出
                float3 weights = 1 - abs(i.normal);
                weights /= weights.x + weights.y + weights.z;
                // Grid
                float3 gridPos = i.worldPos.xyz + _GridSpeed * _Time.x;
                gridPos = fmod(gridPos, _GridSize) - (_GridSize * 0.5) + _GridSize * step(gridPos, 0);
                gridPos = (_GridSize * 0.5) - abs(gridPos);
                float width = _GridSize * _GridWidth * 0.5;
                float gridFlag = (1 - step(width, gridPos.x)) * weights.x;
                gridFlag = max(gridFlag, (1 - step(width, gridPos.y)) * weights.y);
                gridFlag = max(gridFlag, (1 - step(width, gridPos.z)) * weights.z);
                // Dot
                float3 dotPos = i.worldPos.xyz + _DotSpeed * _Time.x;
                dotPos = floor(dotPos / _DotSize);
                float dotFlag = step(dot(random3(dotPos), float3(1,1,1)) / 3, _DotDensity);

                pattern = gridFlag * _GridColor.a * _GridColor.rgb + (1 - gridFlag * _GridColor.a) * pattern;
                pattern = dotFlag * _DotColor.a * _DotColor.rgb + (1 - dotFlag * _DotColor.a) * pattern;

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
                if(IsNaN(lightDir.x))
                {
                    lightDir = normalize(float3(1, 1, 1));
                    lightColor = float3(1, 1, 1);
                }

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
                fragColor.rgb = pattern * lerp(difColor, ambColor, _Ambient);
                fragColor.rgb += ambColor * _Ambient;
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, _Reflect);
                fragColor.rgb += speColor  * _Specular;

                return fragColor;
            }
			ENDCG
		}

        UsePass "Standard/ShadowCaster"
	}
=======
﻿Shader "TARARO/GridTexture"
{
	Properties
    {
        [Header(Main)]
            _BGColor("Background Color", Color) = (0,0,0,1)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.1
            _Specular("Specular", Range(0.0, 1.0)) = 0.5
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 4
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.25
        [Header(Grid)]
            _GridColor("Grid Color", Color) = (0.25,0.25,0.5,1)
            _GridSize ("Grid Size", Range(0.0, 1.0)) = 0.1
            _GridSpeed ("Grid Speed", Float) = (0.25, 0, 0.1)
            _GridWidth ("Grid Width", Range(0.0, 1.0)) = 0.02
        [Header(Dot)]
            _DotColor("Dot Color", Color) = (0.5,0.5,0.75,0.5)
            _DotSize ("Dot Size", Range(0.0, 1.0)) = 0.1
            _DotSpeed ("Dot Speed", Float) = (0.3, 0, 0.15)
            _DotDensity ("Dot Density", Range(0.0, 1.0)) = 0.5
	}

    CGINCLUDE
    #pragma target 3.0
    #pragma vertex vert
    #pragma fragment frag

    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"

    float4 _BGColor;
    float _Ambient;
    float _Specular;
    float _SpecularPow;
    float _Reflect;
    float4 _GridColor;
    float _GridSize;
    float3 _GridSpeed;
    float _GridWidth;
    float4 _DotColor;
    float _DotSize;
    float3 _DotSpeed;
    float _DotDensity;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
    }

    float3 random3 (float3 st)
    {
        st = float3(dot(st, float3(127.7, 311.9, 208.1)), dot(st, float3(269.3, 214.3, 183.1)), dot(st, float3(118.1, 153.1, 370.9)));
        return frac(sin(st) * 43758.5453123);
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

    struct appdata
    {
        float4 vertex : POSITION;
        half3 normal : NORMAL;
        half4 tangent : TANGENT;
    };

    struct v2f
    {
        float4 pos : SV_POSITION;
        half3 normal : TEXCOORD0; //法線
        half3 tangent : TEXCOORD1; //接線
        half3 binormal : TEXCOORD2; //従法線
        float4 worldPos : TEXCOORD3;
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
			CGPROGRAM

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 柄
                float3 pattern = _BGColor.rgb;
                // 重み算出
                float3 weights = 1 - abs(i.normal);
                weights /= weights.x + weights.y + weights.z;
                // Grid
                float3 gridPos = i.worldPos.xyz + _GridSpeed * _Time.x;
                gridPos = fmod(gridPos, _GridSize) - (_GridSize * 0.5) + _GridSize * step(gridPos, 0);
                gridPos = (_GridSize * 0.5) - abs(gridPos);
                float width = _GridSize * _GridWidth * 0.5;
                float gridFlag = (1 - step(width, gridPos.x)) * weights.x;
                gridFlag = max(gridFlag, (1 - step(width, gridPos.y)) * weights.y);
                gridFlag = max(gridFlag, (1 - step(width, gridPos.z)) * weights.z);
                // Dot
                float3 dotPos = i.worldPos.xyz + _DotSpeed * _Time.x;
                dotPos = floor(dotPos / _DotSize);
                float dotFlag = step(dot(random3(dotPos), float3(1,1,1)) / 3, _DotDensity);

                pattern = gridFlag * _GridColor.a * _GridColor.rgb + (1 - gridFlag * _GridColor.a) * pattern;
                pattern = dotFlag * _DotColor.a * _DotColor.rgb + (1 - dotFlag * _DotColor.a) * pattern;

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
                if(IsNaN(lightDir.x))
                {
                    lightDir = normalize(float3(1, 1, 1));
                    lightColor = float3(1, 1, 1);
                }

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
                fragColor.rgb = pattern * lerp(difColor, ambColor, _Ambient);
                fragColor.rgb += ambColor * _Ambient;
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, _Reflect);
                fragColor.rgb += speColor  * _Specular;

                return fragColor;
            }
			ENDCG
		}

        UsePass "Standard/ShadowCaster"
	}
>>>>>>> origin/main
}