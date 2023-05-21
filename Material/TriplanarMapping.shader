Shader "TARARO/TriplanarMapping"
{
	Properties
    {
        [Header(Texture)]
            _MainTex ("Texture", 2D) = "white" {}
            [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
            _BumpScale  ("Normal Scale", Range(0, 1)) = 1.0
        [Header(Main)]
            _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.1
            _Specular("Specular", Range(0.0, 1.0)) = 0.5
            _SpecularPow("Specular Power", Range(1.0, 100.0)) = 2
            _Reflect("Reflection", Range(0.0, 1.0)) = 0.5
	}

    CGINCLUDE
    #pragma target 3.0
    #pragma vertex vert
    #pragma fragment frag

    #include "UnityCG.cginc"
    #include "Lighting.cginc"
    #include "AutoLight.cginc"

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

    sampler2D _MainTex;
    float4 _MainTex_ST;
    sampler2D _BumpMap;
    float _BumpScale;
    float _Ambient;
    float _SpecularPow;
    float _Specular;
    float _Reflect;

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
                o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent)).xyz;
                o.binormal = cross(v.normal, v.tangent) * v.tangent.w;
                o.binormal = normalize(mul(unity_ObjectToWorld, o.binormal));
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // uv算出
                float2 uv_xy = TRANSFORM_TEX(i.worldPos.xy, _MainTex);
                float2 uv_yz = TRANSFORM_TEX(i.worldPos.yz, _MainTex);
                float2 uv_zx = TRANSFORM_TEX(i.worldPos.zx, _MainTex);
                // 重み算出
                float3 weights = abs(i.normal);
                weights /= weights.x + weights.y + weights.z;
                // テクスチャ
                fixed4 triTexture = tex2D(_MainTex, uv_xy) * weights.z +  tex2D(_MainTex, uv_yz) * weights.x +  tex2D(_MainTex, uv_zx) * weights.y;
                fixed4 triBump = tex2D(_BumpMap, uv_xy) * weights.z +  tex2D(_BumpMap, uv_yz) * weights.x +  tex2D(_BumpMap, uv_zx) * weights.y;

                // 法線
                half3 normalmap = UnpackScaleNormal(triBump, _BumpScale);
                float3 normal = normalize((i.tangent * normalmap.x) + (i.binormal * normalmap.y) + (i.normal * normalmap.z));
                // 視線の向き
                float3 cameraPos = _WorldSpaceCameraPos;
                #if defined(USING_STEREO_MATRICES)
                    cameraPos = (unity_StereoWorldSpaceCameraPos[0] + unity_StereoWorldSpaceCameraPos[1]) * 0.5;
                #endif
                float3 eyeDir = normalize(i.worldPos - cameraPos);
                // 光源の向き
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

                // 環境光
                half3 ambColor = ShadeSH9(half4(normal, 1));
                // ランバート反射
                float3 difColor = saturate(dot(normal, lightDir)) * _LightColor0;
                // フォン鏡面反射
                float3 refLightVec = reflect(lightDir, normal);
                float3 speColor = pow(saturate(dot(refLightVec, eyeDir)), _SpecularPow) * _LightColor0;
                // 反射
                float3 refViewVec = normalize(reflect(eyeDir, normal));
                float4 refColor = refProbe(refViewVec, i.worldPos);

                // 出力色
                fixed4 fragColor = fixed4(0,0,0,1);
                fragColor.rgb = triTexture.rgb * lerp(difColor, ambColor, _Ambient);
                fragColor.rgb += ambColor * _Ambient;
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, _Reflect);
                fragColor.rgb += speColor  * _Specular;

                return fragColor;
            }
			ENDCG
		}

        UsePass "Standard/ShadowCaster"
	}
}