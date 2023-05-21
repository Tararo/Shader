Shader "TARARO/cube_glass-cube"
{
	Properties
    {
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,0.15)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.1
            _Specular("Specular", Range(0.0, 1.0)) = 1
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 30
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.5
            _Refract("Refraction", Range(0.0, 1.0)) = 0.2
            _RefractIndex("Refraction Index", Float) = 1.3
        [Header(Floating Object)]
            _Scale ("Scale", Range(0, 1)) = 1
            _RotateSpeed ("Rotation Speed", Float) = 0.05
	}

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag

    #include "UnityCG.cginc"
    #include "Lighting.cginc"

    sampler2D _GrabTexture;
    fixed4 _Color;
    float _Ambient;
    float _Specular;
    float _SpecularPow;
    float _Reflect;
    float _Refract;
    float _RefractIndex;
    int _ObjectNum;
    float _Scale;
    float _RotateSpeed;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
    }

    float3x3 rotateToMatrix(float roll, float pitch, float yaw)
    {
        float2 R = float2(sin(roll * UNITY_PI), cos(roll * UNITY_PI));
        float2 P = float2(sin(pitch * UNITY_PI), cos(pitch * UNITY_PI));
        float2 Y = float2(sin(yaw * UNITY_PI), cos(yaw * UNITY_PI));
        return float3x3(
            P.y * Y.y, R.x * P.x * Y.y - R.y * Y.x, R.y * P.x * Y.y + R.x * Y.x,
            P.y * Y.x, R.x * P.x * Y.x + R.y * Y.y, R.y * P.x * Y.x - R.x * Y.y,
            - P.x, R.x * P.y, R.y * P.y
        );
    }

    // 乱数
    float4 rand(float x){
        return frac(sin(x * float4(12.9898,78.233,40.847,97.259)) * 43758.5453);
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

    // フレネル反射係数
    float schlickFresnel(float cosine) {
        float r0 = (1 - _RefractIndex) / (1 + _RefractIndex);
        r0 = r0 * r0;
        return r0 + (1 - r0) * pow(1 - cosine, 5);
    }

    // 立方体
    float box(float3 p, float3 b) {
        float3 q = abs(p) - b;
        return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - 0.05;
    }

    //最終的な距離関数
    float dist(float3 p) {
        float tRot = _Time.y * _RotateSpeed;
        float3 q = p;
        q = mul(rotateToMatrix(tRot, tRot, tRot), q);
        float d = box(q,float3(0.25, 0.25, 0.25)*_Scale);
        return d;
    }

    //レイマーチング(返り値はレイ衝突フラグ).
    bool rayMarching(float3 rayOrigin, float3 rayDirection, out float3 pos)
    {
        //レイの長さ
        float t = 0;
        //距離
        float d = 0;

        //レイマーチング
        [unroll(32)]
        for (int i = 0; i < 32; ++i)
        { 
            pos = rayOrigin + rayDirection * t;
            d = dist(pos);
            t += d;
            //レイが遠くに行き過ぎたか衝突した場合ループを終える
            if (d < 0.001 || t > 1000)
            {
                break;
            }
        }
        pos = rayOrigin + rayDirection * t;

        //レイの衝突判定
        if (d > 0.001)
        {
            return false;
        }
        else
        {
            return true;
        }
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
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "VRCFallback"="Hidden"
        }
		LOD 100

        GrabPass {}

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
                //---レイマーチング1回目（屈折）---
                //レイのスタート位置（カメラのローカル座標）.
				float3 ro = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1)).xyz;
                //レイの方向（視点→メッシュ）.
				float3 rd = normalize(i.vertex.xyz - ro);
                //レイの先端座標
				float3 p;
                //レイが衝突していないと判断すれば描画しない
				if (rayMarching(ro, rd, p) == false)
                {
					discard;
				}
                //法線
                float3 normal = getnormal(p);

                //---レイマーチング2回目（再屈折）---
                //屈折方向
                float3 refractDir = refract(rd, normal, 1.0 / _RefractIndex);
                //レイのスタート位置（オブジェクト表面から屈折方向の遠い点）
                float3 ro2 = p + refractDir * 100;
                //レイの方向（屈折方向の逆）
                float3 rd2 = - refractDir;
                //レイの先端座標（再屈折位置）
                float3 p2;
                //レイマーチング
                rayMarching(ro2, rd2, p2);
                //法線
                float3 normal2 = getnormal(p2);
                //再屈折方向
                float3 refractDir2 = refract(rd2, normal2, 1.0 / _RefractIndex);


                //光源
                float3 lightDir = normalize(ObjSpaceLightDir(float4(p,1)));
                float3 lightColor = _LightColor0;
                if(IsNaN(lightDir.x))
                {
                    lightDir = normalize(float3(1, 1, 1));
                    lightColor = float3(1, 1, 1);
                }

                //環境光
                half3 ambColor = ShadeSH9(half4(normal, 1));
                //ランバート反射
                float3 difColor = saturate(dot(normal, lightDir)) * lightColor;
                //フォン鏡面反射
                float3 refLightVec = reflect(lightDir, normal);
                float3 speColor = pow(saturate(dot(refLightVec, rd)), _SpecularPow) * lightColor;
                //反射
                float3 refViewVec = reflect(rd, normal);
                refViewVec = normalize(mul(unity_ObjectToWorld, refViewVec) - mul(unity_ObjectToWorld, float3(0, 0, 0)));
                float4 reflectColor = refProbe(refViewVec, mul(unity_ObjectToWorld, p));
                float fresnel = schlickFresnel(max(0.0, dot(-rd, normal)));

                //屈折
                float3 refractPos = p + refractDir2 * _Refract;
                float4 refractScreenPos = UnityObjectToClipPos(float4(refractPos, 1.0));
                float4 refractGrabScreenPos = ComputeGrabScreenPos(refractScreenPos);
                float2 refractScreenUv = refractGrabScreenPos.xy / refractGrabScreenPos.w;
                float3 refractColor = tex2D(_GrabTexture, refractScreenUv);

                //出力色
				float4 fragColor = float4(0,0,0,1);
                fragColor.rgb = lerp(refractColor, _Color.rgb * difColor, _Color.a);
                fragColor.rgb = lerp(fragColor.rgb, reflectColor.rgb, fresnel * _Reflect);
                fragColor.rgb += speColor * fresnel * _Specular;
                fragColor.rgb += ambColor * _Ambient;

				pout o;
				float4 projectionPos = UnityObjectToClipPos(float4(p, 1.0));
				o.depth = projectionPos.z / projectionPos.w;
				o.color = fragColor;
				return o;
			}
			ENDCG
		}
	}
}