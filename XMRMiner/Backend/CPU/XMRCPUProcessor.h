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

void xmr_hash(void *blob, uint32_t length, char *hash, uint64_t version, uint64_t height);

#endif /* XMRCPUProcessor_h */
