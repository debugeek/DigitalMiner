//
//  XMRCPUProcessor.h
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/4.
//  Copyright © 2018 debugeek. All rights reserved.
//

#ifndef XMRCPUProcessor_h
#define XMRCPUProcessor_h

#include <stdio.h>
#include <stdbool.h>

void xmr_hash(void *blob, uint32_t length, uint32_t nonce, uint8_t *hash);

#endif /* XMRCPUProcessor_h */
