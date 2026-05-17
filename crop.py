from PIL import Image, ImageDraw

img = Image.open('/Users/keller/.gemini/antigravity/brain/ba9e3488-1dc5-4fd0-9819-1045fdd53859/tobisk_tag_editor_icon_1778802964604.png').convert("RGBA")

# Crop coordinates targeting the icon
box = (195, 168, 829, 802)
cropped = img.crop(box)

# Create squircle mask
size = cropped.size
mask = Image.new('L', size, 0)
draw = ImageDraw.Draw(mask)
draw.rounded_rectangle((0, 0, size[0], size[1]), radius=142, fill=255)

cropped.putalpha(mask)
cropped.save('/Users/keller/.gemini/antigravity/brain/ba9e3488-1dc5-4fd0-9819-1045fdd53859/final_icon.png')
