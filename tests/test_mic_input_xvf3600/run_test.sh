#!/bin/bash
_file="$(date +"test_mic_input_xvf3600_4_MICS_SDR_LIN_%Y_%m_%d_%I_%M_%p").log"
echo "Running tests..."
xrun --xscope bin/4_MICS_SDR_LIN/test_mic_input_xvf3600_4_MICS_SDR_LIN.xe &> "$_file"
tail -5 "$_file"
_file="$(date +"test_mic_input_xvf3600_4_MICS_SDR_SQ_%Y_%m_%d_%I_%M_%p").log"
xrun --xscope bin/4_MICS_SDR_SQ/test_mic_input_xvf3600_4_MICS_SDR_SQ.xe &> "$_file"
tail -5 "$_file"
