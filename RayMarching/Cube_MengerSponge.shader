Shader "TARARO/Cube_MengerSponge"
{
    Properties
    {
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,1)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.2
            _Specular("Specular", Range(0.0, 1.0)) = 1
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 50
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.5
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"
    #include "Lighting.cginc"

    fixed4 _Color;
    float _Ambient;
    float _Specular;
    float _SpecularPow;
    float _Reflect;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
    }

    // 立方体
    float box(float3 p, float3 b) {
        float3 q = abs(p) - b;
        return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
    }

    // 移動
    float3 move(float time) {
        float x = floor(time / 3) + sin(saturate(fmod(time, 3)) * UNITY_HALF_PI);
        float y = floor(time / 3) + sin(saturate(fmod(time, 3) - 1) * UNITY_HALF_PI);
        float z = floor(time / 3) + sin(saturate(fmod(time, 3) - 2) * UNITY_HALF_PI);
        return float3(x, y, z);
    }

    // menger sponge
    float mengersponge(float3 p) {
        float3 q = p + move(_Time.y * 0.1);
        q = abs(0.5 - abs(abs(fmod(q, 1.0)) - 0.5));
        float s = 2;
        float d = max(box(p,float3(0.5, 0.5, 0.5)), box(q,float3(0.5, 0.5, 0.5)));

        for( int m = 0; m < 3; m++ ) {
            float3 a = fmod( q*s, 2.0 )-1.0;
            s *= 3.0;
            float3 r = abs(1.0 - 3.0*abs(a));

            float da = max(r.x,r.y);
            float db = max(r.y,r.z);
            float dc = max(r.z,r.x);
            float c = (min(da,min(db,dc))-1.0)/s;

            d = max(d,c);
        }
        return d;
    }

    //最終的な距離関数
    float dist(float3 p) {
        float d = mengersponge(p);
        return d;
    }

    //法線を導出する関数
    float3 getnormal(float3 p)
    {
        float d = 0.0001;
        return normalize(float3(
            dist(p + float3(d, 0.0, 0.0)) - dist(p + float3(-d, 0.0, 0.0)),
            dist(p + float3(0.0, d, 0.0)) - dist(p + float3(0.0, -d, 0.0)),
            dist(p + float3(0.0, 0.0, d)) - dist(p + float3(0.0, 0.0, -d))
        ));
    }

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
    };

    struct v2f
    {
        float2 uv : TEXCOORD0;
        float4 pos : SV_POSITION;
        float4 vertex : TEXCOORD1;
    };

    struct pout
    {
        fixed4 color : SV_Target;
        float depth : SV_Depth;
    };
    ENDCG
    
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "VRCFallback"="Hidden"
        }
        LOD 100
        Cull Front
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.vertex = v.vertex;//メッシュのローカル座標
                o.uv = v.uv;
                return o;
            }

            pout frag(v2f i)
            {
                //レイのスタート位置（カメラのローカル座標）.
                float3 ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;
                //レイの方向（視点→メッシュ）.
                float3 rd = normalize(i.vertex.xyz - ro);
                //レイの歩幅
                float d = 0;
                //レイの長さ
                float t = 0;
                //レイの先端座標
                float3 p = float3(0, 0, 0);

                //レイマーチング
                [unroll]
                for (int i = 0; i < 60; ++i)
                { 
                    p = ro + rd * t;
                    d = dist(p);
                    t += d;
                    //レイが遠くに行き過ぎたか衝突した場合ループを終える
                    if (d < 0.001 || t > 1000)
                    {
                        break;
                    }
                }
                p = ro + rd * t;

                //レイが衝突していないと判断すれば描画しない
                if (d > 0.01)
                {
                    discard;
                }
                
                //出力色
                float4 fragColor = float4(0,0,0,1);
                //法線
                float3 normal = getnormal(p);
                //光源
                float3 lightDir = normalize(ObjSpaceLightDir(float4(p,1)));
                float3 lightColor = _LightColor0;
                if(IsNaN(lightDir.x))
                {
                    lightDir = normalize(float3(1, 1, 1));
                    lightColor = float3(1, 1, 1);
                }


                // 環境光
                half3 ambColor = ShadeSH9(half4(normal, 1));
                //ランバート反射
                float3 difColor = saturate(dot(normal, lightDir)) * lightColor;
                //フォン鏡面反射
                float3 refLightVec = reflect(lightDir, normal);
                float3 speColor = pow(saturate(dot(refLightVec, rd)), _SpecularPow) * lightColor;
                //反射
                float3 refViewVec = reflect(rd, normal);
                refViewVec = normalize(mul(unity_ObjectToWorld, refViewVec) - mul(unity_ObjectToWorld, float3(0, 0, 0)));
                half4 refColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, refViewVec, 0);

                //fragColor.rgb = lerp(_Color.rgb * (difColor + speColor * _Specular) + ambColor * _Ambient, refColor.rgb, _Reflect);
                fragColor.rgb = lerp(_Color.rgb, refColor.rgb, _Reflect) * (difColor + speColor * _Specular) + ambColor * _Ambient;

                pout o;
                o.color = fragColor;
                float4 projectionPos = UnityObjectToClipPos(float4(p, 1.0));
                o.depth = projectionPos.z / projectionPos.w;
                return o;
            }
            ENDCG
        }
    }
}