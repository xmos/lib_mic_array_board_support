#!/bin/bash
_file="$(date +"%Y_%m_%d_%I_%M_%p").log"
echo "Running test..."
xrun --xscope ./bin/4_MICS/test_mic_input_4_MICS.xe &> "$_file"
tail -1 "$_file"