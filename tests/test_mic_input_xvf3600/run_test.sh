#!/bin/bash
_file="$(date +"%Y_%m_%d_%I_%M_%p").log"
echo "Running test..."
xrun --xscope bin/4_MICS_SDR_LIN/test_mic_input_4_MICS_SDR_LIN.xe &> "$_file"
tail -5 "$_file"
