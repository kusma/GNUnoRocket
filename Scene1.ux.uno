
using Uno;
using Uno.Collections;
using Uno.Scenes;
using Uno.UI;
using Uno.Diagnostics;
using Experimental.Audio;

using Rocket;

public partial class Scene1
{
    public Scene1()
    {
		device = new Rocket.ClientDevice();
		device.SetRowEvent += OnSetRow;
		device.TogglePauseEvent += OnTogglePause;
		device.IsPlayingEvent += OnIsPlaying;

		try
		{
			device.Connect("localhost", 1338);
			testTrackX = device.GetTrack("testTrackX");
			testTrackY = device.GetTrack("testTrackY");
			testTrackZ = device.GetTrack("testTrackZ");
		}
		catch (Exception e)
		{
			Uno.Diagnostics.Debug.Log("failed to connect to editor: " + e.Message);
			throw e;
		}

		try
		{
			player = new Player();
			sound = player.CreateSound(import BundleFile("lug00ber-carl_breaks.mp3"));
		}
		catch (Exception e)
		{
			Uno.Diagnostics.Debug.Log("failed to load music stuff: " + e.Message);
			throw e;
		}


        InitializeUX();

		channel = player.PlaySound(sound, false);
    }

	protected override void OnUpdate()
	{
		base.OnUpdate();

		float row = (float)(channel.Position * row_rate);

		if (device != null)
			device.Update((int)Math.Floor(row));

		Transform3.Position = float3(testTrackX.GetValue(row),
		                             testTrackY.GetValue(row),
		                             testTrackZ.GetValue(row));
	}

	public void OnSetRow(object sender, int row)
	{
		channel.Position = row / row_rate;
	}

	public void OnTogglePause(object sender, bool pause)
	{
		if (pause)
			channel.Pause();
		else
			channel.Play();
	}

	bool OnIsPlaying(object sender)
	{
		return channel.IsPlaying;
	}

	Rocket.ClientDevice device;
	Rocket.Track testTrackX, testTrackY, testTrackZ;

	const double bpm = 105.0;
	const int rpb = 8;
	const double row_rate = (bpm / 60.0) * rpb;

	Player player;
	Sound sound;
	Channel channel;
}
