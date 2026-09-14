#!/bin/bash

URL=$1
VERSION=$2

success=0
failed=0

for i in {1..30}
do
    response=$(curl -s "$URL")

    if echo "$response" | grep -q "$VERSION"
    then
        echo "Request $i: SUCCESS"
        success=$((success+1))
    else
        echo "Request $i: FAILED"
        failed=$((failed+1))
    fi
done

echo
echo "Successful requests: $success"
echo "Failed requests: $failed"

if [ $failed -eq 0 ]
then
    echo "RESULT: PASS"
else
    echo "RESULT: FAIL"
fi