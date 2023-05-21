Shader "TARARO/Art_GameOfLife"
{
    Properties
    {
        [Header(Custom Render Texture)]
            [NoScaleOffset]_BoidTex("8x8, rgba SFLOAT, Double Buffered", 2D) = "gray" {}
        [Header(Main)]
            _CellColor("Cell Color", Color) = (0,1,0,0.2)
            _BGColor("BackGround Color", Color) = (0,0,0,0)
            _Tiling ("Tiling", Float) = 1.0
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"

    sampler2D _BoidTex;
    float2 _BoidTex_TexelSize;
    fixed4 _CellColor;
    fixed4 _BGColor;
    float _Tiling;

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
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
        }
        LOD 100
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
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
                //UV tiling
                float2 uv = frac(i.uv * _Tiling);
                uv = (floor(uv / _BoidTex_TexelSize) + 0.5) * _BoidTex_TexelSize;
                //生死
                float isLive = tex2Dlod(_BoidTex, float4(uv.x, uv.y, 0, 0));
                //出力色
                float4 fragColor = _CellColor * isLive + _BGColor * (1 - isLive);

                pout o;
                o.color = fragColor;
                return o;
            }
            ENDCG
        }
    }
}