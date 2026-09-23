namespace CustomShaderGUIs
{
    /// <summary>
    /// Custom inspector for Creatush/TooltipSDF. Reuses the same
    /// GroupedShaderGUI base class as RoundedRectGUI/SpriteExtensionGUI/
    /// UberSpriteGUI - drop this file in next to Editor/GroupedShaderGUI.cs.
    ///
    /// Every outline (1-5) and the shadow are enabled purely by width > 0,
    /// same as SpriteExtension - there's no dedicated on/off toggle to gate
    /// a group header with, so each is a plain collapsible section.
    /// </summary>
    public class TooltipSDFGUI : GroupedShaderGUI
    {
        protected override string[] BasePropertyNames => new string[0];

        protected override Group[] GetGroups() => new[]
        {
            new Group("Canvas and Shape", null, new[]
            {
                "_CanvasSize", "_Width", "_Height",
            }),

            new Group("Corner Radius", null, new[]
            {
                "_RadTL", "_RadTR", "_RadBR", "_RadBL",
            }),

            new Group("Face", null, new[]
            {
                "_FaceTransparent", "_FaceColor", "_FaceColor2", "_UseGradient",
                "_InnerShadowColor", "_InnerShadowSize",
            }),

            new Group("Tip", null, new[]
            {
                "_TipPosX", "_TipPosY", "_TipRot", "_TipSize", "_TipWidth",
            }),

            new Group("Outline 1", null, new[]
            {
                "_O1Width", "_O1Color", "_O1Delta", "_O1OffX", "_O1OffY",
            }),

            new Group("Outline 2", null, new[]
            {
                "_O2Width", "_O2Color", "_O2Delta", "_O2OffX", "_O2OffY",
            }),

            new Group("Outline 3", null, new[]
            {
                "_O3Width", "_O3Color", "_O3Delta", "_O3OffX", "_O3OffY",
            }),

            new Group("Outline 4", null, new[]
            {
                "_O4Width", "_O4Color", "_O4Delta", "_O4OffX", "_O4OffY",
            }),

            new Group("Outline 5", null, new[]
            {
                "_O5Width", "_O5Color", "_O5Delta", "_O5OffX", "_O5OffY",
            }),

            new Group("Shadow", null, new[]
            {
                "_ShadWidth", "_ShadColor", "_ShadDelta", "_ShadOffX", "_ShadOffY",
                "_ShadOpacity", "_ShadSmooth",
            }),

            new Group("Rendering", null, new[]
            {
                "_AlphaClip", "_OverallOpacity",
            }),
        };
    }
}
