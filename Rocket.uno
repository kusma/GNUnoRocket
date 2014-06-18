using Uno;
using Uno.Collections;
using Uno.Graphics;
using Uno.Scenes;
using Uno.Content;
using Uno.Content.Models;
using Uno.Compiler.ExportTargetInterop;

namespace Rocket
{
	public class Track
	{
		public Track(string name)
		{
			this.name = name;
		}

		private class KeyFrame
		{
			public int row;
			public float val;
			public int interpolation;
		}

		public float GetValue(float time)
		{
			if (keyFrames.Count == 0)
				return 0.0f;

			int row = (int)Math.Floor(time);
			int idx = FindKey(row);

			if (idx < 0)
				idx = -idx - 2;

			if (idx < 0)
				return keyFrames[0].val;
			if (idx >= keyFrames.Count - 1)
				return keyFrames[keyFrames.Count - 1].val;

			float t = (row - keyFrames[idx].row) / (float)(keyFrames[idx + 1].row - keyFrames[idx].row);

			switch (keyFrames[idx].interpolation) {
			case 0: t = 0; break;
			case 1: break;
			case 2: t = t * t * (3 - 2 * t); break;
			case 3: t *= t; break;
			}

			return keyFrames[idx].val + (keyFrames[idx + 1].val - keyFrames[idx].val) * t;
		}

		int FindKey(int row)
		{
			int lo = 0, hi = keyFrames.Count;

			while (lo < hi) {
				int mi = (lo + hi) / 2;
				assert(mi != hi);

				if (keyFrames[mi].row < row)
					lo = mi + 1;
				else if (keyFrames[mi].row > row)
					hi = mi;
				else
					return mi; /* exact hit */
			}

			assert(lo == hi);

			/* return first key after row, negated and biased (to allow -0) */
			return -lo - 1;
		}

		public void SetKey(int row, float val, int interpolation)
		{
			var key = new KeyFrame();
			key.row = row;
			key.val = val;
			key.interpolation = interpolation;
			int idx = FindKey(row);
			if (idx < 0)
				keyFrames.Insert(-idx - 1, key);
			else
				keyFrames[idx] = key;
		}

		public void DelKey(int row)
		{
			int idx = FindKey(row);
			assert(idx >= 0);
			keyFrames.RemoveAt(idx);
		}

		public string name;
		List<KeyFrame> keyFrames = new List<KeyFrame>();
	}

	[ExportCondition("CIL")]
	public class Socket
	{
		public extern bool Connect(string host, int port);
		public extern void Disconnect();
		public extern bool IsConnected();
		public extern bool PollData();
		public extern bool Send(byte[] data, int size);
		public extern bool Receive(byte[] data, int size);
	}

	class Encoding {
		public class ASCII {
			public static byte[] GetBytes(string str)
			{
				var ret = new byte[str.Length];
				for (int i = 0; i < str.Length; ++i)
					ret[i] = (byte)(str[i] < 128 ? str[i] : '?');
				return ret;
			}

			public static string GetString(byte[] bytes)
			{
				var ret = "";
				for (int i = 0; i < bytes.Length; ++i)
					ret += bytes[i] < 128 ? (char)bytes[i] : '?';
				return ret;
			}
		}

		public class UTF8 {
			public static byte[] GetBytes(string str)
			{
				var ret = new List<byte>();
				for (int i = 0; i < str.Length; ++i) {
					int ch = str[i];

					// HACK: ignore surrogate pairs

					int trailingBytes = 0;
					byte byteMark = 0x00;
					if (ch >= 0x80) {
						trailingBytes = 1;
						byteMark = 0xC0;
					} else if (ch >= 0x800) {
						trailingBytes = 2;
						byteMark = 0xE0;
					} else if (ch >= 0x10000) {
						trailingBytes = 3;
						byteMark = 0xF0;
					}

					ret.Add((byte)(byteMark | (ch >> (6 * trailingBytes)) & 0x7f));
					Uno.Diagnostics.Debug.Log(ret[ret.Count - 1]);

					for (int j = 0; j < trailingBytes; ++j) {
						ret.Add((byte)(0x80 | (ch >> (6 * (trailingBytes - 1 - j))) & 0xbf));
						Uno.Diagnostics.Debug.Log(ret[ret.Count - 1]);
					}
				}
				return ret.ToArray();
			}
		}
	}

	[ExportCondition("CIL")]
	public class ClientDevice
	{
		public bool Connect(string host, int port)
		{
			assert(socket == null);

			socket = new Socket();
			if (socket.Connect(host, port)) {
                byte[] clientGreet = Encoding.ASCII.GetBytes("hello, synctracker!");
                string serverGreet = "hello, demo!";
                byte[] bytesReceived = new Byte[serverGreet.Length];

                if (!socket.Send(clientGreet, clientGreet.Length) ||
                    !socket.Receive(bytesReceived, bytesReceived.Length) ||
                    !Encoding.ASCII.GetString(bytesReceived).Equals(serverGreet))
                {
                    return false;
                }

				foreach (Track track in tracks)
					GetTrack(track.name);
				return true;
			}
			return false;
		}

		public Track GetTrack(string name)
		{
			foreach (Track t in tracks) {
				if (t.name.Equals(name)) {
					return t;
				}
			}

			var track = new Track(name);
			tracks.Add(track);

			var nameUTF8 = Encoding.UTF8.GetBytes(name);
			var output = new byte[5 + nameUTF8.Length];

			// "get track"
			output[0] = 2;

			output[1] = (byte)((nameUTF8.Length >> 24) & 0xff);
			output[2] = (byte)((nameUTF8.Length >> 16) & 0xff);
			output[3] = (byte)((nameUTF8.Length >> 8) & 0xff);
			output[4] = (byte)(nameUTF8.Length & 0xff);

			for (int i = 0; i < nameUTF8.Length; ++i) {
				assert(i < output.Length);
				output[5 + i] = (byte)nameUTF8[i];
			}

			// disconnect on error
			if (!socket.Send(output, output.Length))
				socket.Disconnect();

			return track;
		}

		private bool HandleSetKeyCmd()
		{
			byte[] payload = new byte[4];

			if (!socket.Receive(payload, payload.Length))
				return false;
			int track = payload[3] | (payload[2] << 8) | (payload[1] << 16) | (payload[0] << 24);

			if (!socket.Receive(payload, payload.Length))
				return false;
			int row = payload[3] | (payload[2] << 8) | (payload[1] << 16) | (payload[0] << 24);

			if (!socket.Receive(payload, payload.Length))
				return false;
			// YUCK! stitch together FP32!
			int significand = ((payload[3] | (payload[2] << 8) | (payload[1] << 16)) & ((1 << 23) - 1));
			int exponent = (((payload[0] & 0x7f) << 1) | (payload[1] >> 7)) - 127;
			if (exponent != -127)
				significand |= 1 << 23;
			float val = (significand / (float)(1 << 23)) * Math.Exp2(exponent);
			if ((payload[0] & 0x80) != 0)
				val = - val;

			if (!socket.Receive(payload, 1))
				return false;
			int interpolation = payload[0];

			tracks[track].SetKey(row, val, interpolation);
			return true;
		}

		private bool HandleDelKeyCmd()
		{
			byte[] payload = new byte[4];

			if (!socket.Receive(payload, payload.Length))
				return false;
			int track = payload[3] | (payload[2] << 8) | (payload[1] << 16) | (payload[0] << 24);

			if (!socket.Receive(payload, payload.Length))
				return false;
			int row = payload[3] | (payload[2] << 8) | (payload[1] << 16) | (payload[0] << 24);

			tracks[track].DelKey(row);
			return true;
		}

		private bool HandleSetRowCmd()
		{
			byte[] payload = new byte[4];
			if (!socket.Receive(payload, payload.Length))
				return false;

			int row = payload[3] | (payload[2] << 8) | (payload[1] << 16) | (payload[0] << 24);
			if (SetRowEvent != null)
				SetRowEvent(this, row);
			return true;
		}

		private bool HandlePauseCmd()
		{
			byte[] payload = new byte[1];
			if (!socket.Receive(payload, 1))
				return false;
			bool pause = payload[0] != 0;
			if (TogglePauseEvent != null)
				TogglePauseEvent(this, pause);
			return true;
		}

		private bool HandleSaveTracksCmd()
		{
			// TODO: implement
			return true;
		}

		public bool Update(int row)
		{
			if (!socket.IsConnected())
				return false;

			while (socket.PollData()) {
				byte[] cmd = new byte[1];
				if (!socket.Receive(cmd, 1)) {
					socket.Disconnect();
					break;
				}

				switch (cmd[0]) {
				case 0:
					if (!HandleSetKeyCmd())
						socket.Disconnect();
					break;

				case 1:
					if (!HandleDelKeyCmd())
						socket.Disconnect();
					break;

				case 3:
					if (!HandleSetRowCmd())
						socket.Disconnect();
					break;

				case 4:
					if (!HandlePauseCmd())
						socket.Disconnect();
					break;

				case 5:
					if (!HandleSaveTracksCmd())
						socket.Disconnect();
					break;
				}
			}

			if (socket.IsConnected() && IsPlayingEvent != null && IsPlayingEvent(this)) {
				byte[] output = new byte[5];

				output[0] = 3; // set row

				output[1] = (byte)((row >> 24) & 0xff);
				output[2] = (byte)((row >> 16) & 0xff);
				output[3] = (byte)((row >> 8) & 0xff);
				output[4] = (byte)(row & 0xff);

				// disconnect on error
				if (!socket.Send(output, output.Length))
					socket.Disconnect();
			}

			return socket.IsConnected();
		}

		Socket socket = null;
		List<Track> tracks = new List<Track>();

		public delegate void SetRowEventHandler(object sender, int row);
		public event SetRowEventHandler SetRowEvent;

		public delegate void TogglePauseEventHandler(object sender, bool pause);
		public event TogglePauseEventHandler TogglePauseEvent;

		public delegate bool IsPlayingEventHandler(object sender);
		public event IsPlayingEventHandler IsPlayingEvent;

	}
}
