#!/usr/bin/env python3
"""Frame strips of an island animation inside a sandbox (tools/sandbox.sh), never on the desktop.

Runs the trigger command, then grabs grim frames of a region as fast as possible. The shell
should run with LUXSHELL_SLOWMO (e.g. 10): video time = real time / slowmo, so the frames can be
resampled onto an exact 60 fps grid.

  animstrip.py ref   SANDBOX "X,Y WxH" SLOWMO START_MS=OUT.png [START_MS=OUT.png ...] -- trigger...
      2 x 15 tiles in the layout of ref/13 + ref/14 (60 fps labels, 0..483 ms); the trigger
      sits at START_MS on that timeline (0 = whole animation, or the start fitted on the
      reference so the strip lines up frame by frame with it); one capture, several strips
  animstrip.py row   SANDBOX "X,Y WxH" SLOWMO SCALE OUT.png "LABEL" T1,T2,.. -- trigger...
      one row of frames at the given video times (ms after the trigger), scaled
"""
import json, os, subprocess, sys, tempfile, time
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/inter/InterVariable.ttf'


def sandbox_env(name):
    env = dict(os.environ)
    rt = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
    for line in open(os.path.join(rt, 'luxsandbox', f'{name}.env')):
        k, v = line.replace('export ', '').strip().split('=', 1)
        env[k] = v
    return env


def capture(env, geom, trigger, seconds, tmp):
    pre = os.path.join(tmp, 'pre.png')
    subprocess.run(['grim', '-g', geom, pre], env=env, check=True)
    subprocess.run(trigger, env=env, check=True, stdout=subprocess.DEVNULL)
    t0 = time.monotonic_ns()
    frames, i = [], 0
    while (time.monotonic_ns() - t0) / 1e9 < seconds:
        f = os.path.join(tmp, f'f{i:04d}.png')
        a = time.monotonic_ns()
        subprocess.run(['grim', '-g', geom, f], env=env, check=True)
        frames.append((((a + time.monotonic_ns()) / 2 - t0) / 1e6, f))
        i += 1
    return pre, frames


def pick(pre, frames, slowmo, t):
    if t < 0:
        return pre
    return min(frames, key=lambda x: abs(x[0] / slowmo - t))[1]


def main():
    argv = sys.argv[1:]
    trigger = argv[argv.index('--') + 1:]
    args = argv[:argv.index('--')]
    mode, name, geom, slowmo = args[0], args[1], args[2], float(args[3])
    env = sandbox_env(name)
    with tempfile.TemporaryDirectory() as tmp:
        if mode == 'ref':
            jobs = [(float(a.split('=', 1)[0]), a.split('=', 1)[1]) for a in args[4:]]
            pre, frames = capture(env, geom, trigger, (500 - min(j[0] for j in jobs) + 60) * slowmo / 1000, tmp)
            font = ImageFont.truetype(FONT, 15)
            w, h = Image.open(pre).size
            for start, out in jobs:
                strip = Image.new('RGB', (2 * w, 15 * h))
                for k in range(30):
                    t = round(k * 1000 / 60)
                    im = Image.open(pick(pre, frames, slowmo, k * 1000 / 60 - start)).convert('RGB')
                    ImageDraw.Draw(im).text((8, h - 22), f'00:00:00.{t:03d}', fill=(255, 230, 0), font=font)
                    strip.paste(im, ((k % 2) * w, (k // 2) * h))
                strip.save(out)
        elif mode == 'row':
            scale, out, label = float(args[4]), args[5], args[6]
            times = [float(x) for x in args[7].split(',')]
            pre, frames = capture(env, geom, trigger, (max(times) + 60) * slowmo / 1000, tmp)
            font = ImageFont.truetype(FONT, 13)
            w, h = Image.open(pre).size
            tw, th = int(w * scale), int(h * scale)
            row = Image.new('RGB', (tw * len(times), th))
            for c, t in enumerate(times):
                im = Image.open(pick(pre, frames, slowmo, t)).convert('RGB').resize((tw, th), Image.LANCZOS)
                d = ImageDraw.Draw(im)
                d.text((6, th - 18), f'+{t:.0f} ms', fill=(255, 230, 0), font=font)
                if c == 0:
                    d.text((6, th - 34), label, fill=(255, 230, 0), font=font)
                row.paste(im, (c * tw, 0))
            row.save(out)
        else:
            sys.exit(__doc__)


if __name__ == '__main__':
    main()
