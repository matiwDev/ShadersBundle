using System.IO;
using UnityEditor;
using UnityEngine;

namespace CustomShaderGUIs
{
    /// <summary>
    /// [Gradient] - a generic, reusable MaterialPropertyDrawer. Write it once,
    /// use it on any Texture property in any shader:
    ///
    ///     [Gradient] _MyGradientTex ("Label", 2D) = "white" {}
    ///
    /// and the material Inspector shows a native gradient bar in its place
    /// (Unity's own EditorGUI.GradientField - same widget/popup as any
    /// built-in Gradient field). No custom ShaderGUI, no companion asset, no
    /// linking step: this is the whole thing.
    ///
    /// Persistence: the actual editable Gradient (all its color/alpha keys,
    /// not just its baked pixels) is stored as JSON in the baked texture's
    /// own TextureImporter.userData. That's what makes the texture asset
    /// itself the single source of truth - reopening the Inspector reads the
    /// keys back out of the very PNG the shader already uses, so there's
    /// nothing extra to keep track of.
    ///
    /// On every edit: bakes a 1-row texture (128x1 by default; use
    /// [Gradient(256)] etc. to override) and writes/overwrites it at
    /// "<MaterialFolder>/Generated Gradients/<MaterialName>_<PropertyName>.png",
    /// creating that folder next to the material the first time it's needed.
    /// </summary>
    public class GradientDrawer : MaterialPropertyDrawer
    {
        private const string FolderName = "Generated Gradients";
        private readonly int _resolution;

        public GradientDrawer() : this(128f) { }
        public GradientDrawer(float resolution) { _resolution = Mathf.Max(2, (int)resolution); }

        public override void OnGUI(Rect position, MaterialProperty prop, string label, MaterialEditor editor)
        {
            if (prop.propertyType != UnityEngine.Rendering.ShaderPropertyType.Texture)
            {
                EditorGUI.HelpBox(position, "[Gradient] only works on a Texture (2D) property.", MessageType.Error);
                return;
            }

            Material material = editor.target as Material;
            Texture2D currentTex = prop.textureValue as Texture2D;
            Gradient gradient = LoadGradient(currentTex) ?? DefaultGradient();

            EditorGUI.BeginChangeCheck();
            Gradient edited = EditorGUI.GradientField(position, label, gradient);
            if (EditorGUI.EndChangeCheck() && material != null)
            {
                prop.textureValue = BakeAndSave(material, prop.name, edited, _resolution);
            }
        }

        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            return EditorGUIUtility.singleLineHeight;
        }

        // --- Persistence: read the Gradient's keys back out of the baked texture's userData ---

        private static Gradient LoadGradient(Texture2D tex)
        {
            if (tex == null) return null;
            string path = AssetDatabase.GetAssetPath(tex);
            if (string.IsNullOrEmpty(path)) return null;
            if (!(AssetImporter.GetAtPath(path) is TextureImporter importer)) return null;
            if (string.IsNullOrEmpty(importer.userData)) return null;

            try
            {
                GradientData data = JsonUtility.FromJson<GradientData>(importer.userData);
                return data?.ToGradient();
            }
            catch
            {
                return null; // userData wasn't ours (e.g. a hand-picked texture) - fall back to default
            }
        }

        private static Gradient DefaultGradient()
        {
            var g = new Gradient();
            g.SetKeys(
                new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(Color.white, 1f) },
                new[] { new GradientAlphaKey(1f, 0f), new GradientAlphaKey(0f, 1f) }
            );
            return g;
        }

        // --- Baking: pixels + userData, written next to the material ---

        private static Texture2D BakeAndSave(Material material, string propertyName, Gradient gradient, int resolution)
        {
            string matPath = AssetDatabase.GetAssetPath(material);
            if (string.IsNullOrEmpty(matPath))
            {
                Debug.LogWarning("[Gradient]: save this Material as an asset first, then edit its gradient.");
                return null;
            }

            string matDir = Path.GetDirectoryName(matPath).Replace('\\', '/');
            string bakeDir = $"{matDir}/{FolderName}";
            if (!AssetDatabase.IsValidFolder(bakeDir))
            {
                AssetDatabase.CreateFolder(matDir, FolderName);
            }

            string baseName = $"{material.name}_{propertyName.TrimStart('_')}";
            string texPath = $"{bakeDir}/{baseName}.png";

            var tex = new Texture2D(resolution, 1, TextureFormat.RGBA32, false, false);
            var pixels = new Color[resolution];
            for (int x = 0; x < resolution; x++)
            {
                float t = resolution <= 1 ? 0f : x / (float)(resolution - 1);
                pixels[x] = gradient.Evaluate(t);
            }
            tex.SetPixels(pixels);
            tex.Apply(false, false);
            byte[] png = tex.EncodeToPNG();
            Object.DestroyImmediate(tex);

            File.WriteAllBytes(texPath, png);
            AssetDatabase.ImportAsset(texPath, ImportAssetOptions.ForceUpdate);

            if (AssetImporter.GetAtPath(texPath) is TextureImporter importer)
            {
                importer.textureType = TextureImporterType.Default;
                importer.alphaIsTransparency = true;
                importer.mipmapEnabled = false;
                importer.wrapMode = TextureWrapMode.Clamp;
                importer.filterMode = FilterMode.Bilinear;
                importer.sRGBTexture = true;
                importer.userData = JsonUtility.ToJson(GradientData.FromGradient(gradient));
                importer.SaveAndReimport();
            }

            return AssetDatabase.LoadAssetAtPath<Texture2D>(texPath);
        }

        [System.Serializable]
        private class GradientData
        {
            public Color[] colors;
            public float[] colorTimes;
            public float[] alphas;
            public float[] alphaTimes;
            public int mode;

            public static GradientData FromGradient(Gradient g)
            {
                var d = new GradientData
                {
                    colors = new Color[g.colorKeys.Length],
                    colorTimes = new float[g.colorKeys.Length],
                    alphas = new float[g.alphaKeys.Length],
                    alphaTimes = new float[g.alphaKeys.Length],
                    mode = (int)g.mode
                };
                for (int i = 0; i < g.colorKeys.Length; i++)
                {
                    d.colors[i] = g.colorKeys[i].color;
                    d.colorTimes[i] = g.colorKeys[i].time;
                }
                for (int i = 0; i < g.alphaKeys.Length; i++)
                {
                    d.alphas[i] = g.alphaKeys[i].alpha;
                    d.alphaTimes[i] = g.alphaKeys[i].time;
                }
                return d;
            }

            public Gradient ToGradient()
            {
                var colorKeys = new GradientColorKey[colors.Length];
                for (int i = 0; i < colors.Length; i++) colorKeys[i] = new GradientColorKey(colors[i], colorTimes[i]);
                var alphaKeys = new GradientAlphaKey[alphas.Length];
                for (int i = 0; i < alphas.Length; i++) alphaKeys[i] = new GradientAlphaKey(alphas[i], alphaTimes[i]);

                var g = new Gradient();
                g.SetKeys(colorKeys, alphaKeys);
                g.mode = (GradientMode)mode;
                return g;
            }
        }
    }
}
