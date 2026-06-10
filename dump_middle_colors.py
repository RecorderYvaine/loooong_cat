from PIL import Image
img = Image.open('assets/cat_middle_body.png')
print("Middle body colors:")
for x in range(img.width):
    p = img.getpixel((x,0))
    print(f"{x}: {p}")
