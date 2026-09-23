using System;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;

namespace _PapayaKit.Papaya.Shaders.ShaderGraph.Editor
{
	public class MirrorGUI : ShaderGUI
	{
		public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
		{
			EditorGUILayout.LabelField("Mirroring 1.0", EditorStyles.boldLabel);
			EditorGUILayout.LabelField("Papaya Custom Shader", EditorStyles.miniLabel);
			EditorGUILayout.Space();
			CoreEditorUtils.DrawSplitter();
			
			base.OnGUI (materialEditor, properties);

			EditorGUILayout.Space();
			GUIStyle textStyle = EditorStyles.helpBox;
			textStyle.wordWrap = true;
			textStyle.fontSize = 12;
			EditorGUILayout.LabelField(
			"Notice that you won't be able to use the slice in the direction you are mirroring. " +
			"Meaning that when using a quarter you can use slicing at all.", textStyle);
		}
	}
}
