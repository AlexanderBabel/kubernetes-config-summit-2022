#!/bin/bash -e

files=$(for file in "$@"; do echo "$file" | sed 's/\/[0-9A-Za-z_.-]*\.yaml$//' | sed 's/\/templates$//' | sed 's/\/values$//'; done | awk '!a[$0]++' | jq -nR '[inputs | select(length>0)]')
echo ::set-output name=files::${files}
