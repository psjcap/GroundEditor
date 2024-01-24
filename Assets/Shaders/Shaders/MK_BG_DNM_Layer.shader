Shader "MK_Environment/MK_BG_DNM_Layer"
{
	Properties
	{
		_MainTex ("None", 2D) = "white" {}
		_MaskTex("Mask (RGB)", 2D) = "white" {}
		_LayerTex ("Cliff (RGB)", 2D) = "white" {}
		_Layer1Tex("Road (RGB)", 2D) = "white" {}
		_Layer2Tex("Soil (RGB)", 2D) = "white" {}
		_BumpMap ("Road Normal", 2D) = "bump" {}
		_DetailBumpMap ("Soil Normal", 2D) = "bump" {}
		_NormalPower("NormalPower", range(0.0, 6.0)) = 1.0

		[Space][Space][Space]
		//[KeywordEnum(NONE, R, G, B, A)] WATER("Water Channel", Int) = 0
		[KeywordEnum(OFF, ON)] WET("Wet On/Off", Int) = 0
		_WaterAmount("Water Amount", range(0.0, 1.0)) = 1.0
		_WaterColor("Water Color", Color) = (0.5, 0.5, 0.5, 1)
		_WaterTransparent("Water Transparent", range(0.0,1.0)) = 0.7
		_WaterSpecularIntensity("Water Specular Intensity", range(0.0, 6.0)) = 2.0
		_WaterSpecularPower("Water Specular Power", range(0.0, 1.0)) = 0.25
		_WaterEnvIntensity("Water Env Intensity", range(0.0, 6.0)) = 1.0
		_WaterEnvSmoothness("Water Env Smoothness", range(0.0, 1.0)) = 1.0
	}
	
	SubShader
	{
		Tags { "RenderType"="Opaque+1" "Queue"="Geometry" }
		
		LOD 300
		
		Pass
		{
			Tags{ "LightMode" = "ForwardBase" }

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_fwdbase
			#pragma multi_compile __ FAKE_HDR_ON 
			#pragma multi_compile __ WEATHER_RAIN  
			//#pragma multi_compile WATER_NONE WATER_R WATER_G WATER_B WATER_A
			#pragma multi_compile __ WET_ON
			#if (defined(SHADER_API_D3D9) || defined(SHADER_API_D3D11) || defined(SHADER_API_D3D11_9X))
			#pragma target 3.0
			#endif
			
        	#include "MK_ShaderInclude.cginc"
        	#include "AutoLight.cginc"

			sampler2D _MaskTex;
			half4 _MastTex_ST;
			sampler2D _Layer1Tex;
			sampler2D _Layer2Tex;
			half4 _Layer1Tex_ST;
			half4 _Layer2Tex_ST;

			half _WaterAmount;
			half4 _WaterColor;
			half _WaterTransparent;
			half _WaterSpecularIntensity;
			half _WaterSpecularPower;
			half _WaterEnvIntensity;
			half _WaterEnvSmoothness;
        	
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
				half4 uv2  : TEXCOORD2;
				half2 uv3  : TEXCOORD3;
				half3 normal : TEXCOORD4;
				half3 tangent : TEXCOORD5;
				half3 binormal : TEXCOORD6;
				float4 viewDir : TEXCOORD7;
				float3 lightDir : TEXCOORD8;
				
				SHADOW_COORDS(9)
			};
							
			v2f vert (InputVS v)
			{
				v2f o;
				
				float4 vPos = v.vertex;
				
				o.pos = UnityObjectToClipPos(vPos);

				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;

				o.uv1.xy = TRANSFORM_TEX(v.texcoord, _BumpMap);
				o.uv1.zw = TRANSFORM_TEX(v.texcoord, _DetailBumpMap);

				o.uv2.xy = TRANSFORM_TEX(v.texcoord, _LayerTex);
				o.uv2.zw = TRANSFORM_TEX(v.texcoord, _Layer1Tex);

				o.uv3.xy = TRANSFORM_TEX(v.texcoord, _Layer2Tex);
				
				float4x4 WORLD = unity_ObjectToWorld;

				o.normal.xyz = normalize(mul( (float3x3)WORLD, v.normal));
				o.tangent = normalize(mul( (float3x3)WORLD, v.tangent.xyz));
				o.binormal = cross( o.tangent, o.normal) * v.tangent.w;

				float4 wPos = mul(unity_ObjectToWorld, vPos);
				float3 wViewDir = _WorldSpaceCameraPos.xyz - wPos.xyz;
				float sqrviewDist = dot(wViewDir, wViewDir) * volFogHeightDensityAtViewer;
				o.viewDir.xyz = normalize(wViewDir);
				//o.viewDir.w = saturate(length(wViewDir) * _fogInfo.x - _fogInfo.y);
				o.viewDir.w = sqrviewDist;

				o.lightDir = UnityWorldSpaceLightDir(wPos);

				TRANSFER_SHADOW(o);
				return o;			
			}

			half4 frag (v2f i) : COLOR
			{
				half4 albedo = 0.0;
				half4 masktex = tex2D(_MaskTex, i.uv.xy);

				half4 layer = tex2D(_LayerTex, i.uv2.xy);
				half4 layer1 = tex2D(_Layer1Tex, i.uv2.zw);
				half4 layer2 = tex2D(_Layer2Tex, i.uv3.xy);
				//albedo = lerp(albedo, layer, masktex.r);
				albedo = layer;
				albedo = lerp(albedo, layer1, masktex.g);
				albedo = lerp(albedo, layer2, masktex.b);

				half3 L = normalize(i.lightDir);
				half3 V = normalize(i.viewDir.xyz);
				half3 H = normalize(L + V);

				half3 bumpColor = 0;
				//bumpColor = lerp(bumpColor, half3(0, 0, 1), masktex.r);
				bumpColor = half3(0, 0, 1);
				bumpColor = lerp(bumpColor, UnpackNormal(tex2D(_BumpMap, i.uv1.xy)), masktex.g);
				bumpColor = lerp(bumpColor, UnpackNormal(tex2D(_DetailBumpMap, i.uv1.zw)), masktex.b);

				bumpColor = normalize(bumpColor);
				bumpColor.xy *= _NormalPower;
				bumpColor = normalize(bumpColor);
				half3 N = normalize(i.tangent * bumpColor.x + i.binormal * bumpColor.y + i.normal * bumpColor.z);

				// water start
				//#if WATER_R || WATER_G || WATER_B || WATER_A
				//#if WATER_R
				//half waterFactor = masktex.r * _WaterAmount;
				//#elif WATER_G
				//half waterFactor = masktex.g * _WaterAmount;
				//#elif WATER_B
				//half waterFactor = masktex.b * _WaterAmount;
				//#elif WATER_A
				//half waterFactor = masktex.a * _WaterAmount;
				//#endif
				#if WET_ON
				half waterFactor = masktex.r * _WaterAmount;

				half normalDiff = dot(N, i.normal); 
				waterFactor = waterFactor * saturate(normalDiff * normalDiff);
				N = lerp(N, i.normal, waterFactor);

				half NdotH = saturate(dot(N, H));
				half3 R = reflect(-V, N);

				half4 skyData = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, R, (1.0f - _WaterEnvSmoothness) * UNITY_SPECCUBE_LOD_STEPS);
				half3 skyColor = DecodeHDR(skyData, unity_SpecCube0_HDR) * _WaterEnvIntensity * _WaterColor;
				half3 spec = _LightColor0 * pow(NdotH, _WaterSpecularPower * 256.0h) * _WaterSpecularIntensity;
				albedo.rgb = lerp(albedo.rgb, skyColor.rgb + spec.rgb, waterFactor * _WaterTransparent);
				#endif
				// water end..

				half4 lmColor = 1.0;
				#ifdef LIGHTMAP_ON
				half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv.zw); 
				half4 bakedColor = DecodeLightmapEX(bakedColorTex);
				half4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, i.uv.zw);
				lmColor = DecodeDirectionalLightmapEX (bakedColor, bakedDirTex, N);
				#endif				

				half atten = saturate(SHADOW_ATTENUATION(i) + _AmbientInfo.w);
				half4 outColor = (albedo* lmColor) * atten;

				half4 expfog = GetVolumetricFogColorDistanceBased(i.viewDir.w, -V.y);
				outColor = lerp(expfog, outColor, expfog.w);
				//outColor.rgb = ComputeSimpleFog(outColor.rgb, i.viewDir.w);
				outColor.rgb *= (1.0 - _FinalColorDarkeness);

				#ifdef FAKE_HDR_ON
				outColor *= (1.0 - _OutputRatio);
				#endif
				
				return outColor;
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
			#if (defined(SHADER_API_D3D9) || defined(SHADER_API_D3D11) || defined(SHADER_API_D3D11_9X))
			#pragma target 3.0
			#endif

			#include "MK_ShaderInclude.cginc"
			#include "AutoLight.cginc"

			sampler2D _MaskTex;
			sampler2D _Layer1Tex;
			sampler2D _Layer2Tex;
			half4 _Layer1Tex_ST;
			half4 _Layer2Tex_ST;

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
				half4 uv2  : TEXCOORD2;
				half2 uv3  : TEXCOORD3;
				half3 normal : TEXCOORD4;
				half3 tangent : TEXCOORD5;
				half3 binormal : TEXCOORD6;
				float4 viewDir : TEXCOORD7;
				float3 lightDir : TEXCOORD8;
				float4 worldPos : TEXCOORD9;

				UNITY_LIGHTING_COORDS(10, 11)
			};

			v2f vert(InputVS v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);

				float4 vPos = v.vertex;

				o.pos = UnityObjectToClipPos(vPos);

				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;

				o.uv1.xy = TRANSFORM_TEX(v.texcoord, _BumpMap);
				o.uv1.zw = TRANSFORM_TEX(v.texcoord, _DetailBumpMap);

				o.uv2.xy = TRANSFORM_TEX(v.texcoord, _LayerTex);
				o.uv2.zw = TRANSFORM_TEX(v.texcoord, _Layer1Tex);

				o.uv3.xy = TRANSFORM_TEX(v.texcoord, _Layer2Tex);

				float4x4 WORLD = unity_ObjectToWorld;

				o.normal.xyz = normalize(mul((float3x3)WORLD, v.normal));
				o.tangent = normalize(mul((float3x3)WORLD, v.tangent.xyz));
				o.binormal = cross(o.tangent, o.normal) * v.tangent.w;

				float4 wPos = mul(unity_ObjectToWorld, vPos);
				float3 wViewDir = _WorldSpaceCameraPos.xyz - wPos.xyz;
				float sqrviewDist = dot(wViewDir, wViewDir) * volFogHeightDensityAtViewer;
				o.viewDir.xyz = normalize(wViewDir);
				o.viewDir.w = sqrviewDist;

				o.lightDir = normalize(WorldSpaceLightDir(vPos));
				o.worldPos = mul(unity_ObjectToWorld, vPos);

				UNITY_TRANSFER_LIGHTING(o, v.texcoord1);
				return o;
			}

			half4 frag(v2f i) : COLOR
			{
				half4 albedo = 0.0;
				half4 masktex = tex2D(_MaskTex, i.uv.xy);

				half4 layer = tex2D(_LayerTex, i.uv2.xy);
				half4 layer1 = tex2D(_Layer1Tex, i.uv2.zw);
				half4 layer2 = tex2D(_Layer2Tex, i.uv3.xy);
				albedo = lerp(albedo, layer, masktex.r);
				albedo = lerp(albedo, layer1, masktex.g);
				albedo = lerp(albedo, layer2, masktex.b);				

				half3 bumpColor = 0;
				bumpColor = lerp(bumpColor, half3(0, 0, 1), masktex.r);
				bumpColor = lerp(bumpColor, UnpackNormal(tex2D(_BumpMap, i.uv1.xy)), masktex.g);
				bumpColor = lerp(bumpColor, UnpackNormal(tex2D(_DetailBumpMap, i.uv1.zw)), masktex.b);

				bumpColor = normalize(bumpColor);
				bumpColor.xy *= _NormalPower;
				bumpColor = normalize(bumpColor);

				half3 N = normalize(i.tangent * bumpColor.x + i.binormal * bumpColor.y + i.normal * bumpColor.z);
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

	SubShader
	{
		Tags{ "Queue" = "Geometry" "LightMode" = "ForwardBase" }

		LOD 200

		Pass
		{
			//Cull off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_fwdbase
			#pragma multi_compile __ FAKE_HDR_ON 

			#include "MK_ShaderInclude.cginc"

			sampler2D _MaskTex;
			half4 _MaskTex_ST;
			sampler2D _Layer1Tex;
			sampler2D _Layer2Tex;
			half4 _Layer1Tex_ST;
			half4 _Layer2Tex_ST;

			struct InputVS
			{
				float4 vertex : POSITION;
				half2 texcoord : TEXCOORD0;
				half2 texcoord1 : TEXCOORD1;
			};

			struct v2f
			{
				float4 pos	: SV_POSITION;
				half4 uv 	: TEXCOORD0;
				half4 uv1 	: TEXCOORD1;
				half2 uv2 	: TEXCOORD2;
			};

			v2f vert(InputVS v)
			{
				v2f o;

				float4 vPos = v.vertex;

				o.pos = UnityObjectToClipPos(vPos);
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _LayerTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _Layer1Tex);
				o.uv1.xy = TRANSFORM_TEX(v.texcoord, _Layer2Tex);
				o.uv1.zw = TRANSFORM_TEX(v.texcoord, _MaskTex);

				o.uv2.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				return o;
			}

			half4 frag(v2f i) : COLOR
			{
				half4 layerTex = tex2D(_LayerTex, i.uv.xy);
				half4 layer1Tex = tex2D(_Layer1Tex, i.uv.zw);
				half4 layer2Tex = tex2D(_Layer2Tex, i.uv1.xy);
				half4 maskTex = tex2D(_MaskTex, i.uv1.zw);

				half4 outColor = layerTex;
				outColor = lerp(outColor, layer1Tex, maskTex.g);
				outColor = lerp(outColor, layer2Tex, maskTex.b);

				#ifdef LIGHTMAP_ON
				half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv2.xy);
				half4 lmColor = DecodeLightmapEXLowSpec(bakedColorTex);
				outColor *= lmColor;
				#endif

				#ifdef FAKE_HDR_ON
				outColor *= (1.0 - _OutputRatio);
				#endif

				return outColor;
			}
			ENDCG
		}
	}

	SubShader
	{
		Tags{ "Queue" = "Geometry" "LightMode" = "ForwardBase" }

		LOD 100

		Pass
		{
			//Cull off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_fwdbase
			#pragma multi_compile __ FAKE_HDR_ON 

			#include "MK_ShaderInclude.cginc"

			sampler2D _MaskTex;
			half4 _MaskTex_ST;
			sampler2D _Layer1Tex;
			sampler2D _Layer2Tex;
			half4 _Layer1Tex_ST;
			half4 _Layer2Tex_ST;

			struct InputVS
			{
				float4 vertex : POSITION;
				half4 texcoord : TEXCOORD0;
			};

			struct v2f
			{
				float4 pos	: SV_POSITION;
				half4 uv 	: TEXCOORD0;
				half4 uv1 	: TEXCOORD1;
			};

			v2f vert(InputVS v)
			{
				v2f o;

				float4 vPos = v.vertex;

				o.pos = UnityObjectToClipPos(vPos);
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _LayerTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _Layer1Tex);
				o.uv1.xy = TRANSFORM_TEX(v.texcoord, _Layer2Tex);
				o.uv1.zw = TRANSFORM_TEX(v.texcoord, _MaskTex);
				return o;
			}

			half4 frag(v2f i) : COLOR
			{				
				half4 layerTex = tex2D(_LayerTex, i.uv.xy);
				half4 layer1Tex = tex2D(_Layer1Tex, i.uv.zw);
				half4 layer2Tex = tex2D(_Layer2Tex, i.uv1.xy);
				half4 maskTex = tex2D(_MaskTex, i.uv1.zw);

				half4 outColor = layerTex;
				outColor = lerp(outColor, layer1Tex, maskTex.g);
				outColor = lerp(outColor, layer2Tex, maskTex.b);

				return outColor;
			}
			ENDCG
		}
	}

	FallBack "VertexLit"
}