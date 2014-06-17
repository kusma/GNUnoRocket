using Uno;
using Uno.Collections;
using Uno.Graphics;
using Uno.Scenes;
using Uno.Content;
using Uno.Content.Models;

namespace Rocket
{
	public class Track
	{
		private class KeyFrame
		{
			public int row;
			public float val;
		}

		float GetValue(float time)
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

		List<KeyFrame> keyFrames;
	}

	public class Device
	{
	}
}
