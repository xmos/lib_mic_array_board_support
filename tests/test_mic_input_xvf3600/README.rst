*** NB: needs lib_mic_array written for DDR mics (currently in fork: henkmuller/lib_mic_array, commit 0325fd72b251715e551d56e1eb666212bfb3dd1e).


Overview
--------

This test application is intended for testing arrays of microphones of the XVF3600 board. The dependent libs and versions for this test are listed in the XGIT view xvf3600_mic_test_view.

Running the Test
................

To run the test execute the shell:

   ./run_test.sh

The test takes a few seconds to load then around 8 seconds to run. The output should look something like:

   Microphone 0 working
   Microphone 1 working
   Microphone 2 working
   Microphone 3 working
   Pass: 0.01dB spread

 It will also record a log to a file with the time of execution as its name.

 What The Program Does
 .....................

The purpose of the test is to asertain that the microphones are not damaged, soldered correctly and have a matched response. It does this by first building up a PSD of the spectrum over a window of time (around 8 seconds). Then after data collection is complete converts the specta to RMS magnitude. 

To decide if a microphone pair is matched it performs a linear regression between the respective magnitudes of each frequency bin. For a matched pair the coefficient of determination should be close to one and the ratio of one pair of magnitudes to the other should be approximatly equal to one. This ratio is the response difference between the microphones and is used to detect quiet microphones. The coefficient of determination (unused) detects if there are spectral deviations between the pairs.

Finally, all pairs are compared. The test fails if any pairs are too mismatched.

NB, the test waits for 128 frames to pass before begining in order to allow the DC offset elimination to take effect. This is useful for spotting failing mics as they will have zero output energy.
