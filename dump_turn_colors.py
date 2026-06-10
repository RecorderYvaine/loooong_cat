from PIL import Image
img = Image.open('assets/cat_turn_body.png')
for y in range(9, 18):
    s = ""
    for x in range(9):
        p = img.getpixel((x,y))
        if p[3] == 0:
            s += "   "
        elif p[0] < 20: # dark outline
            s += "## "
        else:
            s += "OO "
    print(s)
