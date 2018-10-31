#!/bin/sh

echo "test - validate status v1"
../scripts/status-validator < status_example_v1.json

echo "test - validate status v2"
../scripts/status-validator < status_example_v2.json
