namespace CustomShaderGUIs
{
    /// <summary>
    /// Custom inspector for Creatush/RoundedRect. Reuses the same
    /// GroupedShaderGUI base class as UberSpriteGUI - if you already have
    /// Editor/GroupedShaderGUI.cs from the sprite bundle, just drop this file
    /// in alongside it.
    ///
    /// Main Shape / Corner Radius / Fill are plain collapsible sections (no
    /// single toggle gates all of their properties - e.g. Fill's Opacity and
    /// Softness apply whether or not "Use Gradient" is on, so they stay
    /// visible regardless). Outline 1, Outline 2, and Shadow each have a real
    /// gating toggle drawn right in their section header.
    /// </summary>
    public class RoundedRectGUI : GroupedShaderGUI
    {
        protected override string[] BasePropertyNames => new string[0];

        protected override Group[] GetGroups() => new[]
        {
            new Group("Main Shape", null, new[]
            {
                "_Width", "_Height",
            }),

            new Group("Corner Radius", null, new[]
            {
                "_CornerRadiusTL", "_CornerRadiusTR", "_CornerRadiusBR", "_CornerRadiusBL",
            }),

            new Group("Fill", null, new[]
            {
                "_UseGradient", "_ColorStart", "_ColorEnd", "_GradientAngle", "_GradientBlend",
                "_FillOpacity", "_FillSoftness",
            }),

            new Group("Outline 1", "_UseOutline1", new[]
            {
                "_UseOutline1Gradient", "_Outline1Color", "_Outline1ColorStart", "_Outline1ColorEnd",
                "_Outline1Offset", "_Outline1Thickness",
            }),

            new Group("Outline 2", "_UseOutline2", new[]
            {
                "_UseOutline2Gradient", "_Outline2Color", "_Outline2ColorStart", "_Outline2ColorEnd",
                "_Outline2Offset", "_Outline2Thickness",
            }),

            new Group("Shadow", "_UseShadow", new[]
            {
                "_ShadowColor", "_ShadowOffset", "_ShadowSmoothness", "_ShadowOpacity",
                "_ShadowUseCustomRadius", "_ShadowRadiusTL", "_ShadowRadiusTR", "_ShadowRadiusBR", "_ShadowRadiusBL",
            }),
        };
    }
}
