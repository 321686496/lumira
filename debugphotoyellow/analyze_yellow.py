import os, sys
from PIL import Image

os.chdir(os.path.dirname(os.path.abspath(__file__)))

def analyze(path):
    img = Image.open(path)
    rgb = img.convert('RGB')
    w, h = rgb.size
    px = rgb.load()
    print(f"=== {path}  {w}x{h} ===")

    # overall average
    import statistics
    R = G = B = 0
    n = 0
    for y in range(0, h, 8):
        for x in range(0, w, 8):
            r, g, b = px[x, y]
            R += r; G += g; B += b; n += 1
    R/=n; G/=n; B/=n
    print(f"overall avg R={R:.1f} G={G:.1f} B={B:.1f}  R-B={R-B:+.1f} R-G={R-G:+.1f}")

    # high-light (near-white) region: pixels with all channels high, measure their cast
    rHung=bHung=gHung=0; nh=0
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            r,g,b = px[x,y]
            if min(r,g,b) > 120 and max(r,g,b) > 170:
                rHung+=r; gHung+=g; bHung+=b; nh+=1
    if nh>0:
        rHung/=nh; gHung/=nh; bHung/=nh
        print(f"highlight avg R={rHung:.1f} G={gHung:.1f} B={bHung:.1f}  R-B={rHung-bHung:+.1f} R-G={rHung-gHung:+.1f}  (n={nh})")

    # neutral-gray assumption: find pixels where channels are close, measure true neutral cast
    rN=gN=bN=0; nn=0
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            r,g,b = px[x,y]
            if max(r,g,b)-min(r,g,b) < 18 and r>40:
                rN+=r; gN+=g; bN+=b; nn+=1
    if nn>0:
        rN/=nn; gN/=nn; bN/=nn
        print(f"50%gray-ish avg R={rN:.1f} G={gN:.1f} B={bN:.1f}  R-B={rN-bN:+.1f} R-G={rN-gN:+.1f}  (n={nn})")
    print()

for p in ["raw_src.jpg", "final_out.jpg"]:
    analyze(p)