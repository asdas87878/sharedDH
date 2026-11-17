# Frames from clip.sh to a GIF: gif.py <frames_dir> <out.gif> [width] [first] [last] [crop: x0,y0,x1,y1 as shares] [ms]
import glob, sys
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
width = int(sys.argv[3]) if len(sys.argv) > 3 else 720
fs = sorted(glob.glob(src + '/f*.png'))
first = int(sys.argv[4]) if len(sys.argv) > 4 else 0
last = int(sys.argv[5]) if len(sys.argv) > 5 else len(fs)
crop = [float(x) for x in sys.argv[6].split(',')] if len(sys.argv) > 6 else None
frames = []
for f in fs[first:last]:
    im = Image.open(f).convert('RGB')
    if crop:
        w, h = im.size
        im = im.crop((int(crop[0] * w), int(crop[1] * h), int(crop[2] * w), int(crop[3] * h)))
    im = im.resize((width, int(im.size[1] * width / im.size[0])))
    frames.append(im.quantize(colors=128, method=Image.Quantize.MEDIANCUT))
duration = int(sys.argv[7]) if len(sys.argv) > 7 else 110  # ms a frame: the time between captures
frames[0].save(out, save_all=True, append_images=frames[1:], duration=duration, loop=0, optimize=True)
print(len(frames), 'frames ->', out)
