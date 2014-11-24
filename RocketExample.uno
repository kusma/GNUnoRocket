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
		Rocket.ClientDevice device;
		const double bpm = 105.0;
		const int rpb = 8;
		const double row_rate = (bpm / 60.0) * rpb;

		Rocket.Track testTrackX, testTrackY, testTrackZ;

		Player player;
		Sound sound;
		Channel channel;

		public App()
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
			channel = player.PlaySound(sound, false);
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

		public override void Draw()
		{
			ClearColor = float4(0, 0, 0, 1);

			float row = (float)(channel.Position * row_rate);

			if (device != null)
				device.Update((int)Math.Floor(row));

			draw DefaultShading, Cube
			{
				Size: 50.0f;
				CameraPosition: float3(testTrackX.GetValue(row), testTrackY.GetValue(row), testTrackZ.GetValue(row));
				PixelColor: float4(1, 0, 1, 1);
				LightDirection: float3(-100, 100, 100);
			};
		}
    }
}