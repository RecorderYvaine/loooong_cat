from PIL import Image

img = Image.open('issue7.png')
# Find the leftmost dark pixel to locate the bottom-left corner
leftmost_x = img.width
bottommost_y = 0

for y in range(img.height):
    for x in range(img.width):
        p = img.getpixel((x,y))
        if p[0] < 50 and p[1] < 50 and p[2] < 60: # cat colors
            if x < leftmost_x: leftmost_x = x
            if y > bottommost_y: bottommost_y = y

print(f"Cat bounds: left={leftmost_x}, bottom={bottommost_y}")

# Dump a 20x20 area around the bottom left
start_x = leftmost_x - 2
start_y = bottommost_y - 15

for y in range(start_y, start_y + 20):
    if y >= img.height: continue
    s = ""
    for x in range(start_x, start_x + 20):
        if x >= img.width: continue
        p = img.getpixel((x,y))
        if p[0] < 50 and p[1] < 50 and p[2] < 60:
            s += "##"
        elif p[0] > 60 and p[1] > 60 and p[2] > 100: # Paw colors
            s += "PP"
        else:
            s += "  "
    print(s)
