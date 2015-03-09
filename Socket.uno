using Uno.Compiler.ExportTargetInterop;

namespace Rocket
{
	[ExportCondition("CIL")]
	public class Socket
	{
		public extern Socket();
		public extern void Connect(string host, int port);
		public extern void Disconnect();
		public extern bool IsConnected();
		public extern bool PollData();
		public extern bool Send(byte[] data, int size);
		public extern bool Receive(byte[] data, int size);
	}
}
