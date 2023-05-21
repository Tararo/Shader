<<<<<<< HEAD
Shader "TARARO/Cube_DistortionSphere"
{
	Properties
    {
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,1)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.1
            _Specular("Specular", Range(0.0, 1.0)) = 1
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 50
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.5
        [Header(Sphere)]
            _Radius("Radius", Range(0.0, 1.0)) = 0.8
            _Amount("Noise Amount", Range(0.0, 1.0)) = 0.05
            _Density("Noise Density", Range(0.0, 10.0)) = 3
            _Speed("Noise Amount", Float) = (0,-1,0)
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
    float _Radius;
    float _Amount;
    float _Density;
    float3 _Speed;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
    }

    float3 random3 (float3 st)
    {
        st = float3(dot(st, float3(127.7, 311.9, 208.1)), dot(st, float3(269.3, 214.3, 183.1)), dot(st, float3(118.1, 153.1, 370.9)));
        return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
    }

    float perlinNoise3 (float3 st) 
    {
        float3 p = floor(st);
        float3 f = frac(st);
        float3 u = smoothstep(0, 1, f);

        float3 v000 = random3(p + float3(0, 0, 0));
        float3 v001 = random3(p + float3(0, 0, 1));
        float3 v010 = random3(p + float3(0, 1, 0));
        float3 v011 = random3(p + float3(0, 1, 1));
        float3 v100 = random3(p + float3(1, 0, 0));
        float3 v101 = random3(p + float3(1, 0, 1));
        float3 v110 = random3(p + float3(1, 1, 0));
        float3 v111 = random3(p + float3(1, 1 ,1));

        float o = 
        lerp(
            lerp(
                lerp( dot( v000, f - float3(0, 0, 0) ), dot( v100, f - float3(1, 0, 0) ), u.x ), 
                lerp( dot( v010, f - float3(0, 1, 0) ), dot( v110, f - float3(1, 1, 0) ), u.x ), 
            u.y ),
            lerp(
                lerp( dot( v001, f - float3(0, 0, 1) ), dot( v101, f - float3(1, 0, 1) ), u.x ), 
                lerp( dot( v011, f - float3(0, 1, 1) ), dot( v111, f - float3(1, 1, 1) ), u.x ), 
            u.y ),
        u.z ) + 0.5f;
        
        return o;
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

    //球の距離関数
    float sphere(float3 p, float3 center, float radius) 
    {
        return length(p - center) - radius;
    }

    //Distortion Sphere
    float dsphere(float3 p) {
        //極座標
        float theta1 = (acos(p.y*rsqrt(p.x*p.x+p.y*p.y+p.z*p.z))-UNITY_HALF_PI)*_Density;
        float theta2 = (acos(p.z*rsqrt(p.x*p.x+p.y*p.y+p.z*p.z))-UNITY_HALF_PI)*_Density;
        float theta3 = (acos(p.x*rsqrt(p.x*p.x+p.y*p.y+p.z*p.z))-UNITY_HALF_PI)*_Density;
        theta1 += _Time.y * _Speed.y;
        theta2 += _Time.y * _Speed.z;
        theta3 += _Time.y * _Speed.x;
        float noise = perlinNoise3((float3(theta1, theta2, theta3))) * _Amount;
        float d = sphere(p, float3(0,0,0), (_Radius + noise)*0.5);
        return d;
    }

    //最終的な距離関数
    float dist(float3 p) {
        float d = dsphere(p);
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

                //環境光
                half3 ambColor = ShadeSH9(half4(normal, 1));
                //ランバート反射
                float3 difColor = saturate(dot(normal, lightDir)) * lightColor;
                //フォン鏡面反射
                float3 refLightVec = reflect(lightDir, normal);
                float3 speColor = pow(saturate(dot(refLightVec, rd)), _SpecularPow) * lightColor;
                //反射
                float3 refViewVec = normalize(reflect(UnityObjectToWorldDir(rd), UnityObjectToWorldNormal(normal)));
                float4 refColor = refProbe(refViewVec, mul(unity_ObjectToWorld, p));

                fragColor.rgb = _Color * lerp(difColor, ambColor, _Ambient);
                fragColor.rgb += ambColor * _Ambient;
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, _Reflect);
                fragColor.rgb += speColor  * _Specular;

				pout o;
				o.color = fragColor;
				float4 projectionPos = UnityObjectToClipPos(float4(p, 1.0));
				o.depth = projectionPos.z / projectionPos.w;
				return o;
			}
			ENDCG
		}
	}
=======
﻿Shader "TARARO/Cube_DistortionSphere"
{
	Properties
    {
        [Header(Main)]
            _Color("Color", Color) = (0,0,0,1)
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.1
            _Specular("Specular", Range(0.0, 1.0)) = 1
            _SpecularPow("Specular Power", Range(2.0, 100.0)) = 50
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.5
        [Header(Sphere)]
            _Radius("Radius", Range(0.0, 1.0)) = 0.8
            _Amount("Noise Amount", Range(0.0, 1.0)) = 0.05
            _Density("Noise Density", Range(0.0, 10.0)) = 3
            _Speed("Noise Amount", Float) = (0,-1,0)
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
    float _Radius;
    float _Amount;
    float _Density;
    float3 _Speed;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
    }

    float3 random3 (float3 st)
    {
        st = float3(dot(st, float3(127.7, 311.9, 208.1)), dot(st, float3(269.3, 214.3, 183.1)), dot(st, float3(118.1, 153.1, 370.9)));
        return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
    }

    float perlinNoise3 (float3 st) 
    {
        float3 p = floor(st);
        float3 f = frac(st);
        float3 u = smoothstep(0, 1, f);

        float3 v000 = random3(p + float3(0, 0, 0));
        float3 v001 = random3(p + float3(0, 0, 1));
        float3 v010 = random3(p + float3(0, 1, 0));
        float3 v011 = random3(p + float3(0, 1, 1));
        float3 v100 = random3(p + float3(1, 0, 0));
        float3 v101 = random3(p + float3(1, 0, 1));
        float3 v110 = random3(p + float3(1, 1, 0));
        float3 v111 = random3(p + float3(1, 1 ,1));

        float o = 
        lerp(
            lerp(
                lerp( dot( v000, f - float3(0, 0, 0) ), dot( v100, f - float3(1, 0, 0) ), u.x ), 
                lerp( dot( v010, f - float3(0, 1, 0) ), dot( v110, f - float3(1, 1, 0) ), u.x ), 
            u.y ),
            lerp(
                lerp( dot( v001, f - float3(0, 0, 1) ), dot( v101, f - float3(1, 0, 1) ), u.x ), 
                lerp( dot( v011, f - float3(0, 1, 1) ), dot( v111, f - float3(1, 1, 1) ), u.x ), 
            u.y ),
        u.z ) + 0.5f;
        
        return o;
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

    //球の距離関数
    float sphere(float3 p, float3 center, float radius) 
    {
        return length(p - center) - radius;
    }

    //Distortion Sphere
    float dsphere(float3 p) {
        //極座標
        float theta1 = (acos(p.y*rsqrt(p.x*p.x+p.y*p.y+p.z*p.z))-UNITY_HALF_PI)*_Density;
        float theta2 = (acos(p.z*rsqrt(p.x*p.x+p.y*p.y+p.z*p.z))-UNITY_HALF_PI)*_Density;
        float theta3 = (acos(p.x*rsqrt(p.x*p.x+p.y*p.y+p.z*p.z))-UNITY_HALF_PI)*_Density;
        theta1 += _Time.y * _Speed.y;
        theta2 += _Time.y * _Speed.z;
        theta3 += _Time.y * _Speed.x;
        float noise = perlinNoise3((float3(theta1, theta2, theta3))) * _Amount;
        float d = sphere(p, float3(0,0,0), (_Radius + noise)*0.5);
        return d;
    }

    //最終的な距離関数
    float dist(float3 p) {
        float d = dsphere(p);
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

                //環境光
                half3 ambColor = ShadeSH9(half4(normal, 1));
                //ランバート反射
                float3 difColor = saturate(dot(normal, lightDir)) * lightColor;
                //フォン鏡面反射
                float3 refLightVec = reflect(lightDir, normal);
                float3 speColor = pow(saturate(dot(refLightVec, rd)), _SpecularPow) * lightColor;
                //反射
                float3 refViewVec = normalize(reflect(UnityObjectToWorldDir(rd), UnityObjectToWorldNormal(normal)));
                float4 refColor = refProbe(refViewVec, mul(unity_ObjectToWorld, p));

                fragColor.rgb = _Color * lerp(difColor, ambColor, _Ambient);
                fragColor.rgb += ambColor * _Ambient;
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, _Reflect);
                fragColor.rgb += speColor  * _Specular;

				pout o;
				o.color = fragColor;
				float4 projectionPos = UnityObjectToClipPos(float4(p, 1.0));
				o.depth = projectionPos.z / projectionPos.w;
				return o;
			}
			ENDCG
		}
	}
>>>>>>> origin/main
}