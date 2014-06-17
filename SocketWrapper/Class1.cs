using System;
using System.Text;
using System.IO;
using System.Net;
using System.Net.Sockets;

namespace Rocket
{
    public class Socket
    {
        public bool Connect(string host, int port)
        {
            IPHostEntry hostEntry = Dns.GetHostEntry(host);
            foreach (IPAddress address in hostEntry.AddressList) {
                IPEndPoint ipe = new IPEndPoint(address, port);
                System.Net.Sockets.Socket tempSocket = new System.Net.Sockets.Socket(ipe.AddressFamily, SocketType.Stream, ProtocolType.Tcp);
                tempSocket.Connect(ipe);
                if (tempSocket.Connected) {

                    Byte[] clientGreet = Encoding.ASCII.GetBytes("hello, synctracker!");
                    string serverGreet = "hello, demo!";
                    Byte[] bytesReceived = new Byte[serverGreet.Length];

                    if (tempSocket.Send(clientGreet, clientGreet.Length, SocketFlags.None) != clientGreet.Length ||
                        tempSocket.Receive(bytesReceived, bytesReceived.Length, SocketFlags.None) != bytesReceived.Length ||
                        !System.Text.Encoding.ASCII.GetString(bytesReceived).Equals(serverGreet))
                    {
                        return false;
                    }

                    socket = tempSocket;
                    return true;
                }
            }
            return false;
        }

        public bool PollData()
        {
            return socket.Poll(0, SelectMode.SelectRead);
        }

        public bool Send(byte[] data, int size)
        {
            return socket.Send(data, size, SocketFlags.None) == size;
        }

        public bool Receive(byte[] data, int size)
        {
            return socket.Receive(data, size, SocketFlags.None) == size;
        }

        private System.Net.Sockets.Socket socket = null;
    }
}
