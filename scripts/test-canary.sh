#!/bin/bash

URL=$1

blue=0
green=0

for i in {1..50}
do
    response=$(curl -s "$URL")

    if echo "$response" | grep -q "alpha-v1.0"
    then
        blue=$((blue+1))
        echo "Request $i: BLUE"

    elif echo "$response" | grep -q "beta-v2.0"
    then
        green=$((green+1))
        echo "Request $i: GREEN"
    fi
done

echo
echo "Blue responses: $blue"
echo "Green responses: $green"