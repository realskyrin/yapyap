#!/bin/bash

if [ -z "$1" ]; then
    echo "❌请提供 commit message"
    echo "用法: $0 \"commit message\""
    exit 1
fi

commit_message="$1"

git add .&& git commit -am "${commit_message}" && git push
