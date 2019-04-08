#!/bin/sh
# ANL:waggle-license
#  This file is part of the Waggle Platform.  Please see the file
#  LICENSE.waggle.txt for the legal details of the copyright and software
#  license.  For more details on the Waggle project, visit:
#           http://www.wa8.gl
# ANL:waggle-license

echo "test - validate status v1"
../scripts/status-validator < status_example_v1.json

echo "test - validate status v2"
../scripts/status-validator < status_example_v2.json
