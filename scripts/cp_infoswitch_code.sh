#!/bin/sh
DEST=$1
cp -r gateways $DEST/lib
cp -r test/integration/infoswitch $DEST/test/integration
#cp -r test/fixtures/vcr_cassettes/InfoSwitch $DEST/test/fixtures/vcr_cassettes/InfoSwitch
