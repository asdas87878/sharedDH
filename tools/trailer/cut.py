"""Cuts a recording of the trailer mode (docs/design/trailer.md) into the game-page video.

python tools/trailer/cut.py <recording.mkv> [out.mp4] [--music song.mp3]

The recording has a pink slate between shots, with the shot's number in six black and white squares (1 white, from the
left the highest). Each shot is taken from CUT (in, seconds of the recording, speed); a shot filmed twice uses its last
take. Cuts marked whip are hidden by a sideways blur. PLAY NOW drops in over the last shot.
"""
import subprocess, sys
import cv2, numpy as np
import imageio_ffmpeg

W, H, FPS = 1920, 1080, 60
# shot: (in, length, speed, whip into the next)
CUT = {
    1: (0.0, 1.4, 1.0, True), 2: (0.1, 0.8, 1.0, True), 3: (0.1, 0.7, 1.0, False), 4: (0.1, 0.9, 1.0, False),
    5: (0.1, 1.0, 1.0, False), 6: (0.0, 1.3, 1.0, True), 7: (0.3, 2.0, 1.1, False), 8: (0.2, 1.9, 1.1, True),
    9: (0.1, 2.2, 1.3, False), 10: (0.1, 1.3, 1.0, False), 11: (0.1, 5.0, 1.35, True), 12: (0.1, 1.3, 1.1, True),
    13: (0.1, 0.9, 1.0, True), 14: (0.1, 0.9, 1.0, True), 15: (0.1, 1.0, 1.0, True), 16: (0.3, 4.2, 2.3, True),
    17: (0.1, 1.4, 1.1, True), 18: (0.1, 1.4, 1.0, False), 19: (0.1, 1.2, 1.0, True), 20: (0.2, 3.8, 1.1, False),
}
WHIP = 5  # frames of blur each side of a cut
TEXT, TEXT_AT, LETTER = "PLAY NOW", 1.1, 0.09  # seconds into the last shot, and between letters


def slate(frame):
    """The shot number on a slate frame, or None."""
    small = cv2.resize(frame, (64, 36), interpolation=cv2.INTER_AREA).astype(int)
    edge = np.concatenate([small[2:6, 4:60].reshape(-1, 3), small[30:34, 4:60].reshape(-1, 3)])
    b, g, r = edge.mean(0)
    if not (b > 200 and r > 200 and g < 70 and edge.std(0).max() < 30):
        return None
    n = 0
    for i in range(6):
        x = int(frame.shape[1] * (0.5 + (i + 1 - 3.5) * 0.08))
        y = frame.shape[0] // 2
        n = n * 2 + int(frame[y - 6:y + 6, x - 6:x + 6].mean() > 128)
    return n


def find(path):
    """{shot: (first frame, last frame)} of its last take, and the recording's frames a second."""
    cap = cv2.VideoCapture(path)
    fps = cap.get(cv2.CAP_PROP_FPS)
    shots, last, start, i = {}, None, None, 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        n = slate(frame)
        if n is not None:
            if start is not None and last and i - start > fps * 0.3:
                shots[last] = (start, i - 1)
            start, last = None, n
        elif last is not None and start is None:
            start = i + 1  # (a frame in, past the slate's own fade in a compressed recording)
        i += 1
    cap.release()
    return shots, fps


def fit(frame):
    h, w = frame.shape[:2]
    k = max(W / w, H / h)
    f = cv2.resize(frame, (int(round(w * k)), int(round(h * k))), interpolation=cv2.INTER_LANCZOS4 if k > 1 else cv2.INTER_AREA)
    y, x = (f.shape[0] - H) // 2, (f.shape[1] - W) // 2
    return f[y:y + H, x:x + W]


def whip(frame, amount):
    n = int(220 * amount) | 1
    return frame if n < 3 else cv2.blur(frame, (n, 1), borderType=cv2.BORDER_REFLECT)


def words(frame, t):
    font, scale, thick = cv2.FONT_HERSHEY_DUPLEX, 8.0, 34
    sizes = [cv2.getTextSize(c, font, scale, thick)[0][0] if c != " " else 110 for c in TEXT]
    x = (W - sum(sizes)) // 2
    for i, c in enumerate(TEXT):
        u = (t - i * LETTER) / 0.16
        if c != " " and u > 0:
            u = min(u, 1.0)
            drop = int((1 - (1 - (1 - u) ** 3)) * -420)
            size = scale * (1 + 0.25 * np.sin(np.pi * u) * (u < 1))
            y = H // 2 + 90 + drop
            for colour, th in (((40, 20, 10), thick + 34), ((255, 255, 255), thick + 6), ((40, 200, 255), thick - 8)):
                cv2.putText(frame, c, (x, y), font, size, colour, th, cv2.LINE_AA)
        x += sizes[i]
    return frame


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    music = sys.argv[sys.argv.index("--music") + 1] if "--music" in sys.argv else None
    if music:
        args.remove(music)
    src, out = args[0], args[1] if len(args) > 1 else "work/trailer/trailer.mp4"
    shots, fps = find(src)
    missing = [n for n in CUT if n not in shots]
    print("shots found:", sorted(shots), "missing:", missing)
    order = [n for n in CUT if n in shots]
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s",
           f"{W}x{H}", "-r", str(FPS), "-i", "-"]
    if music:
        cmd += ["-i", music, "-shortest", "-c:a", "aac", "-b:a", "192k"]
    cmd += ["-c:v", "libx264", "-preset", "fast", "-crf", "16", "-pix_fmt", "yuv420p", "-movflags", "+faststart", out]
    pipe = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    cap = cv2.VideoCapture(src)
    total, before = 0, False
    for k, n in enumerate(order):
        a, length, speed, into = CUT[n]
        first, end = shots[n]
        count = int(length / speed * FPS)
        want = [min(first + int((a + f / FPS * speed) * fps), end) for f in range(count)]
        cap.set(cv2.CAP_PROP_POS_FRAMES, want[0])
        at, frame = want[0] - 1, None
        for f, w in enumerate(want):
            while at < w or frame is None:
                ok, got = cap.read()
                at += 1
                if not ok:
                    break
                frame = got
            pic = fit(frame)
            if before and f < WHIP:
                pic = whip(pic, 1 - f / WHIP)
            if into and k + 1 < len(order) and count - f <= WHIP:
                pic = whip(pic, 1 - (count - f - 1) / WHIP)
            if n == 20 and f / FPS > TEXT_AT:
                pic = words(pic.copy(), f / FPS - TEXT_AT)
            pipe.stdin.write(pic.tobytes())
        total += count
        before = into
    cap.release()
    pipe.stdin.close()
    pipe.wait()
    print(f"{out}: {total / FPS:.1f} s, {len(order)} shots")


main()
