using System.Collections;
using UnityEngine;
using UnityEngine.Experimental.GlobalIllumination;

public class UVLightOld : MonoBehaviour
{
    [SerializeField] private GameObject _uvSpotLightObject;
    [SerializeField] private GameObject _uvSpotLightReboundObject;
    private Light _uvLight;
    private int _lightPositionID;
    private int _spotLightDirID;
    private int _lightedID;
    private bool isOn;
    private void Start()
    {
        // If the spotlightobject and uv light arent referenced or cant be found,
        // the script won't work
        // So we just disable it.
        if (_uvSpotLightObject == null)
        {
            enabled = false;
            return;
        }

        _uvLight = _uvSpotLightObject.GetComponent<Light>();

        if (_uvLight == null)
        {
            enabled = false;
            return;
        }
        
        // Convert the strings IDs of the Revealing Shader properties into
        // shader IDs for best performance
        _lightPositionID = Shader.PropertyToID("_SpotLightPos");
        _spotLightDirID = Shader.PropertyToID("_SpotLightDir");
        _lightedID = Shader.PropertyToID("_Lighted");

        Shader.SetGlobalFloat("_LightStrengthIntensity", _uvLight.intensity);
        Shader.SetGlobalFloat("_LightRange", _uvLight.range);
        Shader.SetGlobalFloat("_InnerSpotAngle", Mathf.Cos(0.5f * Mathf.Deg2Rad * _uvLight.innerSpotAngle));
        Shader.SetGlobalFloat("_OuterSpotAngle", Mathf.Cos(0.5f * Mathf.Deg2Rad * _uvLight.spotAngle));

        // Update the old shader graph values still, so that we can still have a comparison
        Shader.SetGlobalFloat("_InnerSpotAngleOld", _uvLight.innerSpotAngle);
        Shader.SetGlobalFloat("_OuterSpotAngleOld", _uvLight.spotAngle);

        _uvSpotLightObject.SetActive(false);
        if (_uvSpotLightReboundObject != null)
            _uvSpotLightReboundObject.SetActive(false);
        Shader.SetGlobalFloat(_lightedID, 0);
        isOn = false;
    }
    private void OnEnable()
    {
        if (isOn)
        {
            _uvSpotLightObject.SetActive(false);
            if (_uvSpotLightReboundObject != null)
                _uvSpotLightReboundObject.SetActive(false);
            Shader.SetGlobalFloat(_lightedID, 0);
            isOn = false;
        }
    }

    /// <summary>
    /// if bool isOn, which is turned on and off a the same time as necessary components
    /// is true, then update the necessary variables for the uvlight to work.
    /// </summary>
    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Mouse0))
            ToggleUVLight();
        if (isOn)
        {
            Shader.SetGlobalVector(_lightPositionID, _uvLight.transform.position);
            Shader.SetGlobalVector(_spotLightDirID, -_uvLight.transform.forward);
        }

        Debug.Log("spotanglein: " + Shader.GetGlobalFloat("_InnerSpotAngle") + "      spotangleout: " + Shader.GetGlobalFloat("_OuterSpotAngle"));
        Debug.Log("old spotanglein: " + Shader.GetGlobalFloat("_InnerSpotAngleOld") + "      old spotangleout: " + Shader.GetGlobalFloat("_OuterSpotAngleOld"));
    }

    /// <summary>
    /// Turns the Light on if its off and off if its on
    /// </summary>
    public void ToggleUVLight()
    {
        isOn = isOn ? TurnOff() : TurnOn();
    }

    /// <summary>
    /// Turns on all the necessary components to make uvlight work
    /// </summary>
    /// <returns> Returns that the light functions were turned on. </returns>
    private bool TurnOn()
    {

        _uvSpotLightObject.SetActive(true);
        if (_uvSpotLightReboundObject != null)
            _uvSpotLightReboundObject.SetActive(true);
        Shader.SetGlobalFloat(_lightedID, 1);

        return true;
    }

    /// <summary>
    /// Turns off all the necessary components to make uvlight work
    /// </summary>
    /// <returns> Returns that the light functions were turned off. </returns>
    private bool TurnOff()
    {
        _uvSpotLightObject.SetActive(false);
        if (_uvSpotLightReboundObject != null)
            _uvSpotLightReboundObject.SetActive(false);
        Shader.SetGlobalFloat(_lightedID, 0);

        return false;
    }

    private void OnDisable()
    {
        Shader.SetGlobalFloat(_lightedID, 0);
    }
}
