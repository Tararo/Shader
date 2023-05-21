<<<<<<< HEAD
﻿Shader "TARARO/Filter_DepthToWorld"
{
    Properties
    {
        _Color("Color",Color) = (1.0, 0.0, 0.0, 0.5)
        _Intensity("Intensity", Range(0.0, 1.0)) = 0.1
        _Dark("Dark", Range(0.0, 1.0)) = 0.5
        _Size ("Size", Range(0.0, 1)) = 0.5
        _Range ("Range", Range(0.0, 1.0)) = 1.0
    }
    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 3.0
    #include "UnityCG.cginc"

    UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
    fixed4 _Color;
    float _Intensity;
    float _Dark;
    float _Size;
    float _Range;

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
        float3 normal : NORMAL;
    };

    struct v2f
    {
        float4 vertex : SV_POSITION;
        float2 uv : TEXCOORD0;
        float4 scrPos : TEXCOORD1;
    };

    // inverse matrix(4x4)
    float4x4 inverse (float4x4 i)
    {
        float4x4 o;
        float d = determinant(i);
        o._11 = (  i._22*i._33*i._44 + i._23*i._34*i._42 + i._24*i._32*i._43 - i._24*i._33*i._42 - i._23*i._32*i._44 - i._22*i._34*i._43) / d;
        o._12 = (- i._12*i._33*i._44 - i._13*i._34*i._42 - i._14*i._32*i._43 + i._14*i._33*i._42 + i._13*i._32*i._44 + i._12*i._34*i._43) / d;
        o._13 = (  i._12*i._23*i._44 + i._13*i._24*i._42 + i._14*i._22*i._43 - i._14*i._23*i._42 - i._13*i._22*i._44 - i._12*i._24*i._43) / d;
        o._14 = (- i._12*i._23*i._34 - i._13*i._24*i._32 - i._14*i._22*i._33 + i._14*i._23*i._32 + i._13*i._22*i._34 + i._12*i._24*i._33) / d;
        o._21 = (- i._21*i._33*i._44 - i._23*i._34*i._41 - i._24*i._31*i._43 + i._24*i._33*i._41 + i._23*i._31*i._44 + i._21*i._34*i._43) / d;
        o._22 = (  i._11*i._33*i._44 + i._13*i._34*i._41 + i._14*i._31*i._43 - i._14*i._33*i._41 - i._13*i._31*i._44 - i._11*i._34*i._43) / d;
        o._23 = (- i._11*i._23*i._44 - i._13*i._24*i._41 - i._14*i._21*i._43 + i._14*i._23*i._41 + i._13*i._21*i._44 + i._11*i._24*i._43) / d;
        o._24 = (  i._11*i._23*i._34 + i._13*i._24*i._31 + i._14*i._21*i._33 - i._14*i._23*i._31 - i._13*i._21*i._34 - i._11*i._24*i._33) / d;
        o._31 = (  i._21*i._32*i._44 + i._22*i._34*i._41 + i._24*i._31*i._42 - i._24*i._32*i._41 - i._22*i._31*i._44 - i._21*i._34*i._42) / d;
        o._32 = (- i._11*i._32*i._44 - i._12*i._34*i._41 - i._14*i._31*i._42 + i._14*i._32*i._41 + i._12*i._31*i._44 + i._11*i._34*i._42) / d;
        o._33 = (  i._11*i._22*i._44 + i._12*i._24*i._41 + i._14*i._21*i._42 - i._14*i._22*i._41 - i._12*i._21*i._44 - i._11*i._24*i._42) / d;
        o._34 = (- i._11*i._22*i._34 - i._12*i._24*i._31 - i._14*i._21*i._32 + i._14*i._22*i._31 + i._12*i._21*i._34 + i._11*i._24*i._32) / d;
        o._41 = (- i._21*i._32*i._43 - i._22*i._33*i._41 - i._23*i._31*i._42 + i._23*i._32*i._41 + i._22*i._31*i._43 + i._21*i._33*i._42) / d;
        o._42 = (  i._11*i._32*i._43 + i._12*i._33*i._41 + i._13*i._31*i._42 - i._13*i._32*i._41 - i._12*i._31*i._43 - i._11*i._33*i._42) / d;
        o._43 = (- i._11*i._22*i._43 - i._12*i._23*i._41 - i._13*i._21*i._42 + i._13*i._22*i._41 + i._12*i._21*i._43 + i._11*i._23*i._42) / d;
        o._44 = (  i._11*i._22*i._33 + i._12*i._23*i._31 + i._13*i._21*i._32 - i._13*i._22*i._31 - i._12*i._21*i._33 - i._11*i._23*i._32) / d;
        return o;
    }

    float4 screenToClipPos(float4 pos)
    {
        float4 o = pos;
        #if defined(UNITY_SINGLE_PASS_STEREO)
            float4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
            o.xy = (pos.xy - scaleOffset.zw * pos.w) / scaleOffset.xy;
        #endif
        o.x = (o.x - (pos.w * 0.5)) * 2;
        o.y = (o.y - (pos.w * 0.5)) * _ProjectionParams.x * 2;
        o.zw = pos.zw;
        return o;
    }
    ENDCG


    SubShader
    {
        ZWrite Off
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        LOD 100
        CULL front
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
                o.scrPos = ComputeScreenPos(o.vertex);
                o.uv = v.uv;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
                float sampleDepth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.scrPos));
                float depth = LinearEyeDepth(sampleDepth);
                float4 depthScrPos = float4(i.scrPos.x, i.scrPos.y, sampleDepth * i.scrPos.w, i.scrPos.w);
                float4 clipPos = screenToClipPos(depthScrPos);
                float4 worldPos = mul(inverse(UNITY_MATRIX_VP), clipPos);
                worldPos.xyz /= worldPos.w;

                float lineWidth = 0.1;
                float colorDiff = 1 - max((abs(fmod(abs(worldPos.x / (1 - _Size * 0.95)), 2) - 1) + lineWidth - 1), 0) / lineWidth;
                colorDiff *= 1 - max((abs(fmod(abs(worldPos.y / (1 - _Size * 0.95)), 2) - 1) + lineWidth - 1), 0) / lineWidth;
                colorDiff *= 1 - max((abs(fmod(abs(worldPos.z / (1 - _Size * 0.95)), 2) - 1) + lineWidth - 1), 0) / lineWidth;
                colorDiff = saturate(1- colorDiff);
                colorDiff *= saturate(((_Range * 100) - depth) / 10);

                float intensityDiff = saturate((colorDiff - 1 + _Intensity) * 2);

                fixed4 fragColor = fixed4(0, 0, 0, 1);
                float dark = 0.01 + 0.99 * _Dark;
                fragColor.rgb = ((_Color.rgb * _Color.a * colorDiff) + (1 * intensityDiff)) / dark;
                fragColor.a = dark;

				return fragColor;
			}
            ENDCG
        }
    }
}
=======
﻿Shader "TARARO/Filter_DepthToWorld"
{
    Properties
    {
        _Color("Color",Color) = (1.0, 0.0, 0.0, 0.5)
        _Intensity("Intensity", Range(0.0, 1.0)) = 0.1
        _Dark("Dark", Range(0.0, 1.0)) = 0.5
        _Size ("Size", Range(0.0, 1)) = 0.5
        _Range ("Range", Range(0.0, 1.0)) = 1.0
    }
    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 3.0
    #include "UnityCG.cginc"

    UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
    fixed4 _Color;
    float _Intensity;
    float _Dark;
    float _Size;
    float _Range;

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
        float3 normal : NORMAL;
    };

    struct v2f
    {
        float4 vertex : SV_POSITION;
        float2 uv : TEXCOORD0;
        float4 scrPos : TEXCOORD1;
    };

    // inverse matrix(4x4)
    float4x4 inverse (float4x4 i)
    {
        float4x4 o;
        float d = determinant(i);
        o._11 = (  i._22*i._33*i._44 + i._23*i._34*i._42 + i._24*i._32*i._43 - i._24*i._33*i._42 - i._23*i._32*i._44 - i._22*i._34*i._43) / d;
        o._12 = (- i._12*i._33*i._44 - i._13*i._34*i._42 - i._14*i._32*i._43 + i._14*i._33*i._42 + i._13*i._32*i._44 + i._12*i._34*i._43) / d;
        o._13 = (  i._12*i._23*i._44 + i._13*i._24*i._42 + i._14*i._22*i._43 - i._14*i._23*i._42 - i._13*i._22*i._44 - i._12*i._24*i._43) / d;
        o._14 = (- i._12*i._23*i._34 - i._13*i._24*i._32 - i._14*i._22*i._33 + i._14*i._23*i._32 + i._13*i._22*i._34 + i._12*i._24*i._33) / d;
        o._21 = (- i._21*i._33*i._44 - i._23*i._34*i._41 - i._24*i._31*i._43 + i._24*i._33*i._41 + i._23*i._31*i._44 + i._21*i._34*i._43) / d;
        o._22 = (  i._11*i._33*i._44 + i._13*i._34*i._41 + i._14*i._31*i._43 - i._14*i._33*i._41 - i._13*i._31*i._44 - i._11*i._34*i._43) / d;
        o._23 = (- i._11*i._23*i._44 - i._13*i._24*i._41 - i._14*i._21*i._43 + i._14*i._23*i._41 + i._13*i._21*i._44 + i._11*i._24*i._43) / d;
        o._24 = (  i._11*i._23*i._34 + i._13*i._24*i._31 + i._14*i._21*i._33 - i._14*i._23*i._31 - i._13*i._21*i._34 - i._11*i._24*i._33) / d;
        o._31 = (  i._21*i._32*i._44 + i._22*i._34*i._41 + i._24*i._31*i._42 - i._24*i._32*i._41 - i._22*i._31*i._44 - i._21*i._34*i._42) / d;
        o._32 = (- i._11*i._32*i._44 - i._12*i._34*i._41 - i._14*i._31*i._42 + i._14*i._32*i._41 + i._12*i._31*i._44 + i._11*i._34*i._42) / d;
        o._33 = (  i._11*i._22*i._44 + i._12*i._24*i._41 + i._14*i._21*i._42 - i._14*i._22*i._41 - i._12*i._21*i._44 - i._11*i._24*i._42) / d;
        o._34 = (- i._11*i._22*i._34 - i._12*i._24*i._31 - i._14*i._21*i._32 + i._14*i._22*i._31 + i._12*i._21*i._34 + i._11*i._24*i._32) / d;
        o._41 = (- i._21*i._32*i._43 - i._22*i._33*i._41 - i._23*i._31*i._42 + i._23*i._32*i._41 + i._22*i._31*i._43 + i._21*i._33*i._42) / d;
        o._42 = (  i._11*i._32*i._43 + i._12*i._33*i._41 + i._13*i._31*i._42 - i._13*i._32*i._41 - i._12*i._31*i._43 - i._11*i._33*i._42) / d;
        o._43 = (- i._11*i._22*i._43 - i._12*i._23*i._41 - i._13*i._21*i._42 + i._13*i._22*i._41 + i._12*i._21*i._43 + i._11*i._23*i._42) / d;
        o._44 = (  i._11*i._22*i._33 + i._12*i._23*i._31 + i._13*i._21*i._32 - i._13*i._22*i._31 - i._12*i._21*i._33 - i._11*i._23*i._32) / d;
        return o;
    }

    float4 screenToClipPos(float4 pos)
    {
        float4 o = pos;
        #if defined(UNITY_SINGLE_PASS_STEREO)
            float4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
            o.xy = (pos.xy - scaleOffset.zw * pos.w) / scaleOffset.xy;
        #endif
        o.x = (o.x - (pos.w * 0.5)) * 2;
        o.y = (o.y - (pos.w * 0.5)) * _ProjectionParams.x * 2;
        o.zw = pos.zw;
        return o;
    }
    ENDCG


    SubShader
    {
        ZWrite Off
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        LOD 100
        CULL front
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
                o.scrPos = ComputeScreenPos(o.vertex);
                o.uv = v.uv;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
                float sampleDepth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.scrPos));
                float depth = LinearEyeDepth(sampleDepth);
                float4 depthScrPos = float4(i.scrPos.x, i.scrPos.y, sampleDepth * i.scrPos.w, i.scrPos.w);
                float4 clipPos = screenToClipPos(depthScrPos);
                float4 worldPos = mul(inverse(UNITY_MATRIX_VP), clipPos);
                worldPos.xyz /= worldPos.w;

                float lineWidth = 0.1;
                float colorDiff = 1 - max((abs(fmod(abs(worldPos.x / (1 - _Size * 0.95)), 2) - 1) + lineWidth - 1), 0) / lineWidth;
                colorDiff *= 1 - max((abs(fmod(abs(worldPos.y / (1 - _Size * 0.95)), 2) - 1) + lineWidth - 1), 0) / lineWidth;
                colorDiff *= 1 - max((abs(fmod(abs(worldPos.z / (1 - _Size * 0.95)), 2) - 1) + lineWidth - 1), 0) / lineWidth;
                colorDiff = saturate(1- colorDiff);
                colorDiff *= saturate(((_Range * 100) - depth) / 10);

                float intensityDiff = saturate((colorDiff - 1 + _Intensity) * 2);

                fixed4 fragColor = fixed4(0, 0, 0, 1);
                float dark = 0.01 + 0.99 * _Dark;
                fragColor.rgb = ((_Color.rgb * _Color.a * colorDiff) + (1 * intensityDiff)) / dark;
                fragColor.a = dark;

				return fragColor;
			}
            ENDCG
        }
    }
}
>>>>>>> origin/main
