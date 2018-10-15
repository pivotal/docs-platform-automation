#!/bin/bash -e

DIR=$(dirname $0)

for file in $(ls ${DIR}/../*.mmd.erb)
do
  filename=$(basename $file)
  firstchar=${filename:0:1}
  if [ $firstchar != "_" ]; then
    mv $file $(dirname $file)/_$filename
  fi
done