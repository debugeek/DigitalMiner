//
//  XMRCPUProcessor.c
//  XMRMiner
//
//  Created by Jinxiao on 2018/8/4.
//  Copyright © 2018 debugeek. All rights reserved.
//

#include "XMRCPUProcessor.h"

#import <string.h>
#import <malloc/_malloc.h>

#include "hash-ops.h"

void xmr_hash(void *blob, uint32_t length, uint32_t nonce, uint8_t *hash) {

    __attribute__((aligned(16))) uint8_t blob_buffer[128];

    memmove(blob_buffer, blob, length);
    memmove(blob_buffer + 39, &nonce, sizeof(nonce));

    static void *hashbuf = NULL;
    if (hashbuf == NULL) {
        hashbuf = cn_slow_hash_alloc();
    }

    cn_slow_hash(blob_buffer, length, hash, hashbuf);
}
