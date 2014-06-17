
using Uno;
using Uno.Collections;
using Uno.Scenes;
using Uno.UI;
using Uno.Diagnostics;

using Rocket;

public partial class Scene1
{
    public Scene1()
    {
		device = new Rocket.ClientDevice();
		device.SetRowEvent += OnSetRow;
		device.TogglePauseEvent += OnTogglePause;

		Uno.Diagnostics.Debug.Log("calling Connect:");
		bool result = device.Connect("localhost", 1338);
		Uno.Diagnostics.Debug.Log("result: " + result);

		Uno.Diagnostics.Debug.Log("calling GetTrack:");
		var testTrack = device.GetTrack("testTrack");
		Uno.Diagnostics.Debug.Log("result: " + testTrack);

		/*var t = new Track();
		t.GetValue(0); */
        InitializeUX();
    }

	protected override void OnUpdate()
	{
		base.OnUpdate();
		if (device != null)
			device.Update();
	}

	public void OnSetRow(object sender, int row)
	{
		Uno.Diagnostics.Debug.Log("row: " + row);
	}

	public void OnTogglePause(object sender, bool pause)
	{
		Uno.Diagnostics.Debug.Log("set-pause: " + pause);
	}

	Rocket.ClientDevice device = null;
}
