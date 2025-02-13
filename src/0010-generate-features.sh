cat zpool-features.csv \
    | awk -F , '/^[^,]+,[^,]+,yes,/{print "-o feature@" $1 "=enabled\0"}' \
    | tr -d '\n' \
    | xargs -0 printf '%s\n' \
    > zpool-features-enabled.txt
