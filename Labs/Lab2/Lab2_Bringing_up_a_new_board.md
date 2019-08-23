# Bringing up a new board

The overall process is to bring up each of the firmware components in sequence, then create packages, and finally create an FFU configuration. By the end, there will be a new board configuration in the repository that builds an FFU for your board. It is important to create new configurations for your board instead of modifying existing ones, so that you can easily integrate code changes from our repositories. We encourage you to submit your changes via pull request to our repositories so that we can make code changes without breaking your build.

## Initialize the new board configuration

1. Open the IoTCore PowerShell and run `c:\HOLFirmware\imx-iotcore\build\tools\NewiMX6Board.ps1 HOLLab_iMX6Q_2GB`
   >Note: Any new board name should follow the schema of BoardName_SoCType_MemoryCapacity. See imx-iotcore\build\board for examples.  

   This step will create a new board configuration in `c:\HOLFirmware\imx-iotcore\build\board\` and a new firmware folder in `c:\HOLFirmware\imx-iotcore\build\firmware`.

2. Open iMXPlatform solution in Visual Studio (Run VS as Administrator)
3. Open up the Solution Explorer view (Ctrl + Alt + L).
4. Right click the Board Packages folder and select Add Existing Project.
5. Select `C:\HOLFirmware\imx-iotcore\build\board\HOLLab_iMX6Q_2GB\Package\HOLLab_iMX6Q_2GB_Package.vcxproj`
6. Right click on HOLLab_iMX6Q_2GB => Build Dependencies => Project Dependencies then select HalExtiMX6Timers, imxusdhc, and mx6pep.
7. Right click the GenerateTestFFU project => Build Dependencies => Project Dependencies then select HOLLab_iMX6Q_2GB from the list.
8. Right click the GenerateBSP project => Build Dependencies => Project Dependencies then select HOLLab_iMX6Q_2GB from the list.

## Update the firmware
The overall process is to bring up each of the firmware components in sequence, then create packages, and finally create an FFU configuration. By the end, there will be a new board configuration in the repository that builds an FFU for your board. It is important to create new configurations for your board instead of modifying existing ones, so that you can easily integrate code changes from our repositories. 

## Set-up U-Boot
1. Open the Ubuntu shell and change to the u-boot folder `/mnt/c/HOLFirmware/u-boot/` 
2. Copy `configs/mx6cuboxi_nt_defconfig` to `configs/hollabboard_nt_defconfig`
3. Edit `hollabboard_nt_defconfig` to change `CONFIG_TARGET_MX6CUBOXI=y` to `CONFIG_TARGET_HOLLABBOARD=y`.
4. Save the file

## Add a new board to U-Boot

1. Edit `arch/arm/mach-imx/mx6/Kconfig` and add a config option for your board.

       config TARGET_HOLLABBOARD
               bool "HOL Lab iMX6Q board"
               select BOARD_LATE_INIT
               select MX6QDL
               select SUPPORT_SPL

2. Add a source entry for your config and then save the file

       source "board/hol/hollabboard/Kconfig"

3. Create and initialize a board directory

       mkdir -p board/hol/hollabboard
       cp board/solidrun/mx6cuboxi/* board/hol/hollabboard
       mv board/hol/hollabboard/mx6cuboxi.c board/hol/hollabboard/hollabboard.c

4. Edit `board/hol/hollabboard/Makefile` and replace `mx6cuboxi.o` with `hollabboard.o`. Save the file.

5. Edit `board/hol/hollabboard/Kconfig` and set appropriate values for your board. Note that the build system expects `SYS_CONFIG_NAME` to correspond to the name of a header file in `include/configs`. Also save this file.

       if TARGET_HOLLABBOARD

       config SYS_BOARD
               default "hollabboard"

       config SYS_VENDOR
               default "hol"

       config SYS_CONFIG_NAME
               default "hollabboard"

       endif

6. Create a config header for your board

       cp include/configs/mx6cuboxi.h include/configs/hollabboard.h

## Modify OP-TEE
OP-TEE is mostly board-independent. Right now, the only configuration that needs to be changed is the console UART. In the future, there may be other board-specific configurations that need to change as trusted I/O is implemented.

1. Change to the `/mnt/c/HOLFirmware/optee_os/` folder

2. Edit `core/arch/arm/plat-imx/conf.mk` to include our new board. Add the following to `mx6q-flavorlist`

       mx6qhollab \

3. Add the following to the `conf.mk` file:

       ifneq (,$(filter $(PLATFORM_FLAVOR),mx6qhollab))
       CFG_DDR_SIZE ?= 0x80000000
       CFG_UART_BASE ?= UART1_BASE
       endif

4. Save the file.

## Setting up your build enviroment to build firmware_fit.merged

In order to build and load both OPTEE and U-Boot you will need to create a Flattened Image Tree (FIT) binary to flash onto your device. The build enviroment for FIT images is integrated into the build infrastructure. This will sign SPL for [high assurance boot](build-firmware.md#signing-and-high-assurance-boot-hab), and combine SPL, U-Boot, and OP-TEE into a single `firmware_fit.merged` file that can be tested manually, or built into an FFU image as part of a BSP.

1. Change to the folder `/mnt/c/HOLFirmware/imx-iotcore/`
2. Copy `imx-iotcore/build/firmware/hummingboard` to `imx-iotcore/build/firmware/HOLLab_iMX6Q_2GB`

       pushd build/firmware/HummingBoardEdge_iMX6Q_2GB
       make clean
       popd
       mkdir -p build/firmware/HOLLab_iMX6Q_2GB
       cp -r build/firmware/HummingBoardEdge_iMX6Q_2GB/* build/firmware/HOLLab_iMX6Q_2GB

3. Edit `build/firmware/HOLLab_iMX6Q_2GB/Makefile` and change the `UBOOT_CONFIG` and the OP-TEE `PLATFORM` for your board.

       UBOOT_CONFIG=hollabboard_nt_defconfig

       $(MAKE) -C $(OPTEE_ROOT) O=$(OPTEE_OUT) PLATFORM=imx-mx6qhollab \

       BUG:
       Add the flag "EDK2_FLAGS=-D CONFIG_NOT_SECURE_UEFI=1" to the Makefile to disable fTPM. This is due to version incompatibilities in the repos as at 8/11/2019.

4. Run `make` in `imx-iotcore/build/firmware/HOLLab_iMX6Q_2GB` and verify that `firmware_fit.merged` is generated.

       cd build/firmware/HOLLab_iMX6Q_2GB/
       make

   >Note: If you have already run make in the u-boot directory you will need to clean it using `make mrproper`

5. Verify that `firmware_fit.merged` is created.

## UEFI

UEFI is required to boot Windows. UEFI provides a runtime environment for the Windows bootloader, access to storage, hardware initialization, ACPI tables, and a description of the memory map. First we construct a minimal UEFI with only eMMC and debugger support. Then, we add devices one-by-one to the system.

1. Change to the `/mnt/c/HOLFirmware/imx-edk2-platforms/` directory

2. Copy `Platform\SolidRun\HUMMINGBOARD_EDGE_IMX6Q_2GB` to `Platform\hol\HOLLab_iMX6Q_2GB`.

       mkdir -p Platform/hol/HOLLab_iMX6Q_2GB
       cp -r Platform/SolidRun/HummingBoardEdge_iMX6Q_2GB/* Platform/hol/HOLLab_iMX6Q_2GB

1. Rename the `.dsc` and `.fdf` files to match the folder name.

       mv Platform/hol/HOLLab_iMX6Q_2GB/HummingBoardEdge_iMX6Q_2GB.dsc Platform/hol/HOLLab_iMX6Q_2GB/HOLLab_iMX6Q_2GB.dsc
       mv Platform/hol/HOLLab_iMX6Q_2GB/HummingBoardEdge_iMX6Q_2GB.fdf Platform/hol/HOLLab_iMX6Q_2GB/HOLLab_iMX6Q_2GB.fdf

### DSC and FDF file

Edit the `Platform/hol/HOLLab_iMX6Q_2GB/HOLLab_iMX6Q_2GB.dsc` file and change the following settings as appropriate for your board:

 * `BOARD_NAME` - set to `HOLLab_iMX6Q_2GB`
 * `BOARD_DIR` - set to `Platform/hol/$(BOARD_NAME)`

### Board-specific Initialization

The file `Platform/hol/HOLLab_iMX6Q_2GB/Library/iMX6BoardLib/iMX6BoardInit.c` contains board-specific initialization code, which includes:

 - Pin Muxing
 - Clock initialization
 - PHY initialization

For the purposes of this lab we're not going to make changes to this file. Our sensor doesn't require start-up initialization.

## ACPI Tables

For initial bringup, you should start with a minimal DSDT that contains only the devices required to boot. You should then add devices one-by-one, and test each device as you bring it up.

Again for the purposes of this lab we will not be taking the typical approach and instead be modifying just the ACPI table that needs to change to support the new device.

### Dsdt changes

1. Change to the ACPI Tables directory

       cd /mnt/c/HOLFirmware/imx-edk2-platforms/Platform/hol/HOLLab_iMX6Q_2GB/AcpiTables

1. Edit `Dsdt.asl` and add the following ASL to define the new sensor:

       include ("Dsdt-Accel.asl")

2. Copy the Dsdt-Accel.asl file into the AcpiTables directory:

       cp /mnt/c/Users/HOL/source/repos/IoTHOL/Labs/Lab2/Dsdt-Accel.asl .

## Building UEFI

1. Change `/mnt/c/HOLFirmware/imx-iotcore/build/firmware/HOLLab_iMX6Q_2GB/Makefile` to use your .dsc & .fdf files. Modify the entries for `EDK2_DSC` and `EDK2_PLATFORM` to:

       EDK2_DSC=HOLLab_iMX6Q_2GB
       EDK2_PLATFORM=hol/HOLLab_iMX6Q_2GB

2. Save the file.

3. Change to the `/mnt/c/HOLFirmware/imx-iotcore/build/firmware/HOLLab_iMX6Q_2GB/` directory and run `make`:

       cd /mnt/c/HOLFirmware/imx-iotcore/build/firmware/HOLLab_iMX6Q_2GB/
       make

## Testing UEFI

To test UEFI, you will need an SD card with a FAT partition. The easiest way to get an SD card with the right partition layout is to flash the HummingBoard FFU, then replace the firmware components.

1. Ensure your firmware built correctly in the previous sections.

2. Copy the `firmware_fit.merged` and `uefi.fit` files to the `C:\HOLFirmware` directory.

       cp /mnt/c/HOLFirmware/imx-iotcore/build/firmware/HOLLab_iMX6Q_2GB/firmware_fit.merged /mnt/c/HOLFirmware
       cp /mnt/c/HOLFirmware/imx-iotcore/build/firmware/HOLLab_iMX6Q_2GB/uefi.fit /mnt/c/HOLFirmware

3. Switch back to your IoTPShell.

4. Flash the basic FFU created in lab 1 to your SD card

       dism /apply-image /imagefile:C:\MyWorkspace\Build\arm\ProductA\Test\Flash.ffu /applydrive:\\.\PhysicalDrive2 /skipPlatformCheck

5. From an elevated Command Prompt, use the `dd` command to flash `firmware_fit.merged` to the SD card.

       c:\HOLFirmware\dd.exe if=c:\HOLFirmware\firmware_fit.merged of=\\.\PhysicalDrive2 bs=512 seek=2
       
   >Note: DD for Windows will show an error 87. This can be ignored.

6. Replace `uefi.fit` on the EFIESP partition/drive of the SD card with your `uefi.fit` from the `C:\HOLFirmware` directory.

7. Power on the system. You should see UEFI run after U-Boot, and UEFI should attempt to load Windows. The Administrator password is the default for Windows IoT Core - p@ssw0rd

   >Note: The current version of the u-boot source causes the screen buffer to become corrupted. This will display as a torn color image. Please continue to wait and the screen will go black and continue with the booting process.

# If there is a problem booting Windows

As long as the serial console and SDHC device node are configured correctly in UEFI, the Windows kernel should get loaded. Once you see the kernel looking for a debugger connection, you can close the serial terminal and start WinDBG.

       windbg.exe -k com:port=COM3,baud=115200

If you hit an `INACCESSIBLE_BOOT_DEVICE` bugcheck, it means there's a problem with the storage driver. Run `!devnode 0 1` to inspect the device tree, and see what the status of the SD driver is. You can dump the log from the SD driver by running:

       !rcdrkd.rcdrlogdump imxusdhc.sys

After you have a minimal booting Windows image, the next step is to bring up and test each device.

## Next Lab

[Lab 3 - Creating a new Board Support Package](/Labs/Lab3/Lab3_Creating_a_new_BSP.md)

## Previous Lab

[Lab 1 - Create a basic image](/Labs/Lab1/Lab1_Create_a_basic_image.md)