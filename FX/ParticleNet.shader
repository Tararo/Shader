Shader "TARARO/ParticleNet"
{
    Properties
    {
        [Header(Main)]
            _AreaSize("Area Size", float) = 0.5
            _Color("Color", Color) = (1,1,1,1)
            _Intensity("Color Intensity", Range(0, 4)) = 0
        [Header(Particle)]
            _Size ("Size", Float) = 0.02
            _FluctSpeed ("Fluctuation Speed", Float) = 0.2
            _FluctAmount ("Fluctuation Amount", Float) = 0.2
        [Header(Line)]
            _LineLength("Max Length", Range(0, 2)) = 0.8
            _LineWidth("Width", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
            "VRCFallback"="Hidden"
        }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2g
            {
                float4 vertex : POSITION;
            };

            struct g2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float alpha : TEXCOORD1;
                int type : TEXCOORD2;
            };

            float _AreaSize;
            fixed4 _Color;
            float _Intensity;
            float _Size;
            float _FluctSpeed;
            float _FluctAmount;
            float _LineLength;
            float _LineWidth;

            float rand(float3 co){
                return frac(sin(dot(co, float3(12.9898,78.233,40.847))) * 43758.5453);
            }

            half3 LDR2HDR(fixed3 ldr, float intensity)
            {
                float factor = pow(2, intensity);
                half3 hdr = half3(ldr.r * factor, ldr.g * factor, ldr.b * factor);
                return hdr;
            }

            float3 particlePos(float3 co, int id)
            {
                float3 lattice = floor(co / _AreaSize);
                float3 random = float3(rand(lattice + id), rand(lattice + float3(0.5,0,0) + id), rand(lattice + float3(0,0.5,0) + id));
                float tFlu = _Time.y * _FluctSpeed;
                return (lattice + random + sin(tFlu * (random + 0.5)) * _FluctAmount) * _AreaSize;
            }

            v2g vert (appdata v)
            {
                v2g o;
                o.vertex = v.vertex;
                return o;
            }

            [maxvertexcount(105)]
            void geom (triangle v2g IN[3], uint id : SV_PrimitiveID, inout TriangleStream<g2f> stream)
            {
                g2f o;
                float aspectRatio = - UNITY_MATRIX_P[0][0] / UNITY_MATRIX_P[1][1];
                float3 originWorldPos = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;
                float3 shift[7] = {float3(0,0,0),float3(-1,0,0),float3(0,-1,0),float3(0,0,-1),float3(1,0,0),float3(0,1,0),float3(0,0,1)};

                [unroll]
                for ( int i = 0; i < 7; i++ )
                {
                    float3 pos = originWorldPos + shift[i] * _AreaSize;
                    float3 pPos = particlePos(pos, id);
                    float4 vert = mul(UNITY_MATRIX_VP, float4(pPos, 1));
                    float pAlpha = 1 - smoothstep(_AreaSize/2, _AreaSize, length(pPos - originWorldPos));

                    // Particle
                    o.type = 0;
                    o.alpha = pAlpha;
                    o.vertex = vert + float4(0.0,1.0,0.0,0.0) * _Size * float4(aspectRatio, 1, 1, 1);
                    o.uv = float2(0.0,1.0);
                    stream.Append(o);
                    o.vertex = vert + float4(-0.9,-0.5,0.0,0.0) * _Size * float4(aspectRatio, 1, 1, 1);
                    o.uv = float2(-0.9,-0.5);
                    stream.Append(o);
                    o.vertex = vert + float4(0.9,-0.5,0.0,0.0) * _Size * float4(aspectRatio, 1, 1, 1);
                    o.uv = float2(0.9,-0.5);
                    stream.Append(o);
                    stream.RestartStrip();

                    // Line
                    [unroll(6)]
                    for( int j = 0; j < 6 - i; j++ )
                    {
                        int index = i + j + 1;
                        float3 neighborPos = originWorldPos + shift[index] * _AreaSize;
                        float3 neighborPPos = particlePos(neighborPos, id);
                        float3 lineV = neighborPPos - pPos;
                        float nPAlpha = 1 - smoothstep(_AreaSize / 2, _AreaSize, length(neighborPPos - originWorldPos));
                        nPAlpha *= 1 - smoothstep(_LineLength * _AreaSize / 2, _LineLength * _AreaSize, length(lineV));
                        if(length(lineV) < _LineLength * _AreaSize)
                        {
                            float4 dirL = mul(UNITY_MATRIX_VP, lineV);
                            float4 dirW = float4(normalize(float3(-dirL.y, dirL.x, 0)) * _Size * _LineWidth, 0);

                            o.type = 1;
                            o.alpha = min(pAlpha, nPAlpha);
                            o.vertex = vert - dirW * 0.5;
                            o.uv = float2(-1.0,-1.0);
                            stream.Append(o);
                            o.vertex = vert + dirW * 0.5;
                            o.uv = float2(-1.0,1.0);
                            stream.Append(o);
                            o.vertex = vert - dirW * 0.5 + dirL;
                            o.uv = float2(1.0,-1.0);
                            stream.Append(o);
                            o.vertex = vert + dirW * 0.5 + dirL;
                            o.uv = float2(1.0,1.0);
                            stream.Append(o);
                            stream.RestartStrip();
                        }
                    }
                }
            }

            fixed4 frag (g2f i) : SV_Target
            {
                float4 col = _Color;
                col.a *= i.alpha;
                if(i.type == 0)
                {
                    col.a *= saturate(.5-length(i.uv)) * clamp(1 / pow(length(i.uv), 2), 0, 2);
                    return col;
                }
                else
                {
                    col.a *= smoothstep(-1, -0.9, i.uv.x) * (1- smoothstep(0.9, 1, i.uv.x));
                    col.a *= saturate(.5-abs(i.uv.y)) * clamp(1 / pow(abs(i.uv.y), 2), 0, 2);
                    return col;
                }
                return col;
            }
            ENDCG
        }
    }
}