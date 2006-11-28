/*
 *  symbols.c
 *  mameosx
 *
 *  Created by Dave Dribin on 11/27/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#include "audit.h"

void link_symbols(void)
{
    audit_images(0, 0, 0);
    audit_summary(0, 0, 0, 0);
}

