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
			Name = name;
		}

		private class KeyFrame
		{
			public int row;
			public float val;
			public int interpolation;
		}

		public float GetValue(float time)
		{
			if (_keyFrames.Count == 0)
				return 0.0f;

			int row = (int)Math.Floor(time);
			int idx = FindKey(row);

			if (idx < 0)
				idx = -idx - 2;

			if (idx < 0)
				return _keyFrames[0].val;
			if (idx >= _keyFrames.Count - 1)
				return _keyFrames[_keyFrames.Count - 1].val;

			float t = (time - _keyFrames[idx].row) / (float)(_keyFrames[idx + 1].row - _keyFrames[idx].row);

			switch (_keyFrames[idx].interpolation) {
			case 0: t = 0; break;
			case 1: break;
			case 2: t = t * t * (3 - 2 * t); break;
			case 3: t *= t; break;
			}

			return _keyFrames[idx].val + (_keyFrames[idx + 1].val - _keyFrames[idx].val) * t;
		}

		int FindKey(int row)
		{
			int lo = 0, hi = _keyFrames.Count;

			while (lo < hi) {
				int mi = (lo + hi) / 2;
				assert(mi != hi);

				if (_keyFrames[mi].row < row)
					lo = mi + 1;
				else if (_keyFrames[mi].row > row)
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
				_keyFrames.Insert(-idx - 1, key);
			else
				_keyFrames[idx] = key;
		}

		public void DelKey(int row)
		{
			int idx = FindKey(row);
			assert(idx >= 0);
			_keyFrames.RemoveAt(idx);
		}

		public readonly string Name;
		List<KeyFrame> _keyFrames = new List<KeyFrame>();
	}

	public class Device
	{
		public virtual Track GetTrack(string name)
		{
			foreach (Track t in tracks) {
				if (t.Name.Equals(name)) {
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
		Socket ServerConnect(string host, int port)
		{
			var ipAddresses = Dns.GetHostAddresses(host);
			if (ipAddresses.Length < 1)
				throw new Exception("could not resolve host");

			var exceptions = new List<Exception>();
			foreach (var ipAddress in ipAddresses)
			{
				var socket = new Socket(ipAddress.AddressFamily, SocketType.Stream, ProtocolType.Tcp);
				try
				{
					socket.Connect(new IPEndPoint(ipAddress, port));

					var networkStream = new NetworkStream(socket);
					_binaryReader = new BinaryReader(networkStream);
					_binaryWriter = new BinaryWriter(networkStream);

					try
					{
						_binaryWriter.Write(Uno.Text.Utf8.GetBytes("hello, synctracker!"));

						var serverGreet = "hello, demo!";
						var bytesReceived = _binaryReader.ReadBytes(Uno.Text.Utf8.GetBytes(serverGreet).Length);
						if (!Uno.Text.Utf8.GetString(bytesReceived).Equals(serverGreet))
							throw new Exception("handshake-error!");

						return socket;
					}
					catch (Exception e)
					{
						_binaryReader.Dispose();
						_binaryWriter.Dispose();
						throw;
					}

				}
				catch (Exception e)
				{
					socket.Close();
					Uno.Diagnostics.Debug.Log(string.Format("failed to connect to host {0}: {1}", ipAddress, e.Message));
					exceptions.Add(e);
					continue;
				}

				break;
			}

			throw new AggregateException("Failed to connect!", exceptions.ToArray());
		}

		public void Connect(string host, int port)
		{
			_socket = ServerConnect(host, port);

			foreach (Track track in tracks)
				GetTrack(track.Name);
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
