/*
 * Board setup routines for the Emerson/Artesyn MVME3100
 *
 * Copyright 2017 Michael Davidsaver
 *
 * Based on earlier code by:
 *
 *  Alessio Igor Bogani <alessio.bogani@elettra.eu>
 *	Xianghua Xiao (x.xiao@freescale.com)
 *	Tom Armistead (tom.armistead@emerson.com)
 *	Copyright 2012 Emerson
 *
 * This program is free software; you can redistribute  it and/or modify it
 * under  the terms of  the GNU General  Public License as published by the
 * Free Software Foundation;  either version 2 of the  License, or (at your
 * option) any later version.
 *
 * Author Michael Davidsaver <mdavidsaver@gmail.com>
 *
 */

#include <linux/pci.h>
#include <asm/udbg.h>
#include <asm/mpic.h>
#include <sysdev/fsl_soc.h>
#include <sysdev/fsl_pci.h>

#include "mpc85xx.h"

void __init mvme3100_pic_init(void)
{
    struct mpic *mpic = mpic_alloc(NULL, 0,
          MPIC_BIG_ENDIAN | MPIC_SINGLE_DEST_CPU,
        0, 256, " OpenPIC  ");
    BUG_ON(mpic == NULL);
    mpic_init(mpic);
}

/*
 * Setup the architecture
 */
static void __init mvme3100_setup_arch(void)
{
    if (ppc_md.progress)
        ppc_md.progress("mvme3100_setup_arch()", 0);
    fsl_pci_assign_primary();
    pr_info("MVME3100 board from Artesyn\n");
}

machine_arch_initcall(mvme3100, mpc85xx_common_publish_devices);

/*
 * Called very early, device-tree isn't unflattened
 */
static int __init mvme3100_probe(void)
{
    return of_machine_is_compatible("artesyn,MVME3100");
}

static void mvme3100_machine_shutdown(void)
{
    struct device_node *dn = of_find_compatible_node(NULL, NULL, "artesyn,mvme3100-cpld");
    char __iomem *base;

    if (!dn) {
        pr_warn("Unable to find CPLD to request shutdown\n");
        return;
    }

    base = of_iomap(dn, 0);
    if (base) {
        pr_debug("Request Restart");
        iowrite8(ioread8(base+1) | 0xa0, base+1);
        /* we're probably not going to get here, but cleanup anyway */
        iounmap(base);
    }

    of_node_put(dn);
}

define_machine(mvme3100) {
    .name			= "MVME3100",
    .probe			= mvme3100_probe,
    .setup_arch		= mvme3100_setup_arch,
    .init_IRQ		= mvme3100_pic_init,
#ifdef CONFIG_PCI
    .pcibios_fixup_phb      = fsl_pcibios_fixup_phb,
#endif
    .machine_shutdown = mvme3100_machine_shutdown,
    .get_irq		= mpic_get_irq,
    .calibrate_decr		= generic_calibrate_decr,
    .progress		= udbg_progress,
};
