
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

        InitializeUX();
    }

	protected override void OnUpdate()
	{
		base.OnUpdate();
		if (device != null)
			device.Update(row);
		Uno.Diagnostics.Debug.Log("value: " + testTrack.GetValue((float)row));
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
}
