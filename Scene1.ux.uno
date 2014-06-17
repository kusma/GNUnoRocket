
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
		device.Connect("localhost", 1338);
		testTrack = device.GetTrack("testTrack");

		testTrackX = device.GetTrack("testTrackX");
		testTrackY = device.GetTrack("testTrackY");
		testTrackZ = device.GetTrack("testTrackZ");

        InitializeUX();
    }

	protected override void OnUpdate()
	{
		base.OnUpdate();

		float time = row;

		if (device != null)
			device.Update((int)Math.Floor(row));

		Uno.Diagnostics.Debug.Log("value: " + testTrack.GetValue(time));
		Transform3.Position = float3(testTrackX.GetValue(time),
		                             testTrackY.GetValue(time),
		                             testTrackZ.GetValue(time));
	}

	public void OnSetRow(object sender, int row)
	{
		this.row = row;
	}

	public void OnTogglePause(object sender, bool pause)
	{
		Uno.Diagnostics.Debug.Log("set-pause: " + pause);
	}

	Rocket.ClientDevice device = null;
	int row = 0;
	Rocket.Track testTrack = null;
	Rocket.Track testTrackX = null;
	Rocket.Track testTrackY = null;
	Rocket.Track testTrackZ = null;
}
