Shader "MK_Environment/MK_BG_DN" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}

		[Space][Space][Space]
		[KeywordEnum(OFF, ON)] CUTOUT("Use Cutout", Int) = 0
		_Cutout("Cutout Ref", range(0.0, 1.0)) = 0.0

		[Space][Space][Space]
		[KeywordEnum(OFF, ON)] DIFFUSE_MODIFY("Diffuse Color Modify", Int) = 0
		_DiffuseColor("Diffuse Color", color) = (1.0, 1.0, 1.0, 1.0)
		_DiffuseIntensity("Diffuse Itensity", range(0.0, 2.0)) = 1.0

		[Space][Space][Space]
		[KeywordEnum(OFF, ON)] ENVMAP("Use Environment Map", Int) = 0
		_EnvMapIntensity("Environment Map Intensity", float) = 0.5

		[Space][Space][Space]
		[KeywordEnum(ON, OFF)] BUMPMAP("Use BumpMap", Float) = 0.0
		_BumpMap ("Bump", 2D) = "bump" {}		
		_NormalPower("NormalPower", range(0.0, 6.0)) = 1.0

		[Space][Space][Space]
		[KeywordEnum(ON, OFF)] DETAILBUMPMAP("Use Detail BumpMap", Float) = 0.0
		_DetailBumpMap("Detail Bump", 2D) = "bump" {}
		_DetailNormalPower("Detail NormalPower", range(0.0, 6.0)) = 1.0

		[Space][Space][Space]
		_Glossiness("Smoothness", range(0.0, 1.0)) = 0.0
		_SpecIntensity("Specular Fresnel(F0)", range(0.0, 1.0)) = 1.0
		_RainSpecIntensity("Rain Specular Fresnel(F0)", range(0.0, 1.0)) = 0.25

		[Space][Space][Space]
		[KeywordEnum(OFF, ON)] EMISSIVE("Use Emissive", Int) = 0
		_EmissiveColor("Emissive Color", Color) = (1.0, 0.0, 0.0, 1.0)
		_EmissiveMinIntensity("Emissive Min Intensity", Float) = 0.0
		_EmissiveMaxIntensity("Emissive Max Intensity", Float) = 1.0
		_EmissiveIntensityFreq("Emissive Intensity Freq", Float) = 1.0		

		[Space][Space][Space]
		[Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc("Blend Source", Int) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _BlendDst("Blend Destination", Int) = 0
	}
	
	SubShader {
		Tags { "RenderType"="Opaque" "Queue"="Geometry" }
		
		LOD 300
		
		Pass{
			Tags{ "LightMode" = "ForwardBase" }

			Blend[_BlendSrc][_BlendDst]
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_fwdbase noshadowmask nolppv nometa nofog nodynlightmap novertexlights noambient
			#pragma multi_compile __ FAKE_HDR_ON 
			#pragma multi_compile __ WEATHER_RAIN  
			#pragma multi_compile __ DIFFUSE_MODIFY_ON
			#pragma multi_compile __ EMISSIVE_ON
			#pragma multi_compile __ CUTOUT_ON
			#pragma multi_compile __ ENVMAP_ON
			#pragma multi_compile __ BUMPMAP_OFF
			#pragma multi_compile __ DETAILBUMPMAP_OFF

        	#include "MK_ShaderInclude.cginc"
        	#include "AutoLight.cginc"

			half4 _DiffuseColor;
			float _EmissiveMinIntensity;
			float _EmissiveMaxIntensity;
			float _EmissiveIntensityFreq;
			half _Cutout;
			half _EnvMapIntensity;
        	
        	struct InputVS
        	{
	            float4 vertex : POSITION;
	            half4 texcoord : TEXCOORD0;
	            half4 texcoord1 : TEXCOORD1;
	            float3 normal : NORMAL;
	            float4 tangent : TANGENT;
        	};
        				
			struct v2f
			{
				float4 pos	: SV_POSITION;
				half4 uv 	: TEXCOORD0;
				half4 uv1  : TEXCOORD1;
				half3 normal : TEXCOORD2;
				#if !BUMPMAP_OFF
				half3 tangent : TEXCOORD3;
				half3 binormal : TEXCOORD4;
				#endif
				float4 viewDir : TEXCOORD5;
				
				SHADOW_COORDS(6)

				#if EMISSIVE_ON
				float4 emissive : TEXCOORD7;
				#endif

				half4 color : COLOR0;
			};
							
			v2f vert (InputVS v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				
				float4 vPos = v.vertex;
				
				o.pos = UnityObjectToClipPos(vPos);
				o.uv.xy = TRANSFORM_TEX(v.texcoord,_MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord,_BumpMap);
				
				o.uv1.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				o.uv1.zw = TRANSFORM_TEX(v.texcoord,_DetailBumpMap);
				
				float4x4 WORLD = unity_ObjectToWorld;

				o.normal.xyz = normalize(mul( (float3x3)WORLD, v.normal));
				#if !BUMPMAP_OFF
				o.tangent = normalize(mul( (float3x3)WORLD, v.tangent.xyz));
				o.binormal = cross( o.tangent, o.normal) * v.tangent.w;
				#endif
				
				float4 wPos = mul(unity_ObjectToWorld, vPos);
				float3 wViewDir = _WorldSpaceCameraPos.xyz - wPos.xyz;
				float sqrviewDist = dot(wViewDir, wViewDir) * volFogHeightDensityAtViewer;
				o.viewDir.xyz = normalize(wViewDir);
				o.viewDir.w = sqrviewDist;

				o.color.w = 1.0 - _Glossiness;

				#if EMISSIVE_ON
				//float4 worldPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
				//float randomval = frac(worldPos.x * worldPos.y * worldPos.z) * _EmissiveIntensityFreq;		// 움직일 경우 문제 발생..
				//float emissiveFactor = abs(((_Time.y + randomval) % _EmissiveIntensityFreq) / _EmissiveIntensityFreq - 0.5) * 2.0;
				float emissiveFactor = abs((_Time.y % _EmissiveIntensityFreq) / _EmissiveIntensityFreq - 0.5) * 2.0;
				o.emissive = _EmissiveMinIntensity + (_EmissiveMaxIntensity - _EmissiveMinIntensity) * emissiveFactor;
				#endif
				
				TRANSFER_SHADOW(o);
				return o;			
			}
				
			half4 frag (v2f i) : COLOR
			{
				half4 albedo = tex2D(_MainTex, i.uv.xy);
				#if CUTOUT_ON
				clip(albedo.a - _Cutout - 0.001);
				#endif

				#if DIFFUSE_MODIFY_ON
				albedo = albedo * _DiffuseColor * _DiffuseIntensity;
				#endif

				half roughness = i.color.w;
				
				half4 lmColor = 1.0;
				half4 spec = 0.0;
				
				half3 V = normalize(i.viewDir.xyz);

				#if !BUMPMAP_OFF
				half3 bumpColor = UnpackNormal(tex2D(_BumpMap, i.uv.zw)) * _NormalPower;
				#if !DETAILBUMPMAP_OFF
				half3 detailbumpColor = UnpackNormal(tex2D(_DetailBumpMap, i.uv1.zw)) * _DetailNormalPower;
				bumpColor += detailbumpColor;
				#endif
				half3 N = normalize(i.normal + (i.tangent * bumpColor.x + i.binormal * bumpColor.y));
				#else
				half3 N = i.normal;
				#endif

				#ifdef LIGHTMAP_ON							
				half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1.xy); 
				half4 bakedColor = DecodeLightmapEX(bakedColorTex);
				half4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd,unity_Lightmap, i.uv1.xy);
				lmColor = DecodeDirectionalLightmapSpecEX (bakedColor, bakedDirTex, N, V, roughness);
				#ifdef WEATHER_RAIN
				spec = lmColor.w * lmColor.w * _RainSpecIntensity;
				#else
				spec = lmColor.w * lmColor.w * _SpecIntensity;
				#endif
				#endif
				

				half4 outColor = half4(((albedo.rgb + spec) * lmColor.rgb), albedo.a);

				#if ENVMAP_ON
				float3 R = normalize(reflect(-V, N));
				float INdotV = 1.0 - max(dot(N, V), 0.0);
				float fresnelTerm = INdotV * INdotV * INdotV;
				half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R, (1.0 - _Glossiness) * UNITY_SPECCUBE_LOD_STEPS);
				half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR);
				skyColor = lerp(albedo, _SpecIntensity, fresnelTerm) * skyColor * _EnvMapIntensity;
				outColor.rgb += skyColor.rgb;
				#endif

				half atten = saturate(SHADOW_ATTENUATION(i) + _AmbientInfo.w);
				outColor.rgb *= atten;

				#if EMISSIVE_ON
				outColor.rgb += _EmissiveColor.rgb * i.emissive * albedo.a;
				#endif

				half4 expfog = GetVolumetricFogColorDistanceBased(i.viewDir.w, -V.y);
				outColor.rgb = lerp(expfog.rgb, outColor.rgb, expfog.w);
				outColor.rgb *= (1.0 - _FinalColorDarkeness);

				#ifdef FAKE_HDR_ON
				outColor.rgb *= (1.0 - _OutputRatio);
				#endif
				
				return saturate(outColor);
			}
			
			ENDCG
		}

		Pass
		{
			Tags{ "LightMode" = "ForwardAdd" }

			Blend One One
			ZWrite Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile __ FAKE_HDR_ON
			#pragma multi_compile __ CUTOUT_ON

			#include "MK_ShaderInclude.cginc"
			#include "AutoLight.cginc"

			half _Cutout;

			struct InputVS
			{
				float4 vertex : POSITION;
				half4 texcoord : TEXCOORD0;
				half4 texcoord1 : TEXCOORD1;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				float4 pos	: SV_POSITION;
				half4 uv 	: TEXCOORD0;
				half4 uv1  : TEXCOORD1;
				half3 normal : TEXCOORD2;
				half3 tangent : TEXCOORD3;
				half3 binormal : TEXCOORD4;
				float4 viewDir : TEXCOORD5;
				half3 lightDir : TEXCOORD6;
				half4 worldPos : TEXCOORD7;
				UNITY_LIGHTING_COORDS(8, 9)
				half4 color : COLOR0;
			};

			v2f vert(InputVS v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);

				float4 vPos = v.vertex;

				o.pos = UnityObjectToClipPos(vPos);
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);

				o.uv1.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				o.uv1.zw = TRANSFORM_TEX(v.texcoord, _DetailBumpMap);

				float4x4 WORLD = unity_ObjectToWorld;

				o.normal.xyz = normalize(mul((float3x3)WORLD, v.normal));
				o.tangent = normalize(mul((float3x3)WORLD, v.tangent.xyz));
				o.binormal = cross(o.tangent, o.normal) * v.tangent.w;

				float4 wPos = mul(unity_ObjectToWorld, vPos);
				float3 wViewDir = _WorldSpaceCameraPos.xyz - wPos.xyz;
				float sqrviewDist = dot(wViewDir, wViewDir) * volFogHeightDensityAtViewer;
				o.viewDir.xyz = normalize(wViewDir);
				o.viewDir.w = sqrviewDist;

				o.color = 1.0;
				o.color.w = 1.0 - _Glossiness;

				o.lightDir = normalize(WorldSpaceLightDir(vPos));
				o.worldPos = mul(unity_ObjectToWorld, vPos);

				UNITY_TRANSFER_LIGHTING(o, v.texcoord1);
				return o;
			}

			half4 frag(v2f i) : COLOR
			{
				half4 albedo = tex2D(_MainTex, i.uv.xy);
				#if CUTOUT_ON
				clip(albedo.a - _Cutout - 0.001);
				#endif

				half roughness = i.color.w;

				half3 bumpColor = UnpackNormal(tex2D(_BumpMap, i.uv.zw)) * _NormalPower;
				half3 detailbumpColor = UnpackNormal(tex2D(_DetailBumpMap, i.uv1.zw)) * _DetailNormalPower;
				bumpColor += detailbumpColor;

				half3 N = normalize(i.normal + (i.tangent * bumpColor.x + i.binormal * bumpColor.y));
				half3 L = normalize(i.lightDir);
				half NdotL = dot(N, L);

				UNITY_LIGHT_ATTENUATION(latten, i, i.worldPos.xyz);
				half4 lmColor = _LightColor0 * NdotL * latten * (1.0 + _LMAdd);
				half4 outColor = albedo * lmColor;

				#ifdef FAKE_HDR_ON
				outColor *= (1.0 - _OutputRatio);
				#endif

				return outColor;
			}
			ENDCG
		}
	}

	SubShader {
		Tags { "Queue"="Geometry" "LightMode" = "ForwardBase" }
		
		LOD 200
		
		Pass {						
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_fwdbase noshadowmask nolppv nometa nofog nodynlightmap novertexlights noambient
			#pragma multi_compile __ FAKE_HDR_ON 
			#pragma multi_compile __ CUTOUT_ON

        	#include "MK_ShaderInclude.cginc"
        	#include "AutoLight.cginc"
        	
			half _Cutout;

        	struct InputVS
        	{
	            float4 vertex : POSITION;
	            half4 texcoord : TEXCOORD0;
	            half4 texcoord1 : TEXCOORD1;
        	};
        				
			struct v2f
			{
				float4 pos	: SV_POSITION;
				half2 uv 	: TEXCOORD0;
				half2 uv1 	: TEXCOORD1;

				float4 viewDir 	: TEXCOORD2;

				SHADOW_COORDS(6)
			};
							
			v2f vert (InputVS v)
			{
				v2f o;
				
				float4 vPos = v.vertex;
				
				o.pos = UnityObjectToClipPos(vPos);
				o.uv.xy = TRANSFORM_TEX(v.texcoord,_MainTex);
				o.uv1.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;

				o.viewDir.xyz = WorldSpaceViewDir(vPos);
				o.viewDir.w = length(o.viewDir.xyz);	

				float4x4 WORLD = unity_ObjectToWorld;

				TRANSFER_SHADOW(o);
				return o;			
			}
				
			half4 frag (v2f i) : COLOR
			{
				half4 albedo = tex2D(_MainTex, i.uv.xy);
				#if CUTOUT_ON
				clip(albedo.a - _Cutout - 0.001);
				#endif

				#if DIFFUSE_MODIFY_ON
				albedo = albedo * _DiffuseColor * _DiffuseIntensity;
				#endif

				half4 lmColor = 1.0;

				#ifdef LIGHTMAP_ON
				half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1.xy); 
				lmColor = DecodeLightmapEXLowSpec(bakedColorTex);
				#endif
				
				half atten = saturate(SHADOW_ATTENUATION(i) + _AmbientInfo.w);
				half4 outColor = (albedo * lmColor) * atten;

				outColor = GetFogColorDistanceBased(outColor, i.viewDir.w);
				
				#ifdef FAKE_HDR_ON
				outColor *= (1.0 - _OutputRatio);
				#endif
				
				return outColor;
			}
			
			ENDCG
		}
	}

	SubShader{
		Tags{ "Queue" = "Geometry" "LightMode" = "ForwardBase" }

		LOD 100

		UsePass "MK_Character/MK_CH_Unlit/MKDEFAULT"
	}
				
	FallBack "VertexLit"
}
