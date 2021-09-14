// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#ifndef MIC_ARRAY_CONF_H_
#define MIC_ARRAY_CONF_H_

#define MIC_ARRAY_MAX_FRAME_SIZE_LOG2 7
#define MIC_ARRAY_NUM_MICS 8

#if (SQ_MIC_ARRAY == 1)
#define MIC_ARRAY_CH0      PIN4
#define MIC_ARRAY_CH1      PIN7
#define MIC_ARRAY_CH2      PIN6
#define MIC_ARRAY_CH3      PIN5
#else
#define MIC_ARRAY_CH0      PIN4
#define MIC_ARRAY_CH1      PIN7
#define MIC_ARRAY_CH2      PIN5
#define MIC_ARRAY_CH3      PIN6
#endif
#endif /* MIC_ARRAY_CONF_H_ */
