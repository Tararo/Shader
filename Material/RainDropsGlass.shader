Shader "TARARO/RainDropsGlass"
{
    Properties
    {
        _Albedo("Albedo",Color) = (1, 1, 1, 0.1)
        _Ambient("Ambient Light", Range(0.0, 1.0)) = 0.1
        _Specular("Specular", Range(0.0, 1.0)) = 1
        _SpecularPow("Specular Power", Range(2.0, 100.0)) = 50
        _Reflect("Reflection", Range(0.0, 1.0)) = 0.3
        _Refract("Refraction", Range(0.0, 1.0)) = 0.3
        _RefractIndex("Refraction Index", Float) = 1.5
        _Size("Size", Float) = 4
        _Speed("Speed", Float) = 0.5
        _Blur("Blur", Range(0.0, 1.0)) = 0.4
        _BumpScale  ("Normal Scale", Range(-1, 1)) = 0.1
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 3.0
    #include "UnityCG.cginc"
    #include "Lighting.cginc"

    sampler2D _GrabTexture;
    fixed4 _Albedo;
    float _Ambient;
    float _Specular;
    float _SpecularPow;
    float _Reflect;
    float _Refract;
    float _RefractIndex;
    float _Size;
    float _Speed;
    float _Blur;
    float _BumpScale;

    // 非数判定
    bool IsNaN(float x)
    {
        return !(x < 0.f || x > 0.f || x == 0.f);
    }

    float2 random2 (float2 st)
    {
        st = float2(dot(st, float3(127.7, 311.9, 208.1)), dot(st, float3(269.3, 214.3, 183.1)));
        return frac(sin(st) * 43758.5453123)-0.5;
    }

    // LogSumExp関数
    float smoothMax(float x, float y, float k){
        float xx = max(x, 0);
        float yy = max(y, 0);
        return log(exp(k*xx) + exp(k*yy) - 1)/k;
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

    // 水滴の形
    float dropShape(float size, float2 pos, float2 uv) {
        float dropSize = size * max((uv.y - pos.y)/size/2 + 1, 0);
        float drop = smoothstep(dropSize, 0, distance(pos, uv));
        return drop;
    }

    // 流れる水滴
    float flowDrops(float2 uv) {
        float t = _Time.y * _Speed;

        float2 aspect = float2(2, 1);
        float2 gv = uv * _Size * aspect;
        gv.y += t*.5;
        float2 id = floor(gv);
        gv = frac(gv) - .5;
        float w = uv.y*10 + t*.2;

        float rnd = random2(id);
        t += rnd*UNITY_TWO_PI;

        float dropX = sin(3*w)*pow(sin(w),6)*(.4-abs(rnd))*.2 + rnd*.8;
        float dropY = (sin(t) - .5*sin(2*t) + .333*sin(3*t) - .25*sin(4*t) + .2*sin(5*t))/4;
        float dropSize = .04*abs(rnd) + .02;
        float drop = dropShape(dropSize, float2(dropX,dropY)/aspect, gv/aspect);

        return drop;
    }

    // 点滅する水滴
    float staticDrops(float2 uv) {
        float t = _Time.y * _Speed;

        float2 gv = uv * _Size * 10;
        gv.y += t*.1;
        float2 id = floor(gv);
        gv = frac(gv) - .5;

        float2 rnd = random2(id);

        float dropSize = .1*abs(rnd.x) + .05;
        float drop = dropShape(dropSize, float2(rnd*.7), gv);
        
        float fade = smoothstep(0, .025, frac(t + rnd.x)) * smoothstep(1, .025, frac(t + rnd.x));

        return drop*fade;
    }

    // 流れる水滴（軌跡付き）
    float flowDropsTrail(float2 uv) {
        float t = _Time.y * _Speed;

        float2 aspect = float2(2, 1);
        float2 gv = uv * _Size * aspect;
        gv.y += t*.5;
        float2 id = floor(gv);
        gv = frac(gv) - .5;
        float w = uv.y*10 + t*.2;

        float rnd = random2(id);
        t += rnd*UNITY_TWO_PI;

        float dropX = sin(3*w)*pow(sin(w),6)*(.4-abs(rnd))*.2 + rnd*.8;
        float dropY = (sin(t) - .5*sin(2*t) + .333*sin(3*t) - .25*sin(4*t) + .2*sin(5*t))/4;
        float dropSize = .04*abs(rnd) + .02;

        float drop = dropShape(dropSize, float2(dropX,dropY)/aspect, gv/aspect);
        float trail = smoothstep(dropSize, dropSize*.5, abs(gv.x-dropX)/aspect.x);
        trail *= smoothstep(-.0, .05, (gv.y-dropY)/aspect.y);
        trail *= smoothstep(.5, dropY, gv.y*1.5);

        return min(drop + trail, 1);
    }

    // ブラーマップ
    float blurMap(float2 uv) {
        float drops = flowDropsTrail(uv);
        drops = smoothMax(drops, flowDropsTrail(uv*1.23 + 1.53), 4);
        drops = smoothMax(drops, flowDropsTrail(uv*1.43 + 3.27), 4);
        drops = smoothMax(drops, flowDropsTrail(uv*1.55 + 5.73), 4);
        drops = smoothMax(drops, staticDrops(uv), 2);
        return drops;
    }

    // ハイトマップ
    float heightMap(float2 uv) {
        float drops = flowDrops(uv);
        drops = smoothMax(drops, flowDrops(uv*1.23 + 1.53), 4);
        drops = smoothMax(drops, flowDrops(uv*1.43 + 3.27), 4);
        drops = smoothMax(drops, flowDrops(uv*1.55 + 5.73), 4);
        drops = smoothMax(drops, staticDrops(uv), 2);
        return drops;
    }

    // ハイトマップから法線マップ
    float3 normalMap(float2 uv) {
        float delta = 0.001;
        float3 dx = float3(1, 0, heightMap(uv - float2(delta, 0)) - heightMap(uv + float2(delta, 0)));
        float3 dy = float3(0, 1, heightMap(uv + float2(0, delta)) - heightMap(uv - float2(0, delta)));
        float3 normal = normalize(cross(dx, dy)) * 0.5 + 0.5;
        return normal;
    }

    // GPU -> vertex shader
    struct appdata
    {
        float4 vertex : POSITION;
        half3 normal : NORMAL;
        half4 tangent : TANGENT;
        float2 uv : TEXCOORD0;
    };

    // vertex shader -> fragment shader
    struct v2f
    {
        float4 pos : SV_POSITION;
        half3 normal : TEXCOORD0; //法線
        half3 tangent : TEXCOORD1; //接線
        half3 binormal : TEXCOORD2; //従法線
        float4 worldPos : TEXCOORD3;
        float2 uv : TEXCOORD4;
        float4 grabPos : TEXCOORD5;
    };

    ENDCG

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        LOD 100

        GrabPass {}

        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM

            // Vertex Shader
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent)).xyz;
                o.binormal = cross(v.normal, v.tangent) * v.tangent.w;
                o.binormal = normalize(mul(unity_ObjectToWorld, o.binormal));
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.grabPos = ComputeGrabScreenPos(o.pos);
                o.uv = v.uv;
                return o;
            }
            
            // Fragment Shader
            fixed4 frag (v2f i) : SV_Target
            {
                // 法線
                float3 weights = abs(i.normal.xyz);
                weights /= weights.x + weights.y + weights.z;
                float3 normalmap = normalMap(i.worldPos.zy) * weights.x + normalMap(i.worldPos.xy) * weights.z;
                half4 bump = half4(normalmap, 1);
                normalmap = UnpackScaleNormal(bump, _BumpScale);
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
                // 屈折
                float3 refractDir = refract(eyeDir, normal, 1.0 / _RefractIndex);
                float3 refractWorldPos = i.worldPos + refractDir * _Refract;
                float4 refractPos = mul(UNITY_MATRIX_VP, float4(refractWorldPos, 1.0));
                float2 refractUv = (refractPos.xy / refractPos.w) * 0.5 + 0.5;
                #if UNITY_UV_STARTS_AT_TOP
                refractUv.y = 1.0 - refractUv.y;
                #endif

                // GrabTexture
                float heightmap = heightMap(i.worldPos.zy) * weights.x + heightMap(i.worldPos.xy) * weights.z;
                float blurmap = blurMap(i.worldPos.zy) * weights.x + blurMap(i.worldPos.xy) * weights.z;
                float blur = _Blur * .01 * (1 - smoothstep(0, .1, blurmap));
                float2 grabUv = i.grabPos.xy / i.grabPos.w;
                grabUv = lerp(grabUv, refractUv, heightmap);
                float4 grabColor = float4(0, 0, 0, 1);
                float theta = random2(grabUv);
                for(float i = 0; i < 8; i++) {
                    float2 offset = float2(sin(theta * UNITY_PI), cos(theta * UNITY_PI)) * blur;
                    grabColor += tex2D(_GrabTexture, grabUv + offset)/8;
                    theta += 0.25;
                }

                // 出力色
                float4 fragColor = float4(0, 0, 0, 1);
                fragColor.rgb = _Albedo.rgb;
                fragColor.rgb = fragColor.rgb * lerp(difColor, ambColor, _Ambient);
                fragColor.rgb = lerp(grabColor.rgb, fragColor.rgb, _Albedo.a);
                fragColor.rgb = lerp(fragColor.rgb, refColor.rgb, _Reflect);
                fragColor.rgb += speColor  * _Specular;
                //fragColor.rgb = blurmap;

                return fragColor;
            }
            ENDCG
        }
    }
}
