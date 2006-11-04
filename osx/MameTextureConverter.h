/*
 *  MameTextureConverter.h
 *  mameosx
 *
 *  Created by Dave Dribin on 9/12/06.
 *
 */

#import <QuartzCore/QuartzCore.h>

extern "C" {
    
#include "osdepend.h"
#include "render.h"
    
}


// Force inlining, even for non-optimized builds.  The performance impact is just
// too high.
#define inline inline __attribute__((always_inline))

class MamePalette16PixelIterator
{
public:
    MamePalette16PixelIterator(const render_texinfo * texture, int row)
        : mPalette(texture->palette)
    {
        mCurrentPixel = (UINT16 *) texture->base;
        mCurrentPixel += row * texture->rowpixels;
    }
    

    UINT32 inline argb_value() const
    {
        return 0xff000000 | mPalette[*mCurrentPixel];
    }

    void inline next()
    {
        mCurrentPixel++;
    }

private:
    UINT16 * mCurrentPixel;
    const rgb_t * mPalette;
};


class MameARGB32PixelIterator
{
public:
    MameARGB32PixelIterator(const render_texinfo * texture, int row)
    {
        mCurrentPixel = (UINT32 *) texture->base;
        mCurrentPixel += row * texture->rowpixels;
    }
    
    UINT32 inline argb_value() const
    {
        return *mCurrentPixel;
    }
    
    void inline next()
    {
        mCurrentPixel++;
    }
    
private:
    UINT32 * mCurrentPixel;
};

class MamePaletteRGB15PixelIterator
{
public:
    MamePaletteRGB15PixelIterator(const render_texinfo * texture, int row)
        : mPalette(texture->palette)
    {
        mCurrentPixel = (UINT16 *) texture->base;
        mCurrentPixel += row * texture->rowpixels;
    }
    
    UINT32 inline argb_value() const
    {
        UINT16 pix = *mCurrentPixel;
        return
            0xff000000 |
            mPalette[0x40 + ((pix >> 10) & 0x1f)] |
            mPalette[0x20 + ((pix >>  5) & 0x1f)] |
            mPalette[0x00 + ((pix >>  0) & 0x1f)];
    }
    
    void inline next()
    {
        mCurrentPixel++;
    }
    
private:
    UINT16 * mCurrentPixel;
    const rgb_t * mPalette;
};


class MameRGB15PixelIterator
{
public:
    MameRGB15PixelIterator(const render_texinfo * texture, int row)
    {
        mCurrentPixel = (UINT16 *) texture->base;
        mCurrentPixel += row * texture->rowpixels;
    }
    
    UINT32 inline argb_value() const
    {
        UINT16 pix = *mCurrentPixel;
        UINT32 color =
            ((pix & 0x7c00) << 9) |
            ((pix & 0x03e0) << 6) |
            ((pix & 0x001f) << 3);
        
        return 0xff000000 | color | ((color >> 5) & 0x070707);
    }
    
    void inline next()
    {
        mCurrentPixel++;
    }
    
private:
    UINT16 * mCurrentPixel;
};

class MamePaletteRGB32PixelIterator
{
public:
    MamePaletteRGB32PixelIterator(const render_texinfo * texture, int row)
        : mPalette(texture->palette)
    {
        mCurrentPixel = (UINT32 *) texture->base;
        mCurrentPixel += row * texture->rowpixels;
    }
    
    UINT32 inline argb_value() const
    {
        UINT32 sourceValue = *mCurrentPixel;
        return
            0xff000000 |
            mPalette[0x200 + RGB_RED(sourceValue)] |
            mPalette[0x100 + RGB_GREEN(sourceValue)] |
            mPalette[0x000 + RGB_BLUE(sourceValue)];
    }
    
    void inline next()
    {
        mCurrentPixel++;
    }
    
private:
    UINT32 * mCurrentPixel;
    const rgb_t * mPalette;
};

class MameRGB32PixelIterator
{
public:
    MameRGB32PixelIterator(const render_texinfo * texture, int row)
    {
        mCurrentPixel = (UINT32 *) texture->base;
        mCurrentPixel += row * texture->rowpixels;
    }
    
    UINT32 inline argb_value() const
    {
        return 0xff000000 | *mCurrentPixel;
    }
    
    void inline next()
    {
        mCurrentPixel++;
    }
    
private:
    UINT32 * mCurrentPixel;
};

template <typename PixelIterator>
class MameTexture
{
public:
    typedef PixelIterator Iterator;

    MameTexture(const render_texinfo * texture)
        : mTexture(texture)
    {
    }
    
    int width() const
    {
        return mTexture->width;
    }
    
    int height() const
    {
        return mTexture->height;
    }
    
    Iterator iteratorForRow(int row)
    {
        return Iterator(mTexture, row);
    }
    
protected:
        const render_texinfo * mTexture;
};

typedef MameTexture<MamePalette16PixelIterator> MamePalette16Texture;
typedef MameTexture<MameARGB32PixelIterator> MameARGB32Texture;
typedef MameTexture<MamePaletteRGB32PixelIterator> MamePaletteRGB32Texture;
typedef MameTexture<MameRGB32PixelIterator> MameRGB32Texture;
typedef MameTexture<MamePaletteRGB15PixelIterator> MamePaletteRGB15Texture;
typedef MameTexture<MameRGB15PixelIterator> MameRGB15Texture;

class BGRA32PixelIterator
{
public:
#if __BIG_ENDIAN__
    static const int kPixelFormat = k32BGRAPixelFormat;
#else
    static const int kPixelFormat = k32ARGBPixelFormat;
#endif
    
    BGRA32PixelIterator(UINT32 * base)
        : mCurrentPixel(base)
    {
    }
    
    template <typename MamePixelIterator>
    void inline copy_from(const MamePixelIterator & src)
    {
        UINT32 argb_value = src.argb_value();
        *mCurrentPixel =
            (argb_value & 0x000000ff) << 24 |
            (argb_value & 0x0000ff00) <<  8 |
            (argb_value & 0x00ff0000) >>  8 |
            (argb_value & 0xff000000) >> 24;
    }
    
    void inline next()
    {
        mCurrentPixel++;
    }
    
private:
    UINT32 * mCurrentPixel;
};


class ARGB32PixelIterator
{
public:
#if __BIG_ENDIAN__
    static const int kPixelFormat = k32ARGBPixelFormat;
#else
    static const int kPixelFormat = k32BGRAPixelFormat;
#endif

    ARGB32PixelIterator(UINT32 * base)
        : mCurrentPixel(base)
    {
    }
        
    template <typename MamePixelIterator>
    void inline copy_from(const MamePixelIterator & src)
    {
        *mCurrentPixel = src.argb_value();
    }
    
    void inline next()
    {
        mCurrentPixel++;
    }
    
private:
    UINT32 * mCurrentPixel;
};

template <typename PixelIterator>
class Generic32PixelBuffer
{
public:
    typedef PixelIterator Iterator;
    
    static const int kPixelFormat = PixelIterator::kPixelFormat;
    
    Generic32PixelBuffer(void * base, size_t bytesPerRow)
        : mBase(base), mBytesPerRow(bytesPerRow)
    {
    }
    
    Iterator iteratorForRow(int row)
    {
        UINT8 * startAddress = (UINT8 *) mBase;
        startAddress += row * mBytesPerRow;
        return Iterator((UINT32 *) startAddress);
    }
    
private:
    void * mBase;
    size_t mBytesPerRow;
};

typedef Generic32PixelBuffer<ARGB32PixelIterator> ARGB32PixelBuffer;
typedef Generic32PixelBuffer<BGRA32PixelIterator> BGRA32PixelBuffer;

template <typename SourceType, typename DestType>
inline void convertTexture(SourceType & source, DestType & dest)
{
    int height = source.height();
    int width = source.width();
    
    for (int y = 0; y < height; y++)
    {
        typename SourceType::Iterator sourceIterator = source.iteratorForRow(y);
        typename DestType::Iterator destIterator = dest.iteratorForRow(y);
        
        for (int x = 0; x < width; x++)
        {
            destIterator.copy_from(sourceIterator);
            sourceIterator.next();
            destIterator.next();
        }
    }
};


#if 1
// ARGB32 is faster on OS X
typedef ARGB32PixelBuffer PixelBuffer;
#else
typedef BGRA32PixelBuffer PixelBuffer;
#endif


#undef inline
