namespace CustomShaderGUIs
{
    /// <summary>
    /// Custom inspector for the RoundedPanelStack Shader Graph. Reuses the
    /// same GroupedShaderGUI base class as the hand-written Creatush shaders
    /// - drop this file in next to Editor/GroupedShaderGUI.cs.
    ///
    /// The graph's Blackboard only had "General" and "Shadow" as real
    /// categories; the four outlines, overall opacity, and gradient tiling
    /// were all sitting in the uncategorized bucket. Split those into
    /// Outline 1-4 and a Rendering section here rather than showing them as
    /// one long undifferentiated list.
    ///
    /// IMPORTANT: unlike a hand-written .shader file, a Shader Graph asset
    /// has no CustomEditor line you can add by hand. Wire this up instead
    /// via: open the .shadergraph asset -> Graph Inspector -> Graph Settings
    /// tab -> "Custom Editor GUI" field -> enter
    /// CustomShaderGUIs.RoundedPanelStackGUI
    /// </summary>
    public class RoundedPanelStackGUI : GroupedShaderGUI
    {
        protected override string[] BasePropertyNames => new string[0];

        protected override Group[] GetGroups() => new[]
        {
            new Group("General", null, new[]
            {
                "_MainTex", "_colorA", "_colorB", "_transparentFace", "_direction",
                "_radius", "_blendHeight", "_width", "_height", "_AlphaClipThreshold",
            }),

            new Group("Outline 1", null, new[]
            {
                "_outline1Color", "_outline1Width", "_outline1radiusDelta",
            }),

            new Group("Outline 2", null, new[]
            {
                "_outline2Color", "_outline2Width", "_outline2radiusDelta",
            }),

            new Group("Outline 3", null, new[]
            {
                "_outline3Color", "_outline3Width", "_outline3radiusDelta",
            }),

            new Group("Outline 4", null, new[]
            {
                "_outline4Color", "_outline4Width", "_outline4radiusDelta",
                "_outline4heightDelta", "_outline4widthDelta", "_outline4offsetX",
                "_outline4offsetY", "_outline4Spread",
            }),

            new Group("Shadow", null, new[]
            {
                "_shadowColor", "_shadowSmooth", "_shadowOpacity",
                "_shadowOffsetX", "_shadowOffsetY", "_shadowWidthDelta", "_shadowHeightDelta",
            }),

            new Group("Rendering", null, new[]
            {
                "_overallOpacity", "_gradientTilingX", "_gradientTilingY",
            }),
        };
    }
}
