using UnityEditor;
using UnityEngine;

namespace CustomShaderGUIs
{
    /// <summary>
    /// Generic collapsible-group ShaderGUI.
    ///
    /// Renders a fixed list of "always visible" properties first, then one
    /// foldout section per feature group. Each section has its own
    /// expand/collapse arrow AND (if it has a toggle property) its own
    /// "Enabled" checkbox drawn through Unity's normal property pipeline,
    /// so [Toggle(_KEYWORD_ON)] keyword syncing keeps working exactly as
    /// it would in the default inspector.
    ///
    /// Subclass this and implement BasePropertyNames + GetGroups() to wire
    /// it up for a specific shader; see UberSpriteGUI.cs for an example.
    /// </summary>
    public abstract class GroupedShaderGUI : ShaderGUI
    {
        public class Group
        {
            public readonly string title;
            public readonly string togglePropertyName; // null = plain foldout, no toggle
            public readonly string[] memberPropertyNames;
            public readonly bool hideMembersWhenDisabled;

            public Group(string title, string togglePropertyName, string[] memberPropertyNames, bool hideMembersWhenDisabled = true)
            {
                this.title = title;
                this.togglePropertyName = togglePropertyName;
                this.memberPropertyNames = memberPropertyNames;
                this.hideMembersWhenDisabled = hideMembersWhenDisabled;
            }
        }

        /// <summary>Properties always shown above every group, in order.</summary>
        protected abstract string[] BasePropertyNames { get; }

        /// <summary>Group definitions, in the order they should be drawn.</summary>
        protected abstract Group[] GetGroups();

        /// <summary>Optional: properties to hide entirely (e.g. auto-managed stencil state).</summary>
        protected virtual string[] AlwaysHiddenPropertyNames => System.Array.Empty<string>();

        /// <summary>
        /// Override to fully take over drawing for one property name (e.g. to
        /// replace a plain texture field with richer authoring UI). Return
        /// true if you drew something, so the default ShaderProperty call
        /// for that name is skipped.
        /// </summary>
        protected virtual bool DrawCustomProperty(MaterialEditor editor, MaterialProperty[] allProps, string name)
        {
            return false;
        }

        private string _shaderKey;

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            Material material = materialEditor.target as Material;
            _shaderKey = material != null && material.shader != null ? material.shader.name : GetType().Name;

            DrawProperties(materialEditor, properties, BasePropertyNames);

            EditorGUILayout.Space(4);

            foreach (Group group in GetGroups())
            {
                DrawGroup(materialEditor, properties, group);
            }

            EditorGUILayout.Space(8);
            materialEditor.RenderQueueField();
            materialEditor.EnableInstancingField();
        }

        private void DrawProperties(MaterialEditor editor, MaterialProperty[] props, string[] names)
        {
            foreach (string name in names)
            {
                if (DrawCustomProperty(editor, props, name)) continue;
                MaterialProperty p = FindProperty(name, props, false);
                if (p != null) editor.ShaderProperty(p, p.displayName);
            }
        }

        private void DrawGroup(MaterialEditor editor, MaterialProperty[] props, Group group)
        {
            string key = $"GroupedShaderGUI.{_shaderKey}.{group.title}";
            bool expanded = SessionState.GetBool(key, false);

            MaterialProperty toggleProp = string.IsNullOrEmpty(group.togglePropertyName)
                ? null
                : FindProperty(group.togglePropertyName, props, false);
            bool enabled = toggleProp == null || toggleProp.floatValue > 0.5f;

            EditorGUILayout.BeginVertical(EditorStyles.helpBox);

            using (new EditorGUILayout.HorizontalScope())
            {
                expanded = EditorGUILayout.Foldout(expanded, group.title, true, EditorStyles.foldoutHeader);
                if (toggleProp != null)
                {
                    GUILayout.FlexibleSpace();
                    EditorGUIUtility.labelWidth = 50;
                    editor.ShaderProperty(toggleProp, "Enabled");
                    EditorGUIUtility.labelWidth = 0; // reset to default
                    enabled = toggleProp.floatValue > 0.5f;
                }
            }

            SessionState.SetBool(key, expanded);

            if (expanded)
            {
                EditorGUI.indentLevel++;
                bool showMembers = enabled || !group.hideMembersWhenDisabled;
                if (!showMembers)
                {
                    EditorGUILayout.HelpBox("Enable this section above to edit its properties.", MessageType.None);
                }
                else
                {
                    DrawProperties(editor, props, group.memberPropertyNames);
                }
                EditorGUI.indentLevel--;
            }

            EditorGUILayout.EndVertical();
        }
    }
}
