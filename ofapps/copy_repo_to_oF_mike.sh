#!/bin/bash
OF_ROVER_PATH=/Applications/of_v0.8.4_osx_release/apps/rover
REPO_ROVER_PATH=/Users/admin/src/rover/ofapps
rsync -avz --progress $REPO_ROVER_PATH/* $OF_ROVER_PATH