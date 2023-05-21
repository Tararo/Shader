<<<<<<< HEAD
﻿Shader "Hidden/CRT_GameOfLife_init"
{
    Properties
    {

    }

    CGINCLUDE
        #include "UnityCustomRenderTexture.cginc"

        // 乱数
        float rand(float x)
        {
            return frac(sin(x * 12.9898) * 43758.5453) - 0.5;
        }

        // フラグメントシェーダー(更新)
        float4 InitFrag(v2f_init_customrendertexture i) : SV_Target
        {
            float2 uv = i.texcoord;

            //1pxあたりの単位を計算する
            float du = 1.0 / _CustomRenderTextureWidth;
            float dv = 1.0 / _CustomRenderTextureHeight;

            //現在の位置の座標index(xy)を算出
            int index = (int)(uv.y / dv) * _CustomRenderTextureWidth + (int)(uv.x / du);

            //int(0,1)の算出
            int cellNew = step(rand(index + _Time.y), 0);

            // 書き込み
            return float4(cellNew,0,0,1);
        }
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            Name "Init"
            CGPROGRAM
            #pragma vertex InitCustomRenderTextureVertexShader
            #pragma fragment InitFrag
            ENDCG
        }
    }
=======
﻿Shader "Hidden/CRT_GameOfLife_init"
{
    Properties
    {

    }

    CGINCLUDE
        #include "UnityCustomRenderTexture.cginc"

        // 乱数
        float rand(float x)
        {
            return frac(sin(x * 12.9898) * 43758.5453) - 0.5;
        }

        // フラグメントシェーダー(更新)
        float4 InitFrag(v2f_init_customrendertexture i) : SV_Target
        {
            float2 uv = i.texcoord;

            //1pxあたりの単位を計算する
            float du = 1.0 / _CustomRenderTextureWidth;
            float dv = 1.0 / _CustomRenderTextureHeight;

            //現在の位置の座標index(xy)を算出
            int index = (int)(uv.y / dv) * _CustomRenderTextureWidth + (int)(uv.x / du);

            //int(0,1)の算出
            int cellNew = step(rand(index + _Time.y), 0);

            // 書き込み
            return float4(cellNew,0,0,1);
        }
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            Name "Init"
            CGPROGRAM
            #pragma vertex InitCustomRenderTextureVertexShader
            #pragma fragment InitFrag
            ENDCG
        }
    }
>>>>>>> origin/main
}