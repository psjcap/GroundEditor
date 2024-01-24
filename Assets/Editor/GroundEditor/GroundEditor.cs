using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public partial class GroundEditor : EditorWindow
{
    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private Projector _brushProjector;

    private GameObject _groundObject;
    private List<Renderer> _groundObjectCandidate = new List<Renderer>();
    private List<string> _groundObjectCandidateName = new List<string>();
    private int _groundObjectIndex = 0;

    private Texture2D _groundMaskTex;
    private Texture2D[] _groundLayerTex;
    private bool _groundMaskTexReadable;
    private bool _groundMaskTexCompress;
    private TextureImporterFormat _groundMaskTexImporterFormat;
    private TextureImporterCompression _groundMaskTexImporterCompression;

    private List<Polygon> _polygons;
    private List<Pixel> _pixels;
    
    private bool _isModified = false;

    public enum GroundLayer { Cliff = 0, Road = 1, Soil = 2, Wet = 3, };
    private GroundLayer _editingLayer = GroundLayer.Cliff;

    public enum BrushEditType { Add = 0, Remove = 1, Fix = 2 };
    private BrushEditType _brushEditType = BrushEditType.Add;

    private float _brushRadius = 5.0f;
    private float _brushInnerRadius = 1.0f;
    private float _brushValue = 0.5f;

    private double _lastUpdateTime = 0.0f;

    private bool _showTexelPosition = false;
    private List<GameObject> _texelPositions = null;

    private int _clearChannelIndex = 0;

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    [MenuItem("Window/GroundEditor")]
    public static void Menu()
    {
        EditorWindow.GetWindow<GroundEditor>();
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private void OnEnable()
    {
        //SceneView.onSceneGUIDelegate += OnSceneGUI;
        SceneView.duringSceneGui += OnSceneGUI;

        _lastUpdateTime = EditorApplication.timeSinceStartup;
        this.FindGroundObjects();        
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private void OnDisable()
    {
        //SceneView.onSceneGUIDelegate -= OnSceneGUI;
        SceneView.duringSceneGui -= OnSceneGUI;

        if(_isModified)
        {
            if(EditorUtility.DisplayDialog("GroundEditor", "저장하시겠습니까?", "저장 후 종료", "저장하지 않고 종료"))
            this.Save();
        }

        if (_groundMaskTex != null)
        {
            string texPath = AssetDatabase.GetAssetPath(_groundMaskTex);
            TextureImporter texImporter = AssetImporter.GetAtPath(texPath) as TextureImporter;
            texImporter.isReadable = _groundMaskTexReadable;            

            TextureImporterPlatformSettings platformSetting = this.GetTexturePlatformSetting(texImporter);
            platformSetting.textureCompression = _groundMaskTexImporterCompression;
            platformSetting.format = _groundMaskTexImporterFormat;
            texImporter.SetPlatformTextureSettings(platformSetting);

            AssetDatabase.ImportAsset(texPath);
        }

        if (_brushProjector != null)
        {
            DestroyImmediate(_brushProjector.material);
            DestroyImmediate(_brushProjector.gameObject);
        }

        if(_texelPositions != null)
        {
            for (int ii = 0; ii < _texelPositions.Count; ++ii)
                DestroyImmediate(_texelPositions[ii]);
        }
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private void OnGUI()
    {
        EditorGUILayout.BeginVertical();

        if (_groundObjectCandidate.Count > 1)
        {
            EditorGUILayout.HelpBox("Ground는 하나씩만 편집이 가능합니다.", MessageType.Error);
            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("Ground", GUILayout.Width(60.0f));
            int newGroundIndex = EditorGUILayout.Popup(_groundObjectIndex, _groundObjectCandidateName.ToArray());
            if (newGroundIndex != _groundObjectIndex)
            {
                _groundObjectIndex = newGroundIndex;
                this.InitData(_groundObjectCandidate[_groundObjectIndex]);
            }
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space();
            EditorGUILayout.Space();
        }

        _editingLayer = (GroundLayer)GUILayout.SelectionGrid((int)_editingLayer, _groundLayerTex, _groundLayerTex.Length, GUILayout.Width(200.0f), GUILayout.Height(50.0f));
        _editingLayer = (GroundLayer)GUILayout.SelectionGrid((int)_editingLayer, new string[] { GroundLayer.Cliff.ToString(), GroundLayer.Road.ToString(), GroundLayer.Soil.ToString(), GroundLayer.Wet.ToString() }, _groundLayerTex.Length, GUILayout.Width(200.0f), GUILayout.Height(20.0f));

        string[] brushEditTypeText = new string[] { "칠하기", "지우기", "고정값 덮어쓰기" };
        _brushEditType = (BrushEditType)GUILayout.SelectionGrid((int)_brushEditType, brushEditTypeText, brushEditTypeText.Length);

        _brushRadius = EditorGUILayout.Slider("Brush Radius", _brushRadius, 0.0f, 30.0f);
        if(_brushEditType != BrushEditType.Fix)
            _brushInnerRadius = Mathf.Clamp(EditorGUILayout.Slider("Brush Inner Radius", _brushInnerRadius, 0.0F, _brushRadius), 0.0f, _brushRadius);

        _brushValue = EditorGUILayout.Slider("Brush Value", _brushValue, 0.0f, 1.0f);

        EditorGUILayout.BeginHorizontal();
        if (GUILayout.Button("Save")) this.Save();
        if (GUILayout.Button("Revert")) this.Revert();
        EditorGUILayout.EndHorizontal();

        bool showTexelPosition = EditorGUILayout.Toggle("Show Texel Position", _showTexelPosition);
        if(_showTexelPosition != showTexelPosition)
        {
            _showTexelPosition = showTexelPosition;
            if(_showTexelPosition)
            {
                _texelPositions = new List<GameObject>();
                GameObject texelPrefab = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Editor/GroundEditor/GroundEditorTexel.prefab");
                for (int ii = 0; ii < _pixels.Count; ++ii)
                    _texelPositions.Add(Instantiate(texelPrefab, _pixels[ii]._pos, Quaternion.identity));
            }
            else
            {
                for (int ii = 0; ii < _texelPositions.Count; ++ii)
                    DestroyImmediate(_texelPositions[ii]);
                _texelPositions.Clear();
            }
        }

        EditorGUILayout.BeginHorizontal();
        _clearChannelIndex = EditorGUILayout.Popup(_clearChannelIndex, new string[] { "R Channel", "G Channel", "B Channel", "A Channel" });
        if(GUILayout.Button("Clear"))
        {
            for(int xx = 0; xx < _groundMaskTex.width; ++xx)
            {
                for (int yy = 0; yy < _groundMaskTex.height; ++yy)
                {
                    Color color = _groundMaskTex.GetPixel(xx, yy);
                    if (_clearChannelIndex == 0) color.r = 0.0f;
                    else if (_clearChannelIndex == 1) color.g = 0.0f;
                    else if (_clearChannelIndex == 2) color.b = 0.0f;
                    else if (_clearChannelIndex == 3) color.a = 0.0f;

                    _groundMaskTex.SetPixel(xx, yy, color);
                }
            }

            _groundMaskTex.Apply();
            _isModified = true;
        }
        EditorGUILayout.EndHorizontal();

        EditorGUILayout.EndVertical();
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private void OnSceneGUI(SceneView sceneView)
    {
        float deltaTime = (float)(EditorApplication.timeSinceStartup - _lastUpdateTime);
        _lastUpdateTime = EditorApplication.timeSinceStartup;

        if (_groundObject == null || _groundObject.transform.hasChanged)
        {
            this.FindGroundObjects();
            if (_groundObject == null)
                return;
        }

        Event e = Event.current;
        if (e == null)
            return;

        Ray ray = HandleUtility.GUIPointToWorldRay(e.mousePosition);
        this.MoveBrush(ray, _brushRadius, _brushEditType != BrushEditType.Fix ? _brushInnerRadius : _brushRadius);

        if (e.type == EventType.Layout)
        {
            if(e.button != 1)
                HandleUtility.AddDefaultControl(GUIUtility.GetControlID(GetHashCode(), FocusType.Passive));
        }
        else if (e.button == 0 && (e.type == EventType.MouseDown || e.type == EventType.MouseDrag))
        {
            bool isModified = false;
            for (int ii = 0; ii < _pixels.Count; ++ii)
            {
                Pixel pixel = _pixels[ii];
                float dist = 0.0f;
                if (pixel.IsCollide(ray, _brushRadius, ref dist))
                {
                    isModified = true;

                    float brushValue = _brushValue;
                    if(_brushEditType != BrushEditType.Fix && dist > _brushInnerRadius)
                        brushValue *= (1.0f - (dist - _brushInnerRadius) / (_brushRadius - _brushInnerRadius));

                    int xPos = (int)(pixel._uv.x * _groundMaskTex.width);
                    int yPos = (int)(pixel._uv.y * _groundMaskTex.height);

                    Color newColor = _groundMaskTex.GetPixel(xPos, yPos);
                    float bPct = newColor.b;
                    float gPct = newColor.g * (1.0f - newColor.b);
                    float rPct = (1.0f - newColor.g) * (1.0f - newColor.b);                    

                    if (_editingLayer == GroundLayer.Cliff)
                    {
                        if (_brushEditType == BrushEditType.Add)
                            rPct = Mathf.Clamp(rPct + brushValue, 0.0f, 1.0f);
                        else if (_brushEditType == BrushEditType.Remove)
                            rPct = Mathf.Clamp(rPct - brushValue, 0.0f, 1.0f);
                        else if (_brushEditType == BrushEditType.Fix)
                            rPct = Mathf.Clamp(brushValue, 0.0f, 1.0f);

                        float invPct = 1.0f - rPct;
                        float remainPct = gPct + bPct;

                        gPct = (remainPct != 0.0f) ? invPct * (gPct / remainPct) : 0.0f;
                        bPct = (remainPct != 0.0f) ? invPct * (bPct / remainPct) : 0.0f;

                        newColor.b = bPct;
                        newColor.g = gPct / (1.0f - newColor.b);
                    }
                    else if (_editingLayer == GroundLayer.Road)
                    {
                        if (_brushEditType == BrushEditType.Add)
                            gPct = Mathf.Clamp(gPct + brushValue, 0.0f, 1.0f);
                        else if (_brushEditType == BrushEditType.Remove)
                            rPct = Mathf.Clamp(gPct - brushValue, 0.0f, 1.0f);
                        else if (_brushEditType == BrushEditType.Fix)
                            gPct = Mathf.Clamp(brushValue, 0.0f, 1.0f);

                        float invPct = 1.0f - gPct;
                        float remainPct = rPct + bPct;

                        rPct = (remainPct != 0.0f) ? invPct * (rPct / remainPct) : 0.0f;
                        bPct = (remainPct != 0.0f) ? invPct * (bPct / remainPct) : 0.0f;

                        newColor.b = bPct;
                        newColor.g = gPct / (1.0f - newColor.b);
                    }
                    else if (_editingLayer == GroundLayer.Soil)
                    {
                        if (_brushEditType == BrushEditType.Add)
                            bPct = Mathf.Clamp(bPct + brushValue, 0.0f, 1.0f);
                        else if (_brushEditType == BrushEditType.Remove)
                            bPct = Mathf.Clamp(bPct - brushValue, 0.0f, 1.0f);
                        else if (_brushEditType == BrushEditType.Fix)
                            bPct = Mathf.Clamp(brushValue, 0.0f, 1.0f);

                        float invPct = 1.0f - bPct;
                        float remainPct = rPct + gPct;

                        rPct = (remainPct != 0.0f) ? invPct * (rPct / remainPct) : 0.0f;
                        gPct = (remainPct != 0.0f) ? invPct * (gPct / remainPct) : 0.0f;

                        newColor.b = bPct;
                        newColor.g = gPct / (1.0f - newColor.b);
                    }
                    else if (_editingLayer == GroundLayer.Wet)
                    {
                        if (_brushEditType == BrushEditType.Add)
                            newColor.r = Mathf.Clamp(newColor.r + brushValue, 0.0f, 1.0f);
                        else if (_brushEditType == BrushEditType.Remove)
                            newColor.r = Mathf.Clamp(newColor.r - brushValue, 0.0f, 1.0f);
                        else if (_brushEditType == BrushEditType.Fix)
                            newColor.r = Mathf.Clamp(brushValue, 0.0f, 1.0f);
                    }

                    _groundMaskTex.SetPixel(xPos, yPos, newColor);
                    isModified = true;
                }
            }

            if (isModified)
            {
                _groundMaskTex.Apply(true);
                _isModified = true;
            }

            e.Use();
        }
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private void MakeBrushProjector()
    {
        if (_brushProjector == null)
        {
            GameObject brushObject = Instantiate<GameObject>(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Editor/GroundEditor/GroundBrush.prefab"));
            brushObject.hideFlags = HideFlags.HideAndDontSave;

            _brushProjector = brushObject.GetComponent<Projector>();

            Material newMaterial = new Material(_brushProjector.material);
            _brushProjector.material = newMaterial;
        }
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private void MoveBrush(Ray ray, float radius, float innerRadius)
    {
        this.MakeBrushProjector();
        if(_brushProjector != null)
        {
            _brushProjector.transform.position = ray.origin;
            _brushProjector.transform.LookAt(ray.origin + ray.direction, Vector3.up);

            _brushProjector.material.SetVector("_Origin", ray.origin);
            _brushProjector.material.SetVector("_Direction", ray.direction);
            _brushProjector.material.SetFloat("_Radius", _brushRadius);
            _brushProjector.material.SetFloat("_InnerRadius", innerRadius);

            _brushProjector.orthographic = true;
            _brushProjector.orthographicSize = radius;
            _brushProjector.ignoreLayers = ~(1 << _groundObject.layer);
        }
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private void FindGroundObjects()
    {
        _groundObjectCandidate.Clear();
        _groundObjectCandidateName.Clear();

        MeshRenderer[] renderers = FindObjectsOfType<MeshRenderer>();
        for (int ii = 0; ii < renderers.Length; ++ii)
        {
            MeshRenderer renderer = renderers[ii];
            if (renderer.sharedMaterial == null) continue;
            if (renderer.sharedMaterial.shader == null) continue;
            if (renderer.sharedMaterial.shader.name != "MK_Environment/MK_BG_DNM_Layer") continue;
            if (renderer.sharedMaterial.GetTexture("_MaskTex") == null) continue;

            MeshFilter meshFilter = renderer.gameObject.GetComponent<MeshFilter>();
            if (meshFilter == null) continue;
            if (meshFilter.sharedMesh == null) continue;

            _groundObjectCandidate.Add(renderer);
            _groundObjectCandidateName.Add(renderer.name);
        }

        if (_groundObjectCandidate.Count > 0)
        {
            _groundObjectIndex = 0;
            this.InitData(_groundObjectCandidate[0]);
        }
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private void InitData(Renderer renderer)
    {
        _groundObject = renderer.gameObject;
        _groundMaskTex = renderer.sharedMaterial.GetTexture("_MaskTex") as Texture2D;
        _groundLayerTex = new Texture2D[4];
        _groundLayerTex[0] = renderer.sharedMaterial.GetTexture("_LayerTex") as Texture2D;
        _groundLayerTex[1] = renderer.sharedMaterial.GetTexture("_Layer1Tex") as Texture2D;
        _groundLayerTex[2] = renderer.sharedMaterial.GetTexture("_Layer2Tex") as Texture2D;
        _groundLayerTex[3] = Texture2D.whiteTexture;

        _groundObject.transform.hasChanged = false;

        string texPath = AssetDatabase.GetAssetPath(_groundMaskTex);
        TextureImporter texImporter = AssetImporter.GetAtPath(texPath) as TextureImporter;
        _groundMaskTexReadable = texImporter.isReadable;


        TextureImporterPlatformSettings platformSetting = this.GetTexturePlatformSetting(texImporter);
        _groundMaskTexImporterCompression = platformSetting.textureCompression;
        _groundMaskTexImporterFormat = platformSetting.format;

        texImporter.isReadable = true;

        platformSetting.textureCompression = TextureImporterCompression.Uncompressed;
        platformSetting.format = TextureImporterFormat.RGBA32;
        texImporter.SetPlatformTextureSettings(platformSetting);

        AssetDatabase.ImportAsset(texPath);

        _pixels = new List<Pixel>();
        _polygons = new List<Polygon>();

        MeshFilter meshFilter = renderer.gameObject.GetComponent<MeshFilter>();
        Mesh mesh = meshFilter.sharedMesh;
        for (int vert = 0; vert < mesh.triangles.Length; vert += 3)
        {
            Polygon poly = new Polygon(
                _groundObject.transform.localToWorldMatrix,
                mesh.vertices[mesh.triangles[vert]],
                mesh.vertices[mesh.triangles[vert + 1]],
                mesh.vertices[mesh.triangles[vert + 2]],
                mesh.uv[mesh.triangles[vert]],
                mesh.uv[mesh.triangles[vert + 1]],
                mesh.uv[mesh.triangles[vert + 2]]
            );

            _pixels.AddRange(poly.MakePixelData(_groundMaskTex));
            _polygons.Add(poly);
        }
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private void Save()
    {
        if (_groundMaskTex == null)
            return;

        string texPath = AssetDatabase.GetAssetPath(_groundMaskTex);
        string extension = System.IO.Path.GetExtension(texPath);

        byte[] textureData = null;
        if (extension == ".tga")
            textureData = _groundMaskTex.EncodeToTGA();
        else if (extension == ".png")
            textureData = _groundMaskTex.EncodeToPNG();
        else if (extension == ".jpg")
            textureData = _groundMaskTex.EncodeToJPG();

        System.IO.File.WriteAllBytes(texPath, textureData);
        AssetDatabase.ImportAsset(texPath);

        _isModified = false;
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private void Revert()
    {
        if (_groundMaskTex == null)
            return;

        string texPath = AssetDatabase.GetAssetPath(_groundMaskTex);
        AssetDatabase.ImportAsset(texPath);
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private TextureImporterPlatformSettings GetTexturePlatformSetting(TextureImporter texImporter)
    {
        #if UNITY_ANDROID
        string importerName = "Android";
        #elif UNITY_IPHONE
        string importerName = "iPhone";
        #elif UNITY_STANDALONE_WIN
        string importerName = "Standalone";
        #endif

        TextureImporterPlatformSettings platformSetting = texImporter.GetPlatformTextureSettings(importerName);
        if (platformSetting.overridden == false)
            platformSetting = texImporter.GetDefaultPlatformTextureSettings();

        return platformSetting;
    }
}

