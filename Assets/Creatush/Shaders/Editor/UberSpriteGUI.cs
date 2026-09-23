using UnityEngine;

namespace CustomShaderGUIs
{
    /// <summary>
    /// Custom inspector for Custom/2D/UberSprite. Wired up via the shader's
    /// "CustomEditor" directive, so it's picked automatically — no manual
    /// setup needed beyond having this script in an Editor/ folder.
    /// </summary>
    public class UberSpriteGUI : GroupedShaderGUI
    {
        protected override string[] BasePropertyNames => new[]
        {
            "_MainTex",
            "_Color",
        };

        protected override Group[] GetGroups() => new[]
        {
            new Group("Mirror", "_UseMirror", new[]
            {
                "_MirrorX", "_ReverseX", "_MirrorY", "_ReverseY",
            }),

            new Group("Pixelate", "_UsePixelate", new[]
            {
                "_PixelCountX", "_PixelCountY", "_ColorLevels",
            }),

            new Group("HSV and Grayscale", "_UseHSV", new[]
            {
                "_HueShift", "_Saturation", "_Brightness", "_Grayscale",
            }),

            new Group("Dissolve", "_UseDissolve", new[]
            {
                "_NoiseTex", "_DissolveAmount", "_EdgeWidth", "_EdgeColor", "_EdgeIntensity",
            }),

            new Group("Hit Flash", "_UseHitFlash", new[]
            {
                "_FlashColor", "_FlashAmount",
            }),

            new Group("Outline and Glow", "_UseOutline", new[]
            {
                "_OutlineColor", "_OutlineWidth", "_OutlineOnly",
            }),

            new Group("Shine Sweep", "_UseShineSweep", new[]
            {
                "_SweepColor", "_SweepWidth", "_SweepSoftness", "_SweepAngle", "_SweepSpeed", "_SweepInterval",
            }),

            // No toggle property -> plain collapsible foldout, always shown when expanded.
            new Group("UI / Masking (advanced)", null, new[]
            {
                "_UseUIAlphaClip",
            }, hideMembersWhenDisabled: false),
        };
    }
}
