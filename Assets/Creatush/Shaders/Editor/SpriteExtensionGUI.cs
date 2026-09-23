namespace CustomShaderGUIs
{
    /// <summary>
    /// Custom inspector for Creatush/SpriteExtension. Reuses the same
    /// GroupedShaderGUI base class as RoundedRectGUI/UberSpriteGUI - drop
    /// this file in next to Editor/GroupedShaderGUI.cs.
    ///
    /// Unlike RoundedRect, this shader has no on/off toggle properties at
    /// all - each effect (outline 1, outline 2, shadow) is always computed
    /// and just fades out via its own color alpha / width, so every group
    /// here is a plain collapsible section with no header checkbox.
    /// </summary>
    public class SpriteExtensionGUI : GroupedShaderGUI
    {
        protected override string[] BasePropertyNames => new string[0];

        protected override Group[] GetGroups() => new[]
        {
            new Group("Main Image", null, new[]
            {
                "_GrayscaleAmount", "_OverlayColor",
            }),

            new Group("Outline 1", null, new[]
            {
                "_OutlineColor1", "_OutlineWidth1", "_OutlineOffset1",
            }),

            new Group("Outline 2", null, new[]
            {
                "_OutlineColor2", "_OutlineWidth2", "_OutlineOffset2",
            }),

            new Group("Shadow", null, new[]
            {
                "_ShadowColor", "_ShadowOffset", "_ShadowSoftness",
            }),
        };
    }
}
