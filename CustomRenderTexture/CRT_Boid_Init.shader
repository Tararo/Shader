Shader "Hidden/CRT_boid_init"
{
    Properties
    {
        _Area("Area Size", Float) = 10
    }

    CGINCLUDE
        #include "UnityCustomRenderTexture.cginc"

        float _Area;

        // 乱数
        float3 rand(float x)
        {
            return frac(sin(x * float3(12.9898,78.233,40.847)) * 43758.5453) - 0.5;
        }

        // フラグメントシェーダー(更新)
        float4 InitFrag(v2f_init_customrendertexture i) : SV_Target
        {
            float2 uv = i.texcoord;

            // 1pxあたりの単位を計算する
            float du = 1.0 / _CustomRenderTextureWidth;
            float dv = 1.0 / _CustomRenderTextureHeight;

            // 現在の位置のindex(0~31)を算出
            int index = (int)(fmod(uv.y, 0.5) / dv) * 8 + (int)(uv.x / du);

            // 座標,速度の初期値算出
            float3 veloc = 0;
            float3 coord = rand(index + _Time.y) * _Area;

            // 書き込み
            return float4(veloc * step(0.5, uv.y) + coord * step(uv.y, 0.5), 0);
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
}