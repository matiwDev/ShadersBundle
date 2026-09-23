namespace CustomShaderGUIs
{
    /// <summary>
    /// Custom inspector for the RoundedPanelFloat Shader Graph. Reuses the
    /// same GroupedShaderGUI base class as the hand-written Creatush shaders
    /// - drop this file in next to Editor/GroupedShaderGUI.cs.
    ///
    /// Groups mirror the graph's own Blackboard categories (General,
    /// Panel #1-#4) exactly, since that's already how the author organized
    /// it. Panel #1 and Panel #2 each have a real "Use Gradient" keyword
    /// toggle gating their whole section; Panel #3 and Panel #4 have no such
    /// toggle in the graph, so they're plain collapsible sections.
    ///
    /// IMPORTANT: unlike a hand-written .shader file, a Shader Graph asset
    /// has no CustomEditor line you can add by hand. Wire this up instead
    /// via: open the .shadergraph asset -> Graph Inspector -> Graph Settings
    /// tab -> "Custom Editor GUI" field -> enter
    /// CustomShaderGUIs.RoundedPanelFloatGUI
    /// </summary>
    public class RoundedPanelFloatGUI : GroupedShaderGUI
    {
        protected override string[] BasePropertyNames => new string[0];

        protected override Group[] GetGroups() => new[]
        {
            new Group("General", null, new[]
            {
                "_MainTex", "_Radius", "_Height", "_width", "_Overall_Opacity",
            }),

            new Group("Panel #1", "_USE_GRADIENT_5", new[]
            {
                "_Color_C_5", "_Color_A_5", "_Color_B_5", "_Blend_Height_5", "_Direction_5",
                "_Height_1", "_Width_1", "_Spread_5", "_Offset_X_5", "_Offset_Y_5",
                "_North_West_5", "_North_East_5", "_South_East_5", "_South_West_5",
            }),

            new Group("Panel #2", "_USE_GRADIENT_3", new[]
            {
                "_Color_C_3", "_USE_PANEL_1_ROUNDNESS", "_Color_A_3", "_Color_B_3",
                "_Blend_Height_3", "_Direction_3", "_Height_3", "_Width_3", "_Spread_3",
                "_Offset_X_3", "_Offset_Y_3", "_North_West_1", "_North_East_1",
                "_South_East_1", "_South_West_1",
            }),

            new Group("Panel #3", null, new[]
            {
                "_Color_C_2", "_Height_Delta_2", "_Width_Delta_2", "_Radius_Delta_2",
                "_Spread_2", "_Offset_X_2", "_Offset_Y_2",
            }),

            new Group("Panel #4", null, new[]
            {
                "_Color_C_1", "_Height_Delta_1", "_Width_Delta_1", "_Radius_Delta_1",
                "_Spread_1", "_Offset_X_1", "_Offset_Y_1",
            }),
        };
    }
}
