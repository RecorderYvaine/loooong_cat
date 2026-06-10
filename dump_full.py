from PIL import Image

img = Image.open('assets/cat_bottom_body.png')
for y in range(img.height):
    s = ""
    for x in range(img.width):
        p = img.getpixel((x,y))
        s += f"({p[0]},{p[1]},{p[2]},{p[3]:03d}) "
    print(s)
