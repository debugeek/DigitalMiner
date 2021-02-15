//
//  XMRCPUProcessor.c
//  DigitalMiner
//
//  Created by Jinxiao on 2018/8/4.
//  Copyright © 2018 debugeek. All rights reserved.
//

#include "XMRCPUProcessor.h"

#import <string.h>
#import <malloc/_malloc.h>

#include "hash-ops.h"

void xmr_hash(void *blob, uint32_t length, char *hash, uint64_t version, uint64_t height) {
    __attribute__((aligned(16))) uint8_t buffer[128];
    memmove(buffer, blob, length);

    static void *ctx = NULL;
    if (ctx == NULL) {
        ctx = cn_slow_hash_alloc();
    }

    cn_slow_hash(buffer, length, hash, ctx, version, height);
}
