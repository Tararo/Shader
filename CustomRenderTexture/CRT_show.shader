Shader "Hidden/CRT_show"
{
    Properties
    {
        [Header(Custom Render Texture)]
            _BoidTex("Boid Texture", 2D) = "gray" {}
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"
    #include "Lighting.cginc"

    sampler2D _BoidTex;
    float2 _BoidTex_TexelSize;

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
    };
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
                //出力色
                float4 fragColor = float4(0,0,0,1);
                float2 uv = (floor(i.uv / _BoidTex_TexelSize) + 0.5) * _BoidTex_TexelSize;
                fragColor.rgb = tex2Dlod(_BoidTex, float4(uv.x, uv.y, 0, 0));

                pout o;
                o.color = fragColor;
                return o;
            }
            ENDCG
        }
    }
}