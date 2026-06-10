from PIL import Image

def dump(f):
    img = Image.open(f)
    print(f"--- {f} ---")
    for y in range(img.height):
        s = ""
        for x in range(img.width):
            p = img.getpixel((x,y))
            if p[3] > 128:
                if p[0] < 50 and p[1] < 50 and p[2] < 50:
                    s += "##" # Dark outline
                else:
                    s += "OO" # Body
            else:
                s += "  "
        print(s)

dump('assets/cat_middle_body.png')
dump('assets/cat_turn_body.png')
dump('assets/cat_head.png')
