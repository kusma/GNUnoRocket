using Uno.Collections;

namespace Text
{
	public abstract class Encoding : Uno.Object
	{
		abstract public byte[] GetBytes(string str);
		abstract public string GetString(byte[] bytes);

		public static Encoding ASCII {
			get { return new ASCIIEncoding(); }
		}
		public static Encoding UTF8 {
			get { return new UTF8Encoding(); }
		}
	}

	public class ASCIIEncoding : Encoding
	{
		public ASCIIEncoding() { }

		override public byte[] GetBytes(string str)
		{
			var ret = new byte[str.Length];
			for (int i = 0; i < str.Length; ++i)
				ret[i] = (byte)(str[i] < 128 ? str[i] : '?');
			return ret;
		}

		override public string GetString(byte[] bytes)
		{
			var ret = "";
			for (int i = 0; i < bytes.Length; ++i)
				ret += bytes[i] < 128 ? (char)bytes[i] : '?';
			return ret;
		}
	}

	public class UTF8Encoding : Encoding
	{
		public UTF8Encoding() { }

		public override byte[] GetBytes(string str)
		{
			var ret = new List<byte>();
			for (int i = 0; i < str.Length; ++i) {
				int ch = str[i];

				if (ch >= 0xd800 && ch <= 0xdbff) {
					int ch1 = ch;
					ch = 0xfffd;
					if (i + 1 != str.Length) {
						int ch2 = str[++i];
						if (ch2 >= 0xdc00 && ch2 < 0xdfff) {
							ch2 &= 0x3ff;
							ch2 |= (ch1 & 0x3ff) << 10;
							if (ch2 <= 0x10ffff)
								ch = ch2;
						}
					}
				}

				int trailingBytes = 0;
				byte byteMark = 0x00;
				if (ch >= 0x10000) {
					trailingBytes = 3;
					byteMark = 0xF0;
				} else if (ch >= 0x800) {
					trailingBytes = 2;
					byteMark = 0xE0;
				} else if (ch >= 0x80) {
					trailingBytes = 1;
					byteMark = 0xC0;
				}

				ret.Add((byte)(byteMark | (ch >> (6 * trailingBytes)) & 0x7f));

				for (int j = 0; j < trailingBytes; ++j)
					ret.Add((byte)(0x80 | (ch >> (6 * (trailingBytes - 1 - j))) & 0xbf));
			}
			return ret.ToArray();
		}

		override public string GetString(byte[] bytes)
		{
			throw new Uno.Exception("not implemented");
		}
	}
}