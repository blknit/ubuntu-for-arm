itest.b *0x10028 == 0x00 && echo "U-boot loaded from SD"
itest.b *0x10028 == 0x02 && echo "U-boot loaded from eMMC or secondary SD"
itest.b *0x10028 == 0x03 && echo "U-boot loaded from SPI"

load mmc 0:1 ${kernel_addr_r} EFI/BOOT/BOOTAA64.EFI
load mmc 0:1 ${fdt_addr_r} u-boot.dtb
bootefi ${kernel_addr_r} ${fdt_addr_r}
