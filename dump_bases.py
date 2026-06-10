from PIL import Image

def dump(f):
    try:
        img = Image.open(f)
        print(f"--- {f} ---")
        for y in range(img.height):
            s = ""
            for x in range(img.width):
                p = img.getpixel((x,y))
                if p[3] > 128:
                    s += "XX"
                else:
                    s += "  "
            print(s)
    except Exception as e:
        print(f"Error {f}: {e}")

dump('assets/cat_upper_body.png')
dump('assets/cat_bottom_body.png')
dump('assets/cat_tail.png')
