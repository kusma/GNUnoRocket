using Uno;
using Uno.Collections;
using Uno.IO;
using Uno.Net;
using Uno.Net.Sockets;

namespace Rocket
{
	static class Helpers
	{
		public static float GetFloatValue(int binValue)
		{
			// YUCK! stitch together FP32!
			int significand = binValue & ((1 << 23) - 1);

			int exponent = ((binValue >> 23) & 0xFF) - 127;
			if (exponent != -127)
				significand |= 1 << 23;

			float ret = (significand / (float)(1 << 23)) * Math.Exp2(exponent);
			if (binValue < 0)
				ret = -ret;

			return ret;
		}
	}

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

			float t = (time - keyFrames[idx].row) / (float)(keyFrames[idx + 1].row - keyFrames[idx].row);

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

	public class Device
	{
		public virtual Track GetTrack(string name)
		{
			foreach (Track t in tracks) {
				if (t.name.Equals(name)) {
					return t;
				}
			}

			var track = new Track(name);
			tracks.Add(track);

			return track;
		}

		public List<Track> tracks = new List<Track>();
	}

	public extern(!SYNC_PLAYER) class ClientDevice : Device
	{
		public void Connect(string host, int port)
		{
			var ipAddresses = Dns.GetHostAddresses(host);
			if (ipAddresses.Length < 1)
				throw new Exception("could not resolve host");

			_socket = new Socket(ipAddresses[0].AddressFamily, SocketType.Stream, ProtocolType.Tcp);
			_socket.Connect(new IPEndPoint(ipAddresses[0], 1338));
			var networkStream = new NetworkStream(_socket);
			_binaryReader = new BinaryReader(networkStream);
			_binaryWriter = new BinaryWriter(networkStream);

			try
			{
				_binaryWriter.Write(Uno.Text.Utf8.GetBytes("hello, synctracker!"));

				var serverGreet = "hello, demo!";
				var bytesReceived = _binaryReader.ReadBytes(Uno.Text.Utf8.GetBytes(serverGreet).Length);
				if (!Uno.Text.Utf8.GetString(bytesReceived).Equals(serverGreet))
					throw new Exception("handshake-error!");

				foreach (Track track in tracks)
					GetTrack(track.name);
			}
			catch (Exception e)
			{
				_socket.Close();
				throw e;
			}
		}

		public override Track GetTrack(string name)
		{
			if (!_socket.Connected)
				throw new Exception("not connected!");

			// "get track"
			_binaryWriter.Write((byte)2);

			var nameUTF8 = Uno.Text.Utf8.GetBytes(name);
			_binaryWriter.Write(NetworkHelpers.HostToNetworkOrder(nameUTF8.Length));
			_binaryWriter.Write(nameUTF8);

			return base.GetTrack(name);
		}

		private void HandleSetKeyCmd()
		{
			int track = NetworkHelpers.NetworkToHostOrder(_binaryReader.ReadInt());
			int row = NetworkHelpers.NetworkToHostOrder(_binaryReader.ReadInt());
			float val = Helpers.GetFloatValue(NetworkHelpers.NetworkToHostOrder(_binaryReader.ReadInt()));
			int interpolation = _binaryReader.ReadByte();

			tracks[track].SetKey(row, val, interpolation);
		}

		private void HandleDelKeyCmd()
		{
			int track = NetworkHelpers.NetworkToHostOrder(_binaryReader.ReadInt());
			int row = NetworkHelpers.NetworkToHostOrder(_binaryReader.ReadInt());

			tracks[track].DelKey(row);
		}

		private void HandleSetRowCmd()
		{
			int row = NetworkHelpers.NetworkToHostOrder(_binaryReader.ReadInt());

			if (SetRowEvent != null)
				SetRowEvent(this, row);
		}

		private void HandlePauseCmd()
		{
			bool pause = _binaryReader.ReadByte() != 0;
			if (TogglePauseEvent != null)
				TogglePauseEvent(this, pause);
		}

		private void HandleSaveTracksCmd()
		{
			// TODO: implement
		}

		public bool Update(int row)
		{
			if (!_socket.Connected)
				return false;

			while (_socket.Poll(0, SelectMode.Read))
			{
				switch (_binaryReader.ReadByte())
				{
					case 0:
						HandleSetKeyCmd();
						break;

					case 1:
						HandleDelKeyCmd();
						break;

					case 3:
						HandleSetRowCmd();
						break;

					case 4:
						HandlePauseCmd();
						break;

					case 5:
						HandleSaveTracksCmd();
						break;
				}
			}

			if (_socket.Connected && IsPlayingEvent != null && IsPlayingEvent(this))
			{
				_binaryWriter.Write((byte)3);
				_binaryWriter.Write(NetworkHelpers.HostToNetworkOrder(row));
			}

			return _socket.Connected;
		}

		Socket _socket;
		BinaryReader _binaryReader;
		BinaryWriter _binaryWriter;

		public delegate void SetRowEventHandler(object sender, int row);
		public event SetRowEventHandler SetRowEvent;

		public delegate void TogglePauseEventHandler(object sender, bool pause);
		public event TogglePauseEventHandler TogglePauseEvent;

		public delegate bool IsPlayingEventHandler(object sender);
		public event IsPlayingEventHandler IsPlayingEvent;

	}
}
