// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

#include "UnityCG.cginc"

#define UNITY_SPECCUBE_LOD_STEPS (7)
#define SKY_VECTOR (half3(0.0, 1.0, 0.0))

half4 unity_LightGammaCorrectionConsts;

uniform sampler2D _MainTex;
uniform float4 _MainTex_ST;

uniform sampler2D _BumpMap;
uniform float4 _BumpMap_ST;

uniform sampler2D _SpecMap;
uniform float4 _SpecMap_ST;

uniform sampler2D _LayerTex;
uniform float4 _LayerTex_ST;
																
uniform sampler2D _MaskMap;
uniform sampler2D _GGXLookUpTex;

uniform sampler2D _SkinColorMask;

uniform sampler2D _EmissiveMap;
uniform float4 _EmissiveMap_ST;

uniform float4 _LightColor0;

half _LayerOpacity;

half _NormalPower;
half _SpecIntensity;
half4 _EmissiveIntensity;
half4 _EmissiveUVFlowParam;
half _Wrap;

half _Metallic;
half _Glossiness;

half _RollOff;

half _ReflectGlossiness;
half _ReflectIntensity;

half _RimGlossiness;
half _RimIntensity;	

half _Dielectricity;
half _ScatterWidth;
			
uniform half _OutputRatio;
uniform half _InvGlowThreshold;

half _DefaultAmbient;
half4 _AmbientInfo;

half _RainSpecIntensity;

half _LMAdd;
half _LMAddLS;

half4 _WaterInfo;

half _Shrink;
half _DiffuseIntensity;
half _AmbientIntensity;

half _ShadowBiasOffset;

half4 _VariationColor;
half _DamageIntensity;

half4 _LightProbeInfo;

half _DynamicShadowTransparent;

half4 _SkinColor;

//half4 _DiffuseColor;
sampler2D _DetailBumpMap;
sampler2D _GGXSimpleLookUpTex;
half4 _DetailBumpMap_ST;
half _DetailNormalPower;

half4 _UpperColor;
half4 _LowerColor;

half4 _UpperLowSpecColor;
half4 _LowerLowSpecColor;

half4 _EnvironmentRimColor;

half _EnvironmentTheta;

fixed4 _BloodColor;
fixed4 _EmissiveColor;
fixed _FinalColorDarkeness = 0.0;

float _CharacterAmbientIntensity = 1.0f;
float _CharacterLightIntensity = 1.0f;

struct shadowCastv2f 
{
 V2F_SHADOW_CASTER;
};


struct appdata_shadow 
{
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	
	float4 color  : COLOR;
};

float4 UnityClipSpaceShadowCasterPosEX(float3 vertex, float3 normal, half shadowbiasoffset)
{
	float4 clipPos;
    
    // Important to match MVP transform precision exactly while rendering
    // into the depth texture, so branch on normal bias being zero.
    if (unity_LightShadowBias.z != 0.0)
    {
		float3 wPos = mul(unity_ObjectToWorld, float4(vertex,1)).xyz;
		float3 wNormal = UnityObjectToWorldNormal(normal);
		float3 wLight = normalize(UnityWorldSpaceLightDir(wPos));

		// apply normal offset bias (inset position along the normal)
		// bias needs to be scaled by sine between normal and light direction
		// (http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/)
		//
		// unity_LightShadowBias.z contains user-specified normal offset amount
		// scaled by world space texel size.

		float shadowCos = dot(wNormal, wLight);
		float shadowSine = sqrt(1-shadowCos*shadowCos);
		float normalBias = unity_LightShadowBias.z * shadowSine;

		wPos -= wNormal * (normalBias + shadowbiasoffset * 0.004);

		clipPos = mul(UNITY_MATRIX_VP, float4(wPos,1));
    }
    else
    {
        clipPos = UnityObjectToClipPos(float4(vertex,1));
    }
	return clipPos;
} 



shadowCastv2f vertShadowCast( appdata_shadow v )
{
	shadowCastv2f o;
	float4 vPos = float4(v.vertex.xyz, 1.0);
	vPos.xyz += v.normal.xyz * saturate(_Shrink * 0.05) * v.color.a;			 
	//v.vertex.xyz += v.normal.xyz * _Shrink * 0.05;
	//TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
	#ifdef SHADOWS_CUBE
		TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
	#else
	#if defined(UNITY_MIGHT_NOT_HAVE_DEPTH_TEXTURE)
		o.pos = UnityClipSpaceShadowCasterPosEX(vPos.xyz, v.normal, _ShadowBiasOffset);
		o.pos = UnityApplyLinearShadowBias(o.pos);
		o.hpos = o.pos;
	#else
		o.pos = UnityClipSpaceShadowCasterPosEX(vPos.xyz, v.normal, _ShadowBiasOffset);
		o.pos = UnityApplyLinearShadowBias(o.pos);
	#endif				
	#endif
	
	return o;
}

float4 fragShadowCast( shadowCastv2f i ) : COLOR
{
 SHADOW_CASTER_FRAGMENT(i)
}
			
					
half4 DecodeDirectionalLightmapEX (half4 inColor, half4 dirTex, half3 normalWorld)
{
	half3 dir = dirTex.xyz * 2 - 1;

	half4 tau = half4(normalWorld, 1.0) * 0.5;
	half halfLambert = dot(tau, half4(dir, 1.0));

	return (inColor * halfLambert) / max(1e-04, dirTex.w);
}

half4 DecodeDirectionalLightmapSpecEX (half4 inColor, half4 dirTex, half3 normalWorld, half3 relfectionVector, half roughness, out half specTerm)
{
	half3 dir = dirTex.xyz * 2 - 1;

	half4 tau = half4(normalWorld, 1.0) * 0.5;
	half halfLambert = dot(tau, half4(dir, 1.0));

	specTerm = pow( saturate(dot(relfectionVector,dir)), roughness) * 0.25;

	return (inColor * halfLambert) / max(1e-04, dirTex.w);
}

half4 DecodeDirectionalLightmapSpecEX (half4 inColor, half4 dirTex, half3 normalWorld, half3 viewVector, half roughness)
{
	half3 dir = dirTex.xyz * 2 - 1;
	half4 tau = half4(normalWorld, 1.0) * 0.5;
	half halfLambert = dot(tau, half4(dir, 1.0));

	half3 H = normalize( dir + viewVector);
	half NdotH = (dot(normalWorld, H));
	half D = tex2D(_GGXSimpleLookUpTex, half2(NdotH * NdotH, roughness)).x;
	inColor.w = D;

	return (inColor * halfLambert) / max(1e-04, dirTex.w);
}

half4 DecodeDirectionalLightmapFullSpecEX (half4 inColor, half4 dirTex, half3 normalWorld, half3 viewVector, half roughness, half F0)
{
	half3 dir = normalize(dirTex.xyz * 2 - 1);
	half4 tau = half4(normalWorld, 1.0) * 0.5;
	half halfLambert = dot(tau, half4(dir, 1.0));

	half3 H = normalize( dir + viewVector);
	half NdotH = (dot(normalWorld, H));
	half LdotH = (dot(dir, H));
	
	half4 specdistribute = tex2D(_GGXLookUpTex, half2(NdotH * NdotH, roughness));
	half D = dot(specdistribute.xy, half2((255.0 / 65025.0) * 8.0, 8.0));
	half4 FVhelpers = tex2D(_GGXLookUpTex, half2(LdotH, roughness));
	half FV = (F0 + (1.0 - F0) * FVhelpers.w) / max(FVhelpers.z, 0.001);
	inColor.w  = D * FV;
	
	return (inColor * halfLambert) / max(1e-04, dirTex.w);
}

half4 DecodeLightmapEX(half4 inColor){
	return half4(DecodeLightmap(inColor) * ( 1.0 + _LMAdd), 1.0);
}

half4 DecodeLightmapEXLowSpec(half4 inColor){
	return half4(DecodeLightmap(inColor) * ( 1.0 + _LMAddLS), 1.0);
}

inline half Pow4EX (half x)
{
	return x*x * x*x;
}

inline half Pow5EX (half x)
{
	return x*x * x*x * x;
}

inline half4 FresnelLerpEX (half4 F0, half4 F90, half cosA)
{
	half t = Pow5EX (1 - cosA);	// ala Schlick interpoliation
	return lerp (F0, F90, t);
}
	
inline half4 DecodeHDR_NoLinearSupportInSM2EX (half4 data, half4 decodeInstructions)
{
	return (data.a * decodeInstructions.x) * data;
}
			
half4 Unity_GlossyEnvironmentEX (UNITY_ARGS_TEXCUBE(tex), half4 hdr, half3 worldNormal, half roughness)
{
	float mip = roughness * UNITY_SPECCUBE_LOD_STEPS;

	half4 rgbm = SampleCubeReflection(tex, worldNormal.xyz, mip);
	return DecodeHDR_NoLinearSupportInSM2EX (rgbm, hdr);
}

half4 Unity_GlossyEnvironmentEXLOD (UNITY_ARGS_TEXCUBE(tex), half4 hdr, half3 reflectionVector, half roughnessfactor)
{
#if UNITY_GLOSS_MATCHES_MARMOSET_TOOLBAG2 && (SHADER_TARGET >= 30)
	// TODO: remove pow, store cubemap mips differently
	half roughness = pow(roughnessfactor, 3.0/4.0);
#else
	half roughness = roughnessfactor;
#endif

#if UNITY_OPTIMIZE_TEXCUBELOD
	half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(tex, reflectionVector, 4);
	if(roughness > 0.5)
		rgbm = lerp(rgbm, UNITY_SAMPLE_TEXCUBE_LOD(tex, reflectionVector, 8), 2*roughness-1);
	else
		rgbm = lerp(UNITY_SAMPLE_TEXCUBE(tex, reflectionVector), rgbm, 2*roughness);
#else
	half mip = roughness * UNITY_SPECCUBE_LOD_STEPS;
	half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(tex, reflectionVector, mip);
#endif

	return DecodeHDR_NoLinearSupportInSM2EX (rgbm, hdr);
}

half4 GetHemisphereLight(half3 normal, half3 skyvector)
{
	half  NormalContribution  = dot( normal , skyvector);
	half2 ContributionWeightsSqrt = half2(0.5, 0.5f) + half2(0.5f, -0.5f) * NormalContribution;
	half2 ContributionWeights = ContributionWeightsSqrt * ContributionWeightsSqrt * _AmbientInfo.xy;

	half4 result = ContributionWeights[0] + ContributionWeights[1];
	result.w = saturate(NormalContribution); //ContributionWeightsSqrt.x;
	return result;
}

half4 GetHemisphereLightEX(half3 normal, half3 skyvector)
{
	half  NormalContribution  = dot( normal , skyvector);
	half2 ContributionWeightsSqrt = half2(0.5, 0.5f) + half2(0.5f, -0.5f) * NormalContribution;
	half2 ContributionWeights = ContributionWeightsSqrt * ContributionWeightsSqrt;

	half4 result = ContributionWeights[0] * _UpperColor + ContributionWeights[1] * _LowerColor;
	result.w = saturate(NormalContribution); //ContributionWeightsSqrt.x;
	return result;
}

half4 GetHemisphereLightLowSpecEX(half3 normal, half3 skyvector)
{
	half  NormalContribution  = dot( normal , skyvector);
	half2 ContributionWeightsSqrt = half2(0.5, 0.5f) + half2(0.5f, -0.5f) * NormalContribution;
	half2 ContributionWeights = ContributionWeightsSqrt * ContributionWeightsSqrt;

	half4 result = ContributionWeights[0] * _UpperLowSpecColor + ContributionWeights[1] * _LowerLowSpecColor;
	result.w = ContributionWeights.x;
	result *= result;
	return result;
}

inline half4 DecodeHDREX (half4 data, half4 decodeInstructions)
{
	// If Linear mode is not supported we can skip exponent part
	#if defined(UNITY_NO_LINEAR_COLORSPACE)
		return (decodeInstructions.x * data.a) * data;
	#else
		return (decodeInstructions.x * pow(data.a, decodeInstructions.y)) * data;
	#endif
}

half4 GetEnvironmentTexture(UNITY_ARGS_TEXCUBE(tex), half3 dir, half4 hdr){
	half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(tex, dir.xyz, 0.0);
	return DecodeHDREX(rgbm, hdr); //DecodeHDR_NoLinearSupportInSM2EX (rgbm, hdr);
}

inline half GetRimFresnel( half indotv){
	return indotv * indotv;
}

half _EnvironmentRotation;

half4 Unity_GlossyEnvironmentEXPBR (UNITY_ARGS_TEXCUBE(tex), half4 hdr, half3 reflectionVector, half roughnessfactor)
{
#if UNITY_GLOSS_MATCHES_MARMOSET_TOOLBAG2 && (SHADER_TARGET >= 30)
	// TODO: remove pow, store cubemap mips differently
	half roughness = pow(roughnessfactor, 3.0/4.0);
#else
//	half roughness = roughnessfactor;
	half roughness = roughnessfactor * (1.7 - 0.7 * roughnessfactor);
#endif


#if (SHADER_API_GLCORE || SHADER_API_D3D9 || SHADER_API_D3D11)
	half3 R = reflectionVector;
//	R.x = reflectionVector.x *cos(_EnvironmentTheta) + reflectionVector.z * sin(_EnvironmentTheta);
//	R.z = -reflectionVector.x *sin(_EnvironmentTheta) + reflectionVector.z * cos(_EnvironmentTheta);
	R.x = reflectionVector.x *cos(_EnvironmentRotation) + reflectionVector.z * sin(_EnvironmentRotation);
	R.z = -reflectionVector.x *sin(_EnvironmentRotation) + reflectionVector.z * cos(_EnvironmentRotation);

	R = normalize(R);
#else
	half3 R = reflectionVector;
#endif

//#if defined(SHADER_API_GLES)
//	half mip = roughness * UNITY_SPECCUBE_LOD_STEPS;
//	half4 rgbm = texCUBElod (tex, half4(R, mip));
//#else
	half mip = roughness * UNITY_SPECCUBE_LOD_STEPS;
	half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(tex, R, mip);
//#endif

	return DecodeHDR_NoLinearSupportInSM2EX (rgbm, hdr);
}

half4 Unity_RefractEnvironmentEXPBR (UNITY_ARGS_TEXCUBE(tex), half4 hdr, half3 refractVector)
{
	half4 rgbm = UNITY_SAMPLE_TEXCUBE_LOD(tex, refractVector, 0.0);
	return DecodeHDR_NoLinearSupportInSM2EX (rgbm, hdr);
}

half2 BumpOffset( half2 uv, half height, half3 tanCamVec){
	half2 bumpUVOffset = tanCamVec.xy * height; // + _WaterInfo.w);
	bumpUVOffset += uv;
	
	return bumpUVOffset;
}

half G1V( half dotNV, float k){
	return 1.0 / (dotNV * ( 1.0 - k) + k);
}

half LightingFuncGGXEX( half3 N, half3 V, half3 L, half roughness, half F0, out half specFactor){
	half alpha = roughness * roughness;
	half3 H = normalize(L+V);
	
	half NdotL = saturate(dot(N,L));
					
	half NdotV = saturate(dot(N,V));
	half NdotH = saturate(dot(N,H));
	half LdotH = saturate(dot(L,H));
	
	half F, D, vis;
	
	//D
	half alphaSqr = alpha * alpha;
	half pi = 3.141592;
	half denom = NdotH * NdotH * (alphaSqr - 1.0) + 1.0;
	D = alphaSqr / ( pi * denom * denom);
	
	//F
	half LdotH5 = pow( 1-LdotH, 5);
	F = F0 + (1.0 - F0)*(LdotH5);
	
	//V
	half k = alpha / 2.0;
	vis = G1V(NdotL, k) * G1V(NdotV, k);
	
	specFactor = NdotL * D * F * vis;
	return NdotL;
}

float2 LightingFuncGGX_FV( float LdotH, float roughness){
	float alpha = roughness * roughness;
	
	// F
	float F_a, F_b;
	float LdotH5 = pow(1.0 - LdotH, 5);
	F_a = 1.0f;
	F_b = LdotH5;
	
	// V
	float vis;
	float k = alpha / 2.0;
	float k2 = k * k;
	float invK2 = 1.0 - k2;
	vis = 1.0 / ( LdotH * LdotH * invK2 + k2 + 1e-04);
	
	return float2(F_a*vis, F_b*vis);
}

float LightingFuncGGX_D( float NdotH, float roughness){
	float alpha = roughness * roughness;
	float alphasqr = alpha * alpha;
	float denom = NdotH * NdotH * ( alphasqr - 1.0) + 1.0;
	
	float D = alphasqr / (UNITY_PI * denom * denom);
	return D;
}

float LightingFuncGGX_OPT3(float3 N, float3 V, float3 L, float roughness, float F0){
	float3 H = normalize(L+V);
	
	float NdotL = saturate(dot(N,L));
	float LdotH = saturate(dot(L,H));
	float NdotH = saturate(dot(N,H));
	
	float D = LightingFuncGGX_D(NdotH, roughness);
	float2 FV_helper = LightingFuncGGX_FV(LdotH, roughness);
	float FV = F0 * FV_helper.x + (1.0 - F0) * FV_helper.y;
	float spec = NdotL * D * FV;
	
	return spec;
}

half beckmannSpecular(half ndoth, half roughness) {
  half cos2Alpha = ndoth * ndoth;
  half tan2Alpha = (cos2Alpha - 1.0) / cos2Alpha;
  half roughness2 = roughness * roughness;
  half denom = 3.141592 * roughness2 * cos2Alpha * cos2Alpha;
  half result = exp(tan2Alpha / roughness2) / denom;
  #if defined(SHADER_TARGET_GLSL)
  result = max(result, 0.0); //result = result > 4.0 ? 0.0 : result;
  #endif
  return result;
}

half GGXNDFBlinn_Approx(half Roughness, half RoL)
{
	half a = Roughness * Roughness;
	half a2 = a * a + 1e-04;
	#if defined(SHADER_TARGET_GLSL)
	float rcp_a2 = 1.0 / a2;
	#else
	float rcp_a2 = rcp(a2);
	#endif
	
	// 0.5 / ln(2), 0.275 / ln(2)
	half c = 0.72134752 * rcp_a2 + 0.39674113;
	return (rcp_a2 / 3.141592) * exp2(c * RoL - c);
}

inline half GGXTerm (half NdotH, half roughness)
{
	half a = roughness * roughness;
	half a2 = a * a;
	half d = NdotH * NdotH * (a2 - 1.f) + 1.f;
	return a2 / (UNITY_PI * d * d);
}

inline half roughnessToSpecPower (half roughness)
{
#if UNITY_GLOSS_MATCHES_MARMOSET_TOOLBAG2
	// from https://s3.amazonaws.com/docs.knaldtech.com/knald/1.0.0/lys_power_drops.html
	half n = 10.0 / log2((1-roughness)*0.968 + 0.03);
#if defined(SHADER_API_PS3) || defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
	// Prevent fp16 overflow when running on platforms where half is actually in use.
	n = max(n,-255.9370);  //i.e. less than sqrt(65504)
#endif
	return n * n;

	// NOTE: another approximate approach to match Marmoset gloss curve is to
	// multiply roughness by 0.7599 in the code below (makes SpecPower range 4..N instead of 1..N)
#else
	half m = max(1e-4f, roughness * roughness);			// m is the true academic roughness.
	
	half n = (2.0 / (m*m)) - 2.0;						// https://dl.dropboxusercontent.com/u/55891920/papers/mm_brdf.pdf
	n = max(n, 1e-4f);									// prevent possible cases of pow(0,0), which could happen when roughness is 1.0 and NdotH is zero
	return n;
#endif
}

half3 ShadeSH9EX (half4 normal)
{
	#ifdef USE_LIGHT_PROBE
	half3 x1, x2, x3;
	
	// Linear + constant polynomial terms
	x1.r = dot(unity_SHAr,normal);
	x1.g = dot(unity_SHAg,normal);
	x1.b = dot(unity_SHAb,normal);
	
	// 4 of the quadratic polynomials
	half4 vB = normal.xyzz * normal.yzzx;
	x2.r = dot(unity_SHBr,vB);
	x2.g = dot(unity_SHBg,vB);
	x2.b = dot(unity_SHBb,vB);
	
	// Final quadratic polynomial
	half vC = normal.x*normal.x - normal.y*normal.y;
	x3 = unity_SHC.rgb * vC;
	return x2 + x3 + x1;
	#else
	return 1.0;
	#endif
} 

// normal should be normalized, w=1.0
half3 ShadeSH3OrderEX(half4 normal)
{
	#ifdef USE_LIGHT_PROBE
	half3 x2, x3;
	// 4 of the quadratic polynomials
	half4 vB = normal.xyzz * normal.yzzx;
	x2.r = dot(unity_SHBr,vB);
	x2.g = dot(unity_SHBg,vB);
	x2.b = dot(unity_SHBb,vB);
	
	// Final quadratic polynomial
	half vC = normal.x*normal.x - normal.y*normal.y;
	x3 = unity_SHC.rgb * vC;

	return x2 + x3;
	#else
	return 1.0;
	#endif	
}

// normal should be normalized, w=1.0
half3 ShadeSH12OrderEX (half4 normal)
{
	#ifdef USE_LIGHT_PROBE
	half3 x1;
	
	// Linear + constant polynomial terms
	x1.r = dot(unity_SHAr,normal);
	x1.g = dot(unity_SHAg,normal);
	x1.b = dot(unity_SHAb,normal);

	// Final linear term
	return x1;
	#else
	return 1.0;
	#endif		
}

half4 _vfColGradDelta;
half4 _vfColGradBase;
half4 _fogColor_lowSpec;
float4 _fogInfo;
half4 _fogColor;
half _fotDistTweak_lowSpec;

half3 ComputeSimpleFog(half3 outColor, float factor)
{
	return lerp(outColor, _fogColor, factor);
}

half ComputeVolumetricFog( in float3 cameraToWorldPos )
{
	#define volFogHeightDensityAtViewer _fogInfo.x
	#define atmosphereScale 			_fogInfo.y
	#define vfRampParams				_fogInfo.z
	
	float fogInt = 1.0;
	
//	float c_slopeThreshold = 0.01;
//	if( abs( cameraToWorldPos.y ) > c_slopeThreshold )
//	{
//		float t = atmosphereScale * cameraToWorldPos.y;
//		fogInt *= min(( 1.0 - exp( -t ) ) / t, 1024.0);
//	}

	//half volFogHeightDensityAtViewer = (1.0 / log(2.0)) * _fogDensity * exp( -_atmosphereScale * ( _WorldSpaceCameraPos.y - _groundLevel));
	float l = length( cameraToWorldPos) * vfRampParams;// * 0.01;
	float u = l * l * volFogHeightDensityAtViewer;

	fogInt = fogInt * u;
	float f = exp2( -fogInt);

	return f;
}

half4 GetVolumetricFogColorDistanceBased(float3 cameraToWorldPos )
{
	half fog = ComputeVolumetricFog(cameraToWorldPos);
	half l = saturate(normalize(cameraToWorldPos.xyz).y);
	half3 fogColor = _vfColGradBase.xyz + l * _vfColGradDelta.xyz;
	return half4(fogColor, fog);
}


half ComputeVolumetricFog( in float sqrCameraToWorldPosLength )
{
	float fogInt = 1.0;
	
//	half l = cameraToWorldPosLength * vfRampParams;// * 0.01;
//	half u = l * l * volFogHeightDensityAtViewer;
	//float u = sqrCameraToWorldPosLength * vfRampParams * volFogHeightDensityAtViewer;
	float u = sqrCameraToWorldPosLength * vfRampParams;
	fogInt = fogInt * u;
	float f = exp2( -fogInt);
	
	return f;
}

half4 GetVolumetricFogColorDistanceBased(float sqrCameraToWorldPosLength, half cameraHeight)
{
	half fog = ComputeVolumetricFog(sqrCameraToWorldPosLength);
	half l = saturate(cameraHeight);
	half3 fogColor = _vfColGradBase.xyz + l * _vfColGradDelta.xyz;
	return half4(fogColor, fog);
}

half4 GetFogColorDistanceBased(half4 inColor, half cameradepth)
{
	half depth = max(cameradepth - _fotDistTweak_lowSpec, 0.0);
	half fog = exp2(-depth * _fogInfo.w);
	return lerp(_fogColor_lowSpec, inColor, fog);
}

half4 TonemapPhotographic( half4 inColor)
{
	const half _ExposureAdjustment = 1.5;
	return 1-exp2(-_ExposureAdjustment * (inColor));
}

inline void GetLightingInfo( in half4 specTex, in half ndoth, in half ndotv, in half ldoth, 
						out half roughness, out half reflectivity, out half oneMinusReflectivity, out half specfactor, out half grazingTerm, out half fresnelTerm){
	half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;

	//specTex = 1;
	half oneMinusRoughness = specTex.x * _Glossiness;
	half metallic 		   = specTex.y * _Metallic;

	oneMinusReflectivity = (1.0 - metallic) * oneMinusDielectricSpec;
	half oneMinusF0 = oneMinusDielectricSpec;
	half4 roughnessReflectivityFresnelF0 = 1.0 - half4( oneMinusRoughness, oneMinusReflectivity, ndotv, oneMinusF0);

	roughness = roughnessReflectivityFresnelF0.x;
	reflectivity = roughnessReflectivityFresnelF0.y;
	half INdotV = roughnessReflectivityFresnelF0.z;
	half F0 = roughnessReflectivityFresnelF0.w;

	fresnelTerm = INdotV * INdotV;
	grazingTerm = saturate(oneMinusRoughness + reflectivity); //(1-oneMinusReflectivity));
	//grazingTerm = saturate(_Glossiness + _Metallic);
	
	half4 specdistribute = tex2D(_GGXLookUpTex, half2(ndoth * ndoth, roughness));
	half D = dot(specdistribute.xy, half2((255.0 / 65025.0) * 8.0, 8.0));
	half4 FVhelpers = tex2D(_GGXLookUpTex, half2(ldoth, roughness));
	half FV = (F0 + oneMinusF0 * FVhelpers.w) / max(FVhelpers.z, 0.001);
	specfactor  = D * FV;
}

inline void GetLightingInfoMetallic( in half4 specTex, in half ndotv, 
						out half roughness, out half reflectivity, out half oneMinusReflectivity, out half grazingTerm, out half fresnelTerm){
	half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;

	half oneMinusRoughness = _Glossiness;
	half metallic 			= specTex.y * _Metallic;

	oneMinusReflectivity = (1.0 - metallic) * oneMinusDielectricSpec;
	half oneMinusF0 = oneMinusDielectricSpec;
	half4 roughnessReflectivityFresnelF0 = 1.0 - half4( oneMinusRoughness, oneMinusReflectivity, ndotv, oneMinusF0);

	roughness 	= roughnessReflectivityFresnelF0.x;
	reflectivity 	= roughnessReflectivityFresnelF0.y;
	half INdotV 		= roughnessReflectivityFresnelF0.z;
	half F0			= roughnessReflectivityFresnelF0.w;

	fresnelTerm = INdotV * INdotV;
	grazingTerm = saturate(oneMinusRoughness + reflectivity); //(1-oneMinusReflectivity));
}

inline void GetLightingInfoSimple( in half4 specTex, in half ndoth, in half ldoth, out half specfactor, out half oneMinusReflectivity){
	half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
	half oneMinusRoughness = specTex.x * _Glossiness;
	half metallic 			= specTex.y * _Metallic;
	oneMinusReflectivity = (1.0 - metallic) *  oneMinusDielectricSpec;
	half oneMinusF0 = oneMinusDielectricSpec;

	half2 roughnessF0 = 1.0 - half2(oneMinusRoughness, oneMinusF0);
	half4 specdistribute = tex2D(_GGXLookUpTex, half2(ndoth * ndoth, roughnessF0.x));
	half D = dot(specdistribute.xy, half2((255.0 / 65025.0) * 8.0, 8.0));
	half4 FVhelpers = tex2D(_GGXLookUpTex, half2(ldoth, roughnessF0.x));
	half FV = (roughnessF0.y + oneMinusF0 * FVhelpers.w) / max(FVhelpers.z, 0.001);
	specfactor  = D * FV;
}