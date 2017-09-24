#!/bin/sh
# images2fax.sh -- Walter Doekes 2010
# Mikhail Rodionov 2015
# vim: set ts=8 sw=4 sts=4 et:

#
# Get arguments / show help
#

IMCONVERT="`which convert`"
if [ "$#" -lt 2 -o -z "$IMCONVERT" ]; then
    cat >&2 << __EOF__
Usage: $0 OUTPUT.TIFF INPUT.IMG...
Converts a collection of input images to a single multipage tiff to be
sent using the asterisk SendFAX application.

Requires ImageMagick convert(1), found at: ${IMCONVERT:-NOT FOUND}
__EOF__
    exit 1
fi
OUTPUT="$1" ; shift


#
# Utility functions
# (mktemp and mktemp_tiff return filenames safe to use without double quotes)
#

mktemp_tiff() {
    # Bah, this is ugly.
    file=`mktemp`
    mv -n $file $file.tiff
    if [ $? = 0 ]; then
        file=$file.tiff
    else
        rm $file
        file=`mktemp_tiff` # filename in use? try again
    fi
    echo $file
}

resize_image_to_1728x2292() {
    input="$1"
    output=`mktemp_tiff`
    # (-alpha: remove transparency)
    # (-resample: scale to correct proportions)
    # (-scale: resize up/down so it fits)
    # (-extent: add white canvas)
    "$IMCONVERT" "$input" -alpha off -resample 204x196 -scale 1728x2292 \
        -extent 1728x2292 $output
    if [ $? != 0 ]; then
        rm $output
        exit 1
    fi
    echo $output
}

convert_image_to_tiff() {
    input="$1"
    output=`mktemp_tiff`
    "$IMCONVERT" "$input" -compress Fax -units PixelsPerInch -density 204x196 \
        -antialias -resize '1728x2292!' -dither FloydSteinberg -monochrome \
        -dither FloydSteinberg -monochrome $output
    if [ $? != 0 ]; then
        rm $output
        exit 1
    fi
    echo $output
}


#
# Main: convert individual images and combine them
#

converted_list=""
for image in $@; do
    # Resize image
    resized=`resize_image_to_1728x2292 "$image"`
    if [ $? != 0 ]; then
        echo "Failure resizing $image. Aborting..." >&2
        [ -n "$converted_list" ] && rm $converted_list
        exit 1
    fi

    # Convert image
    converted=`convert_image_to_tiff $resized`
    if [ $? != 0 ]; then
        echo "Failure converting $image. Aborting..." >&2
        rm $converted_list $resized
        exit 1
    fi

    # Append to list
    rm $resized
    converted_list="$converted_list $converted"
done

"$IMCONVERT" '(' -coalesce $converted_list ')' "$OUTPUT"
status=$?
rm $converted_list
exit $status

