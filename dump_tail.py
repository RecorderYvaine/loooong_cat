from PIL import Image

img = Image.open('issue7.png')
leftmost_x = img.width
bottommost_y = 0

for y in range(img.height):
    for x in range(img.width):
        p = img.getpixel((x,y))
        if p[0] < 50 and p[1] < 50 and p[2] < 60:
            if x < leftmost_x: leftmost_x = x
            if y > bottommost_y: bottommost_y = y

start_x = leftmost_x + 18
start_y = bottommost_y - 20

print("Dumping area to the right of the vertical line:")
for y in range(start_y, start_y + 25):
    if y >= img.height: continue
    s = ""
    for x in range(start_x, start_x + 25):
        if x >= img.width: continue
        p = img.getpixel((x,y))
        if p[0] < 50 and p[1] < 50 and p[2] < 60:
            s += "##"
        else:
            s += "  "
    print(s)
