// RadialRaysGUI.cs
// Custom ShaderGUI for the "UI/RadialRays" shader.
// Replaces the raw texture slot for _RayGradient with a proper Unity Gradient field
// (RGBA - Unity's Gradient type natively supports alpha keys). The gradient is baked
// into a small lookup texture, and the original Gradient data is stored in that
// texture's importer.userData as JSON, so it can be read back and re-edited later.
//
// Place this file inside a folder named "Editor" anywhere under Assets.

#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public class RadialRaysGUI : ShaderGUI
{
    const int GradientTextureWidth = 256;
    const string GeneratedFolderName = "GeneratedGradients";

    // In-memory cache keyed by the baked texture's instance ID. This is the source of
    // truth while the Editor session is open, so the field never appears "stuck" while
    // waiting on an asset reimport/round-trip. The on-disk userData is only used as a
    // fallback after a domain reload (entering Play mode, script recompile, etc).
    static readonly Dictionary<int, Gradient> s_GradientCache = new Dictionary<int, Gradient>();

    [Serializable]
    private class GradientSerializationData
    {
        public GradientColorKey[] colorKeys;
        public GradientAlphaKey[] alphaKeys;
        public GradientMode mode;
    }

    // Concise display name + tooltip for every property we show, keyed by shader property
    // name. Keeping this in C# (rather than editing the .shader Properties strings) means
    // the working shader logic and defaults are never touched by a cosmetic relabel.
    static readonly Dictionary<string, (string label, string tooltip)> s_Labels =
        new Dictionary<string, (string, string)>
        {
            { "_RayCount", ("Ray Count", "Number of rays distributed evenly across the arc range.") },
            { "_ArcRange", ("Arc Range", "Total sweep of the ray fan, in degrees (0-360).") },
            { "_RaySpacing", ("Ray Spacing", "Gap between rays. 0 = rays touch, 1 = hairline thin.") },
            { "_Opacity", ("Opacity", "Overall opacity multiplier applied to every ray.") },
            { "_OpacitySpread", ("Opacity Spread", "Fades rays out toward both ends of the arc. 0 = uniform, 1 = strong falloff at the extremes.") },

            { "_UseVertexColor", ("Use Vertex Color", "On: tint using the Image/Graphic color (and CanvasGroup alpha). Off: tint using the Ray Gradient below.") },
            { "_RayGradient", ("Ray Gradient (RGBA)", "Custom gradient used when Use Vertex Color is off. The gradient's alpha channel also affects opacity.") },
            { "_GradientRadial", ("Radial Gradient", "On: gradient runs from center to outer edge. Off: gradient runs across the arc angle.") },

            { "_ArcOffset", ("Arc Rotation", "Rotates the fixed arc window around the circle. Independent from the ray Spin Speed below.") },
            { "_RayFeather", ("Edge Softness", "Anti-aliasing softness of each ray's side edges.") },
            { "_InnerRadius", ("Inner Radius", "Cuts a hole out of the center of the ray fan.") },
            { "_OuterRadius", ("Outer Radius", "How far the rays extend from the center.") },

            { "_RotationSpeed", ("Spin Speed", "Degrees per second the rays rotate inside the fixed arc window. Negative values reverse direction.") },
            { "_AutoSweepSpeed", ("Sweep Speed", "Cycles per second for an automatic reveal sweep across the arc. 0 disables the sweep.") },
            { "_SweepFeather", ("Sweep Softness", "Softness of the animated sweep's leading edge.") },

            { "_StencilComp", ("Stencil Comparison", "Set automatically by Mask / RectMask2D. Change only for custom masking setups.") },
            { "_Stencil", ("Stencil ID", "Set automatically by Mask / RectMask2D. Change only for custom masking setups.") },
            { "_StencilOp", ("Stencil Operation", "Set automatically by Mask / RectMask2D. Change only for custom masking setups.") },
            { "_StencilWriteMask", ("Stencil Write Mask", "Set automatically by Mask / RectMask2D. Change only for custom masking setups.") },
            { "_StencilReadMask", ("Stencil Read Mask", "Set automatically by Mask / RectMask2D. Change only for custom masking setups.") },
            { "_ColorMask", ("Color Mask", "Restricts which color channels this graphic writes to.") },
            { "_UseUIAlphaClip", ("Alpha Clip", "Enables alpha-tested clipping, required by some masked UI setups.") },
        };

    // Properties intentionally never drawn: the sprite is assigned automatically by the
    // Image/RawImage component, and Tint is a rarely-needed extra multiplier on top of
    // the Graphic's own color - hiding both keeps the inspector focused on ray controls.
    static readonly HashSet<string> s_Hidden = new HashSet<string> { "_MainTex", "_Color" };

    static bool s_ShowAdvanced;

    static readonly Color HeaderRays = new Color(0.20f, 0.45f, 0.85f);
    static readonly Color HeaderTint = new Color(0.60f, 0.30f, 0.75f);
    static readonly Color HeaderShape = new Color(0.20f, 0.60f, 0.50f);
    static readonly Color HeaderAnim = new Color(0.85f, 0.55f, 0.15f);

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material mat = materialEditor.target as Material;

        DrawSectionHeader("Radial Rays", HeaderRays);
        BeginSectionBody();
        DrawProp(materialEditor, properties, "_RayCount");
        DrawProp(materialEditor, properties, "_ArcRange");
        DrawProp(materialEditor, properties, "_RaySpacing");
        DrawProp(materialEditor, properties, "_Opacity");
        DrawProp(materialEditor, properties, "_OpacitySpread");
        EndSectionBody();

        DrawSectionHeader("Tint", HeaderTint);
        BeginSectionBody();
        MaterialProperty useVertexColor = FindProp(properties, "_UseVertexColor");
        DrawProp(materialEditor, properties, "_UseVertexColor");

        bool gradientActive = useVertexColor == null || useVertexColor.floatValue < 0.5f;
        using (new EditorGUI.DisabledScope(!gradientActive))
        {
            MaterialProperty gradientProp = FindProp(properties, "_RayGradient");
            if (gradientProp != null)
                DrawGradientField(materialEditor, mat, gradientProp);
            DrawProp(materialEditor, properties, "_GradientRadial");
        }
        EndSectionBody();

        DrawSectionHeader("Shape", HeaderShape);
        BeginSectionBody();
        DrawProp(materialEditor, properties, "_ArcOffset");
        DrawProp(materialEditor, properties, "_RayFeather");
        DrawProp(materialEditor, properties, "_InnerRadius");
        DrawProp(materialEditor, properties, "_OuterRadius");
        EndSectionBody();

        DrawSectionHeader("Animation", HeaderAnim);
        BeginSectionBody();
        DrawProp(materialEditor, properties, "_RotationSpeed");
        DrawProp(materialEditor, properties, "_AutoSweepSpeed");
        DrawProp(materialEditor, properties, "_SweepFeather");
        EndSectionBody();

        EditorGUILayout.Space(6);
        s_ShowAdvanced = EditorGUILayout.Foldout(s_ShowAdvanced, "Advanced (UI Masking)", true, EditorStyles.foldoutHeader);
        if (s_ShowAdvanced)
        {
            BeginSectionBody();
            DrawProp(materialEditor, properties, "_UseUIAlphaClip");
            DrawProp(materialEditor, properties, "_StencilComp");
            DrawProp(materialEditor, properties, "_Stencil");
            DrawProp(materialEditor, properties, "_StencilOp");
            DrawProp(materialEditor, properties, "_StencilWriteMask");
            DrawProp(materialEditor, properties, "_StencilReadMask");
            DrawProp(materialEditor, properties, "_ColorMask");
            EditorGUILayout.Space(4);
            materialEditor.RenderQueueField();
            materialEditor.EnableInstancingField();
            EndSectionBody();
        }
    }

    static MaterialProperty FindProp(MaterialProperty[] properties, string name)
    {
        foreach (MaterialProperty p in properties)
            if (p.name == name) return p;
        return null;
    }

    static void DrawProp(MaterialEditor editor, MaterialProperty[] properties, string name)
    {
        if (s_Hidden.Contains(name)) return;
        MaterialProperty prop = FindProp(properties, name);
        if (prop == null) return;

        var (label, tooltip) = s_Labels.TryGetValue(name, out var meta) ? meta : (prop.displayName, "");
        editor.ShaderProperty(prop, new GUIContent(label, tooltip));
    }

    static void DrawSectionHeader(string title, Color color)
    {
        EditorGUILayout.Space(6);
        Rect rect = EditorGUILayout.GetControlRect(false, 22);
        EditorGUI.DrawRect(rect, color);

        GUIStyle style = new GUIStyle(EditorStyles.boldLabel)
        {
            alignment = TextAnchor.MiddleLeft,
            padding = new RectOffset(8, 4, 0, 0)
        };
        style.normal.textColor = Color.white;

        EditorGUI.LabelField(rect, title, style);
    }

    static void BeginSectionBody()
    {
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        EditorGUI.indentLevel++;
    }

    static void EndSectionBody()
    {
        EditorGUI.indentLevel--;
        EditorGUILayout.EndVertical();
    }

    void DrawGradientField(MaterialEditor editor, Material mat, MaterialProperty prop)
    {
        var (label, tooltip) = s_Labels.TryGetValue(prop.name, out var meta) ? meta : (prop.displayName, "");

        Texture2D currentTex = prop.textureValue as Texture2D;
        Gradient current = GetCachedGradient(currentTex) ?? LoadGradientFromTexture(currentTex) ?? DefaultGradient();

        EditorGUI.BeginChangeCheck();
        Gradient edited = EditorGUILayout.GradientField(new GUIContent(label, tooltip), current);
        if (EditorGUI.EndChangeCheck())
        {
            Texture2D tex = BakeGradientToTexture(edited, currentTex, mat);
            s_GradientCache[tex.GetInstanceID()] = edited;

            editor.RegisterPropertyChangeUndo(prop.name);
            prop.textureValue = tex;

            // Make sure every material this editor is targeting, and the texture asset
            // itself, are actually flagged dirty and the view gets told to redraw -
            // otherwise the swapped texture reference can sit un-rendered until some
            // unrelated repaint happens.
            foreach (UnityEngine.Object target in editor.targets)
                EditorUtility.SetDirty(target);
            EditorUtility.SetDirty(tex);
            SceneView.RepaintAll();
            EditorApplication.QueuePlayerLoopUpdate();
        }
    }

    static Gradient GetCachedGradient(Texture2D tex)
    {
        if (tex == null) return null;
        return s_GradientCache.TryGetValue(tex.GetInstanceID(), out Gradient g) ? g : null;
    }

    static Gradient DefaultGradient()
    {
        Gradient g = new Gradient();
        g.SetKeys(
            new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(Color.white, 1f) },
            new[] { new GradientAlphaKey(1f, 0f), new GradientAlphaKey(0f, 1f) });
        return g;
    }

    static string GetTargetFolder(Material mat)
    {
        string materialPath = AssetDatabase.GetAssetPath(mat);
        if (!string.IsNullOrEmpty(materialPath))
        {
            string materialFolder = Path.GetDirectoryName(materialPath).Replace("\\", "/");
            return materialFolder + "/" + GeneratedFolderName;
        }

        // Material hasn't been saved as an asset yet - fall back to a top-level folder.
        return "Assets/" + GeneratedFolderName;
    }

    static Texture2D BakeGradientToTexture(Gradient gradient, Texture2D existing, Material mat)
    {
        string path;
        if (existing != null && AssetDatabase.Contains(existing))
        {
            path = AssetDatabase.GetAssetPath(existing);
        }
        else
        {
            string folder = GetTargetFolder(mat);
            if (!AssetDatabase.IsValidFolder(folder))
            {
                string parent = Path.GetDirectoryName(folder).Replace("\\", "/");
                string newFolderName = Path.GetFileName(folder);
                AssetDatabase.CreateFolder(parent, newFolderName);
            }
            string fileName = mat.name + "_RayGradient.png";
            path = AssetDatabase.GenerateUniqueAssetPath(folder + "/" + fileName);
        }

        Texture2D tex = new Texture2D(GradientTextureWidth, 1, TextureFormat.RGBA32, false, false);
        for (int x = 0; x < GradientTextureWidth; x++)
        {
            float t = x / (float)(GradientTextureWidth - 1);
            tex.SetPixel(x, 0, gradient.Evaluate(t));
        }
        tex.Apply();

        File.WriteAllBytes(path, tex.EncodeToPNG());
        UnityEngine.Object.DestroyImmediate(tex);
        AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceUpdate | ImportAssetOptions.ForceSynchronousImport);

        TextureImporter importer = AssetImporter.GetAtPath(path) as TextureImporter;
        if (importer != null)
        {
            importer.textureType = TextureImporterType.Default;
            importer.sRGBTexture = true;
            importer.alphaSource = TextureImporterAlphaSource.FromInput;
            importer.alphaIsTransparency = true;
            importer.mipmapEnabled = false;
            importer.wrapMode = TextureWrapMode.Clamp;
            importer.filterMode = FilterMode.Bilinear;

            var data = new GradientSerializationData
            {
                colorKeys = gradient.colorKeys,
                alphaKeys = gradient.alphaKeys,
                mode = gradient.mode
            };
            importer.userData = JsonUtility.ToJson(data);
            importer.SaveAndReimport();
        }

        return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
    }

    static Gradient LoadGradientFromTexture(Texture2D tex)
    {
        if (tex == null) return null;
        string path = AssetDatabase.GetAssetPath(tex);
        if (string.IsNullOrEmpty(path)) return null;

        TextureImporter importer = AssetImporter.GetAtPath(path) as TextureImporter;
        if (importer == null || string.IsNullOrEmpty(importer.userData)) return null;

        try
        {
            var data = JsonUtility.FromJson<GradientSerializationData>(importer.userData);
            if (data == null || data.colorKeys == null || data.colorKeys.Length == 0) return null;

            Gradient g = new Gradient();
            g.SetKeys(data.colorKeys, data.alphaKeys);
            g.mode = data.mode;
            return g;
        }
        catch
        {
            return null;
        }
    }
}
#endif
