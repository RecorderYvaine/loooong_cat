import struct
import sys
def get_png_size(f):
    try:
        data = open(f, 'rb').read(24)
        if data[:8] == b'\x89PNG\r\n\x1a\n':
            return struct.unpack('>ii', data[16:24])
    except: pass
    return (0, 0)
for img in ['cat_head.png', 'cat_upper_body.png', 'cat_middle_body.png', 'cat_bottom_body.png', 'cat_turn_body.png']:
    print(img, get_png_size('assets/' + img))
