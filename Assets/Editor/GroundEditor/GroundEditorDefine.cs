using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public partial class GroundEditor : EditorWindow
{
    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private class Pixel
    {
        //------------------------------------------------------------------------------------------------------------------------------------------------------------
        public Vector3 _pos;
        public Vector2 _uv;
        public Vector3 _faceNormal;

        //------------------------------------------------------------------------------------------------------------------------------------------------------------
        public bool IsCollide(Ray ray, float radius, ref float dist)
        {
            if (Vector3.Dot(ray.direction, _faceNormal) > 0.0f)
                return false;

            Vector3 dir = _pos - ray.origin;
            Vector3 projDir = Vector3.Project(dir, ray.direction);

            dist = (dir - projDir).magnitude;
            return (dist < radius);
        }
    }

    //----------------------------------------------------------------------------------------------------------------------------------------------------------------
    private class Polygon
    {
        //------------------------------------------------------------------------------------------------------------------------------------------------------------
        public Vector3[] _pos;
        public Vector3 _posDir1;
        public Vector3 _posDir2;

        public Vector2[] _uv;
        public Vector2 _uvDir1;
        public Vector2 _uvDir2;

        public Vector3 _faceNormal;

        //------------------------------------------------------------------------------------------------------------------------------------------------------------
        public Polygon(Matrix4x4 mtxLocalToWorld, Vector3 v1, Vector3 v2, Vector3 v3, Vector2 uv1, Vector2 uv2, Vector2 uv3)
        {
            _pos = new Vector3[3] { mtxLocalToWorld.MultiplyPoint(v1), mtxLocalToWorld.MultiplyPoint(v2), mtxLocalToWorld.MultiplyPoint(v3) };
            _uv = new Vector2[3] { uv1, uv2, uv3 };

            _posDir1 = _pos[1] - _pos[0];
            _posDir2 = _pos[2] - _pos[0];

            _uvDir1 = _uv[1] - _uv[0];
            _uvDir2 = _uv[2] - _uv[0];

            _faceNormal = Vector3.Cross(_posDir1, _posDir2).normalized;
        }

        //------------------------------------------------------------------------------------------------------------------------------------------------------------
        public bool IsInPos(Vector3 pos, out float U, out float V)
        {
            Vector3 _posDir3 = pos - _pos[0];

            float dot11 = Vector3.Dot(_posDir1, _posDir1);
            float dot12 = Vector3.Dot(_posDir1, _posDir2);
            float dot22 = Vector3.Dot(_posDir2, _posDir2);
            float dot31 = Vector3.Dot(_posDir3, _posDir1);
            float dot32 = Vector3.Dot(_posDir3, _posDir2);

            float invDenom = 1.0f / (dot12 * dot12 - dot11 * dot22);

            U = (dot12 * dot32 - dot22 * dot31) * invDenom;
            V = (dot12 * dot31 - dot11 * dot32) * invDenom;
            if (U < 0.0f || U > 1.0f)
                return false;
            if (V < 0.0f || V > 1.0f)
                return false;

            return (U + V < 1.0f);
        }

        //------------------------------------------------------------------------------------------------------------------------------------------------------------
        public bool IsInUV(Vector2 uv, out float U, out float V)
        {
            Vector2 _uvDir3 = uv - _uv[0];

            float dot11 = Vector2.Dot(_uvDir1, _uvDir1);
            float dot12 = Vector2.Dot(_uvDir1, _uvDir2);
            float dot22 = Vector2.Dot(_uvDir2, _uvDir2);
            float dot31 = Vector2.Dot(_uvDir3, _uvDir1);
            float dot32 = Vector2.Dot(_uvDir3, _uvDir2);

            float invDenom = 1.0f / (dot12 * dot12 - dot11 * dot22);

            U = (dot12 * dot32 - dot22 * dot31) * invDenom;
            V = (dot12 * dot31 - dot11 * dot32) * invDenom;
            if (U < 0.0f || U > 1.0f)
                return false;            
            if (V < 0.0f || V > 1.0f)
                return false;

            return (U + V < 1.0f);
        }

        //------------------------------------------------------------------------------------------------------------------------------------------------------------
        public List<Pixel> MakePixelData(Texture2D tex)
        {
            List<Pixel> pixels = new List<Pixel>();

            Vector2 minUV = new Vector2(Mathf.Min(_uv[0].x, _uv[1].x, _uv[2].x), Mathf.Min(_uv[0].y, _uv[1].y, _uv[2].y));
            Vector2 maxUV = new Vector2(Mathf.Max(_uv[0].x, _uv[1].x, _uv[2].x), Mathf.Max(_uv[0].y, _uv[1].y, _uv[2].y));
            Vector2 unitUV = new Vector2(1.0f / tex.width, 1.0f / tex.height);

            minUV.x = (int)(minUV.x / unitUV.x) * unitUV.x;
            minUV.y = (int)(minUV.y / unitUV.y) * unitUV.y;
            maxUV.x = (int)(Mathf.Ceil(maxUV.x / unitUV.x)) * unitUV.x;
            maxUV.y = (int)(Mathf.Ceil(maxUV.y / unitUV.y)) * unitUV.y;

            Vector2 uv = new Vector2();
            float bcU, bcV;
            for(uv.x = minUV.x; uv.x <= maxUV.x; uv.x += unitUV.x)
            {
                for (uv.y = minUV.y; uv.y <= maxUV.y; uv.y += unitUV.y)
                {
                    if (this.IsInUV(uv, out bcU, out bcV))
                    {
                        pixels.Add(
                            new Pixel()
                            {
                                _pos = _pos[0] + _posDir1 * bcU + _posDir2 * bcV,
                                _uv = uv,
                                _faceNormal = _faceNormal
                            });
                    }
                }
            }            

            return pixels;
        }
    }
}
