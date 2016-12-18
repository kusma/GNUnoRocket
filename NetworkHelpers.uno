public static class NetworkHelpers
{
	public static int HostToNetworkOrder(int host)
	{
		return (((int)HostToNetworkOrder((short)host) & 0xffff) << 16) |
		        ((int)HostToNetworkOrder((short)(host >> 16)) & 0xffff);
	}

	public static short HostToNetworkOrder(short host)
	{
		return (short)(((host & 0xff) << 8) | ((host >> 8) & 0xff));
	}

	public static int NetworkToHostOrder(int host)
	{
		return (((int)HostToNetworkOrder((short)host) & 0xffff) << 16) |
		        ((int)HostToNetworkOrder((short)(host >> 16)) & 0xffff);
	}

	public static short NetworkToHostOrder(short host)
	{
		return (short)(((host & 0xff) << 8) | ((host >> 8) & 0xff));
	}
}
