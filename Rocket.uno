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
		}

		public float GetValue(float time)
		{
			int row = (int)Math.Floor(time);
			int idx = FindKey(row);
			if (idx < 0)
				idx = -idx - 2;

			if (idx < 0)
				return keyFrames[0].val;
			if (idx > keyFrames.Count - 2)
				return keyFrames[keyFrames.Count - 1].val;

			float t = (row - keyFrames[idx].row) / (keyFrames[idx + 1].row / keyFrames[idx].row);
			return keyFrames[idx].val + (keyFrames[idx + 1].row - keyFrames[idx].row) * t;
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

		public void SetKey(int row, float val)
		{
			var key = new KeyFrame();
			key.row = row;
			key.val = val;
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
		public extern bool PollData();
		public extern bool Send(byte[] data, int size);
		public extern bool Receive(byte[] data, int size);
	}

	[ExportCondition("CIL")]
	public class ClientDevice
	{
		public bool Connect(string host, int port)
		{
			assert(socket == null);

			socket = new Socket();
			if (socket.Connect(host, port)) {
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

			byte[] output = new byte[5 + name.Length];

			// "get track"
			output[0] = 2;

			output[1] = (byte)((name.Length >> 24) & 0xff);
			output[2] = (byte)((name.Length >> 16) & 0xff);
			output[3] = (byte)((name.Length >> 8) & 0xff);
			output[4] = (byte)(name.Length & 0xff);

			for (int i = 0; i < name.Length; ++i) {
				assert(i < output.Length);
				output[5 + i] = (byte)name[i]; // HACK: only ASCII supported!
			}

			// disconnect on error
			if (!socket.Send(output, output.Length))
				socket = null;

			return track;
		}

		public bool Update()
		{
			if (socket == null)
				return false;

			while (socket.PollData()) {
				byte[] cmd = new byte[1];
				socket.Receive(cmd, 1);

				switch (cmd[0]) {
				case 0: // set key

					byte[] payload = new byte[4];

					// HACK! no error checking!
					socket.Receive(payload, payload.Length);
					int track = payload[3] | (payload[2] << 8) | (payload[1] << 16) | (payload[0] << 24);

					// HACK! no error checking!
					socket.Receive(payload, payload.Length);
					int row = payload[3] | (payload[2] << 8) | (payload[1] << 16) | (payload[0] << 24);

					// HACK! no error checking!
					socket.Receive(payload, payload.Length);

					// YUCK! stitch together FP32!
					int significand = ((payload[3] | (payload[2] << 8) | (payload[1] << 16)) & ((1 << 23) - 1));
					int exponent = (((payload[0] & 0x7f) << 1) | (payload[1] >> 7)) - 127;
					if (exponent != -127)
						significand |= 1 << 23;
					float val = (significand / (float)(1 << 23)) * Math.Exp2(exponent);
					if ((payload[0] & 0x80) != 0)
						val = - val;

					// HACK! no error checking!
					socket.Receive(payload, 1);
					int iterpolation = payload[0];

					Uno.Diagnostics.Debug.Log("track: " + track);
					Uno.Diagnostics.Debug.Log("row: " + row);
					Uno.Diagnostics.Debug.Log("val: " + val);
					Uno.Diagnostics.Debug.Log("interpolation: " + iterpolation);

					tracks[track].SetKey(row, val);
					break;

				case 1: // del key
					byte[] payload = new byte[4];

					// HACK! no error checking!
					socket.Receive(payload, payload.Length);
					int track = payload[3] | (payload[2] << 8) | (payload[1] << 16) | (payload[0] << 24);

					// HACK! no error checking!
					socket.Receive(payload, payload.Length);
					int row = payload[3] | (payload[2] << 8) | (payload[1] << 16) | (payload[0] << 24);

					Uno.Diagnostics.Debug.Log("track: " + track);
					Uno.Diagnostics.Debug.Log("row: " + row);

					tracks[track].DelKey(row);
					break;

				case 3: // set row
					byte[] payload = new byte[4];
					socket.Receive(payload, payload.Length);
					int row = payload[3] | (payload[2] << 8) | (payload[1] << 16) | (payload[0] << 24);
					if (SetRowEvent != null)
						SetRowEvent(this, row);
					// TODO: callback!
					break;

				case 4: // pause
					byte[] payload = new byte[1];
					socket.Receive(payload, 1);
					bool pause = payload[0] != 0;
					if (TogglePauseEvent != null)
						TogglePauseEvent(this, pause);
					break;

				case 5: // save tracks
					// HACK: not implemented!
					break;
				}
			}

			return true;
		}

		Socket socket = null;
		List<Track> tracks = new List<Track>();

		public delegate void SetRowEventHandler(object sender, int row);
		public event SetRowEventHandler SetRowEvent;

		public delegate void TogglePauseEventHandler(object sender, bool pause);
		public event TogglePauseEventHandler TogglePauseEvent;

	}
}