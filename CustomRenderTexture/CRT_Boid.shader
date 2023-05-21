Shader "Hidden/CRT_boid"
{
    Properties
    {
        _Speed("Speed", Float) = 0.1
        _MinSpeed("Min Speed", Float) = 0.05
        _MaxSpeed("Max Speed", Float) = 1.0
        _Area("Area Size", Float) = 1
        _InfRad("Influence Area Size", Float) = 0.25
        _ForceC("Cohesion Force", Float) = 0.01
        _ForceS("Separation Force", Float) = 0.011
        _ForceA("Alignment Force", Float) = 0.01
        _ForceG("centralization", Float) = 0.001
        _ForceR("Random Force", Float) = 0.001
    }

    CGINCLUDE
        #include "UnityCustomRenderTexture.cginc"

        float _Speed;
        float _MinSpeed;
        float _MaxSpeed;
        float _Area;
        float _InfRad;
        float _ForceC;
        float _ForceS;
        float _ForceA;
        float _ForceG;
        float _ForceR;

        // 乱数
        float3 rand(float x)
        {
            return frac(sin(x * float3(12.9898,78.233,40.847)) * 43758.5453) - 0.5;
        }

        // フラグメントシェーダー(更新)
        float4 UpdateFrag(v2f_customrendertexture i) : SV_Target
        {
            float2 uv = i.globalTexcoord;

            // 1pxあたりの単位を計算する
            float du = 1.0 / _CustomRenderTextureWidth;
            float dv = 1.0 / _CustomRenderTextureHeight;

            // 現在の位置のindex(0~31)を算出
            int index = (int)(fmod(uv.y, 0.5) / dv) * 8 + (int)(uv.x / du);

            // Boid
            // 座標,速度取得
            float3 co[32];
            float3 ve[32];
            int n = 0;
            for(int y = 0; y < 4; y++)
            {
                for(int x = 0; x < 8; x++)
                {
                    float2 uv = (float2(x, y) + 0.5) * float2(du, dv);
                    co[n] = tex2D(_SelfTexture2D, float2(uv.x, uv.y));
                    ve[n] = tex2D(_SelfTexture2D, float2(uv.x, frac(uv.y + 0.5))) * _Speed;
                    n++;
                }
            }

            // 結合(Cohesion)
            float4 VeC = float4(0, 0, 0, 0);
            for(int nc = 0; nc < 32; nc++)
            {
                float dist = distance(co[nc], co[index]);
                VeC.w += step(dist, _InfRad);
                VeC.xyz += step(dist, _InfRad) * co[nc];
            }
            VeC.xyz = (VeC.xyz / VeC.w) - co[index];
            VeC.xyz *= _ForceC;
            VeC.xyz *= (19 + sin(_Time.x)) / 20;

            // 引き離し(Separation)
            float4 VeS = float4(0, 0, 0, 0);
            for(int ns = 0; ns < 32; ns++)
            {
                float dist = distance(co[ns], co[index]);
                VeS.w += step(dist, _InfRad);
                VeS.xyz += step(dist, _InfRad) * (co[index] - co[ns]);
            }
            VeS.xyz = VeS.xyz / VeS.w;
            VeS.xyz *= _ForceS;
            VeS.xyz *= (19 + cos(_Time.x)) / 20;

            // 整列(Alignment)
            float4 VeA = float4(0, 0, 0, 0);
            for(int na = 0; na < 32; na++)
            {
                float dist = distance(co[na], co[index]);
                VeA.w += step(dist, _InfRad);
                VeA.xyz += step(dist, _InfRad) * (ve[na]);
            }
            VeA.xyz = (VeA.xyz - ve[index]) / VeA.w;
            VeA.xyz *= _ForceA;
            VeA.xyz *= (19 + sin(_Time.x / 2)) / 20;

            // 引力
            float3 centerPos = float3(0, 0, 0);
            float dist = distance(co[index], centerPos);
            float forceG = max(dist - _Area, 0);
            forceG = forceG / (_Area + forceG) * _ForceG;
            float3 VeG = - normalize(co[index] - centerPos) * forceG;

            // 座標算出
            //float3 veloc = ve[index] + VeC.xyz + VeS.xyz + VeA.xyz + VeG + rand(co[index].x + co[index].y + co[index].z) * _ForceR;
            //veloc = normalize(veloc) * clamp(length(veloc), 0, 1);
            float3 veloc = ve[index] + VeC.xyz + VeS.xyz + VeA.xyz + VeG + rand(co[index].x + co[index].y + co[index].z) * _ForceR;
            float speed = length(veloc);
            speed = clamp(speed, length(ve[index]) - 0.1, length(ve[index]) + 0.1);
            speed = clamp(speed, _MinSpeed, _MaxSpeed);
            veloc = normalize(veloc) * speed;
            float3 coord = co[index] + veloc * _Speed;

            // 書き込み
            return float4(veloc * step(0.5, uv.y) / _Speed + coord * step(uv.y, 0.5), 0);
        }
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            Name "Update"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment UpdateFrag
            ENDCG
        }
    }
}