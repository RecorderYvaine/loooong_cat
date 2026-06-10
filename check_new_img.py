import struct
def get_png_size(f):
    try:
        data = open(f, 'rb').read(24)
        if data[:8] == b'\x89PNG\r\n\x1a\n':
            return struct.unpack('>ii', data[16:24])
    except: pass
    return (0, 0)
print('New Bottom:', get_png_size('assets/cat_bottom_body.png'))
print('New Tail:', get_png_size('assets/cat_tail.png'))
