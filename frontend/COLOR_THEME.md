# Color Theme Reference

## Current Color Palette

The frontend uses an earthy, agricultural color scheme:

### Primary Colors (Brown/Tan - Earth tones)
- `primary-50`: #faf5f0 (Light cream)
- `primary-100`: #f5ebe0 (Very light tan)
- `primary-500`: #c69b64 (Medium brown)
- `primary-600`: #b8874a (Darker brown) - Main button color
- `primary-700`: #8f6a3a (Dark brown) - Text/icons

### Secondary Colors (Green - Nature)
- `secondary-50`: #f0f9f4 (Light green)
- `secondary-500`: #50be73 (Medium green)
- `secondary-600`: #3d9559 (Dark green)

### Accent Colors (Gold/Yellow - Harvest)
- `accent-500`: #ffd764 (Gold)
- `accent-600`: #ccac50 (Darker gold)

### Earth Colors (Neutral browns)
- `earth-50`: #faf8f5 (Light earth)
- `earth-100`: #f5f1eb
- `earth-700`: #7b6f5d (Dark earth)
- `earth-800`: #524a3e (Very dark earth)

## Usage

- **Primary**: Buttons, links, active states
- **Secondary**: Accents, success states
- **Accent**: Highlights, special elements
- **Earth**: Text, borders, backgrounds

## Customization

To match your exact Netlify site colors:

1. Inspect your site at https://68d1c22dbc928db43b9cbdbf--agri-trace.netlify.app/
2. Check the CSS/Tailwind classes used
3. Update `tailwind.config.js` with the exact hex colors
4. The components will automatically use the new colors

## Quick Color Update

Edit `tailwind.config.js` and replace the color values in the `extend.colors` section.
