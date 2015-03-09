using Uno;
using Uno.Collections;
using Uno.Graphics;
using Fuse.Entities;
using Fuse.Entities.Primitives;
using Fuse.Drawing.Primitives;
using Experimental.Audio;

namespace RocketExample
{
	class App : Uno.Application
	{
		Rocket.Device device;
		const double bpm = 105.0;
		const int rpb = 8;
		const double row_rate = (bpm / 60.0) * rpb;

		float Row {
			get {
				return (float)(channel.Position * row_rate);
			}
			set {
				channel.Position = value / row_rate;
			}
		}

		Rocket.Track testTrackX, testTrackY, testTrackZ;

		Player player;
		Sound sound;
		Channel channel;

		public App()
		{
			if (defined(CIL)) {
				var temp = new Rocket.ClientDevice();
				temp.SetRowEvent += OnSetRow;
				temp.TogglePauseEvent += OnTogglePause;
				temp.IsPlayingEvent += OnIsPlaying;

				try
				{
					temp.Connect("localhost", 1338);
				}
				catch (Exception e)
				{
					Uno.Diagnostics.Debug.Log("failed to connect to editor: " + e.Message);
					throw e;
				}

				device = temp;
			} else
				device = new Rocket.Device();

			testTrackX = device.GetTrack("testTrackX");
			testTrackY = device.GetTrack("testTrackY");
			testTrackZ = device.GetTrack("testTrackZ");

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
			channel = player.PlaySound(sound, false);
		}

		public void OnSetRow(object sender, int row)
		{
			Row = row;
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

		public override void Draw()
		{
			ClearColor = float4(0, 0, 0, 1);

			if (defined(CIL)) {
				var clientDevice = device as Rocket.ClientDevice;
				if (clientDevice != null)
					clientDevice.Update((int)Math.Floor(Row));
			}

			draw DefaultShading, Cube
			{
				Size: 50.0f;
				CameraPosition: float3(testTrackX.GetValue(Row), testTrackY.GetValue(Row), testTrackZ.GetValue(Row));
				PixelColor: float4(1, 0, 1, 1);
				LightDirection: float3(-100, 100, 100);
			};
		}
	}
}
