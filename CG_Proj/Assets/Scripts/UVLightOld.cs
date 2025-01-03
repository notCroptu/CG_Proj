using UnityEngine;
using UnityEngine.UI;

public class UVLightOld : MonoBehaviour
{
    [SerializeField] private GameObject _uvSpotLightObject;
    [SerializeField] private Light _uvLight;
    [SerializeField] private RawImage _shadowDebugger;
    private int _lightPositionID;
    private int _spotLightDirID;
    private int _lightedID;
    private bool isOn;

    private void Start()
    {
        // Convert the strings IDs of the Revealing Shader properties into
        // shader IDs for best performance
        _lightPositionID = Shader.PropertyToID("_SpotLightPos");
        _spotLightDirID = Shader.PropertyToID("_SpotLightDir");
        _lightedID = Shader.PropertyToID("_Lighted");

        Shader.SetGlobalFloat("_LightStrengthIntensity", _uvLight.intensity);
        Shader.SetGlobalFloat("_LightRange", _uvLight.range);
        Shader.SetGlobalFloat("_InnerSpotAngle", Mathf.Cos(0.5f * Mathf.Deg2Rad * _uvLight.innerSpotAngle));
        Shader.SetGlobalFloat("_OuterSpotAngle", Mathf.Cos(0.5f * Mathf.Deg2Rad * _uvLight.spotAngle));
        Shader.SetGlobalColor("_SpotLightColor", _uvLight.color);

        // Here to test the old shader graph
        Shader.SetGlobalFloat("_InnerSpotAngleOld", _uvLight.innerSpotAngle);
        Shader.SetGlobalFloat("_OuterSpotAngleOld", _uvLight.spotAngle);

        _uvSpotLightObject.SetActive(true);
        Shader.SetGlobalFloat(_lightedID, 1);
        isOn = true;
    }

    private void OnEnable()
    {
        if (isOn)
        {
            Shader.SetGlobalFloat(_lightedID, 1);
        }
    }

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Mouse0))
            ToggleUVLight();

        if (isOn)
        {
            Shader.SetGlobalVector(_lightPositionID, _uvLight.transform.position);
            Shader.SetGlobalVector(_spotLightDirID, -_uvLight.transform.forward);
        }
    }

    public void ToggleUVLight()
    {
        isOn = isOn ? TurnOff() : TurnOn();
    }

    private bool TurnOn()
    {
        _uvSpotLightObject.SetActive(true);
        Shader.SetGlobalFloat(_lightedID, 1);
        return true;
    }

    private bool TurnOff()
    {
        _uvSpotLightObject.SetActive(false);
        Shader.SetGlobalFloat(_lightedID, 0);
        return false;
    }

    private void OnDisable()
    {
        Shader.SetGlobalFloat(_lightedID, 0);
    }
}
