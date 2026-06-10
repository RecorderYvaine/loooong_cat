from PIL import Image
img = Image.open('assets/cat_middle_body.png')
print("Middle body:")
for y in range(img.height):
    s = ""
    for x in range(img.width):
        p = img.getpixel((x,y))
        if p[3] > 128: s += "XX"
        else: s += ".."
    print(s)
