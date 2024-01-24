Shader "GroundEditor/GroundBrush"
{
	Properties
	{
		_MainTex("Main Texture", 2D) = "black"
		_Origin("Origin", Vector) = (0.0, 0.0, 0.0, 0.0)
		_Direction("Direction", Vector) = (0.0, 0.0, 1.0, 0.0)
		_Radius("Radius", float) = 10.0
		_InnerRadius("Inner Radius", float) = 5.0
	}

	Subshader
	{
		Tags{ "RenderType" = "Transparent" "Queue" = "Transparent+100" }

		Pass
		{
			ZWrite Off
			Offset -1, -1
			Fog{ Mode Off }
			ColorMask RGB
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_fog_exp2
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "UnityCG.cginc"

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 worldPos : TEXCOORD1;
			};

			uniform sampler2D _MainTex;
			float4 _MainTex_ST;
			float4x4 unity_Projector;
			float4 _Origin;
			float4 _Direction;
			float _Radius;
			float _InnerRadius;

			v2f vert(appdata_tan v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(mul(unity_Projector, v.vertex).xy, _MainTex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				return o;
			}

			fixed4 frag(v2f i) : COLOR
			{
				float3 v = _Direction;
				float3 u = i.worldPos.xyz - _Origin.xyz;
				float3 p = (dot(v, u) / length(v)) * v;
				float l = length(u - p);

				if (l < _Radius && l > _Radius - 0.1)
					return fixed4(1.0, 0.0, 0.0, 0.5);
				if (l < _InnerRadius && l > _InnerRadius - 0.1)
					return fixed4(0.0, 0.0, 1.0, 0.5);

				discard;
				return fixed4(0.0, 0.0, 0.0, 0.0);
			}
			ENDCG
		}
	}
}