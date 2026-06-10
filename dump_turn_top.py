from PIL import Image
img = Image.open('assets/cat_turn_body.png')
for i in range(7):
    frame = img.crop((i*9, 0, i*9+9, 9))
    print(f"Top Frame {i}:")
    for y in range(9):
        s = ""
        for x in range(9):
            p = frame.getpixel((x,y))
            if p[3] > 128: s += "XX"
            else: s += ".."
        print(s)
