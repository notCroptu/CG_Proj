using UnityEngine;
using UnityEngine.Rendering;

public class UVMaterial : MonoBehaviour
{
    [SerializeField] private Material _uvMaterial;
    [SerializeField] private Renderer _rendererToApplyUV;
    private CommandBuffer _commandBuffer;
    [SerializeField] private RenderTexture _alphaTexture;
    private int _alphaDelay;

    private void Start()
    {
         // Unshare material.
        _uvMaterial = new Material(_uvMaterial);

        _alphaTexture = new RenderTexture(Screen.width, Screen.height, 24, RenderTextureFormat.Default);
        _alphaTexture.graphicsFormat = UnityEngine.Experimental.Rendering.GraphicsFormat.R32G32B32A32_SFloat;
        _alphaTexture.Create();

        _alphaDelay = Shader.PropertyToID("_AlphaDelay");

        _commandBuffer = new CommandBuffer { name = "Capture UV Texture Alpha" };
        _commandBuffer.SetRenderTarget(_alphaTexture);

        // Clear previous!
        _commandBuffer.ClearRenderTarget(true, true, Color.clear);
        _commandBuffer.DrawRenderer(_rendererToApplyUV, _uvMaterial);


        // Can't just add a new material, need to make a new array
        Material[] materials = new Material[_rendererToApplyUV.materials.Length + 1];
        _rendererToApplyUV.materials.CopyTo(materials, 0);
        materials[materials.Length - 1] = _uvMaterial;
        _rendererToApplyUV.materials = materials;
    }

    private void Update()
    {
        Matrix4x4 viewProjMatrix = Camera.main.projectionMatrix * Camera.main.worldToCameraMatrix;
        // Pass the matrix and texture to the shader
        _uvMaterial.SetFloat("_AlphaDelayWidth", _alphaTexture.width);
        _uvMaterial.SetFloat("_AlphaDelayHeight", _alphaTexture.height);

        _uvMaterial.SetTexture(_alphaDelay, _alphaTexture);
    }

    private void OnRenderObject()
    {
        Graphics.ExecuteCommandBuffer(_commandBuffer);
    }
}
