using Uno.Compiler.ExportTargetInterop;

namespace Rocket
{
	[ExportCondition("CIL")]
	[DotNetType("Rocket.Socket")]
	public class Socket
	{
		public extern Socket() {}
		public extern void Connect(string host, int port) {}
		public extern void Disconnect() {}
		public extern bool IsConnected() { return false; }
		public extern bool PollData() { return false; }
		public extern bool Send(byte[] data, int size) { return false; }
		public extern bool Receive(byte[] data, int size) { return false; }
	}
}
