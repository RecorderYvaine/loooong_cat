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

# Find the tail bounding box
tail_min_x = img.width
tail_max_x = 0
for y in range(bottommost_y - 40, bottommost_y + 10):
    for x in range(leftmost_x + 30, leftmost_x + 100):
        p = img.getpixel((x,y))
        if p[0] < 50 and p[1] < 50 and p[2] < 60:
            if x < tail_min_x: tail_min_x = x
            if x > tail_max_x: tail_max_x = x

print(f"Vertical line is around x={leftmost_x}")
print(f"Tail is around x={tail_min_x} to {tail_max_x}")
