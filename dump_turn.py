from PIL import Image
img = Image.open('assets/cat_turn_body.png')
# it's 63x18, bottom row is Y=9 to 18
# frames are 9x9
for i in range(7):
    frame = img.crop((i*9, 9, i*9+9, 18))
    # print an ascii representation
    print(f"Frame {i}:")
    for y in range(9):
        s = ""
        for x in range(9):
            p = frame.getpixel((x,y))
            if p[3] > 128: s += "XX"
            else: s += ".."
        print(s)
