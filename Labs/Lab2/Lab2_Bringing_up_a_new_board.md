# Bringing up a new board

The overall process is to bring up each of the firmware components in sequence, then create packages, and finally create an FFU configuration. By the end, there will be a new board configuration in the repository that builds an FFU for your board. It is important to create new configurations for your board instead of modifying existing ones, so that you can easily integrate code changes from our repositories. We encourage you to submit your changes via pull request to our repositories so that we can make code changes without breaking your build.

## Initialize the new board configuration

1. Open the IoTCore PowerShell and run:

   ```powershell
   c:\HOLFirmware\imx-iotcore\build\tools\NewiMX6Board.ps1 HOLLab_iMX6Q_2GB
   ```

   >Note: Any new board name should follow the schema of BoardName_SoCType_MemoryCapacity. See imx-iotcore\build\board for examples.  

   This step will create a new board configuration in `c:\HOLFirmware\imx-iotcore\build\board\` and a new firmware folder in `c:\HOLFirmware\imx-iotcore\build\firmware`.

2. Open iMXPlatform solution in Visual Studio (Visual Studio is running as an administrator so it will ask for approval, click `Yes` to continue).
3. Open up the Solution Explorer view (Ctrl + Alt + L) if it is not already open.

   ![Add an existing project](AddExistingProject.png)

4. Right click the Board Packages folder and select Add Existing Project.
5. Select `C:\HOLFirmware\imx-iotcore\build\board\HOLLab_iMX6Q_2GB\Package\HOLLab_iMX6Q_2GB_Package.vcxproj`
6. Right click on HOLLab_iMX6Q_2GB => Build Dependencies => Project Dependencies then select HalExtiMX6Timers, imxusdhc, and mx6pep.
   ![Set project dependencies](ProjectDependencies.png)
7. Right click the GenerateTestFFU project => Build Dependencies => Project Dependencies then select HOLLab_iMX6Q_2GB from the list.
8. Right click the GenerateBSP project => Build Dependencies => Project Dependencies then select HOLLab_iMX6Q_2GB from the list.

## Update the firmware
The overall process is to bring up each of the firmware components in sequence, then create packages, and finally create an FFU configuration. By the end, there will be a new board configuration in the repository that builds an FFU for your board. It is important to create new configurations for your board instead of modifying existing ones, so that you can easily integrate code changes from our repositories. 

## Set-up U-Boot
1. Open the Ubuntu shell and change to the u-boot folder:

   ```
   cd /mnt/c/HOLFirmware/u-boot/
   ```

2. Copy `configs/mx6cuboxi_nt_defconfig` to `configs/hollabboard_nt_defconfig`

   ```
   cp configs/mx6cuboxi_nt_defconfig configs/hollabboard_nt_defconfig
   ```

3. Edit `hollabboard_nt_defconfig` to change `CONFIG_TARGET_MX6CUBOXI=y` to `CONFIG_TARGET_HOLLABBOARD=y`. The following command uses Nano as the editor but you can use whatever Ubuntu editor you prefer:

   ```
   nano configs/hollabboard_nt_defconfig
   ```

   ![Editing the defconfig file](EditDefconfig.png)

4. Save the file (Nano uses CTRL+X to save).

## Add a new board to U-Boot

1. using `nano` again, edit `arch/arm/mach-imx/mx6/Kconfig` and add a config option for your board.

       config TARGET_HOLLABBOARD
               bool "HOL Lab iMX6Q board"
               select BOARD_LATE_INIT
               select MX6QDL
               select SUPPORT_SPL

   ![Editing KConfig for the target](MX6KConfig-1.png)

2. Add a source entry for your config and then save the file

       source "board/hol/hollabboard/Kconfig"

   ![Editing KConfig for the target](MX6KConfig-2.png)

3. Create and initialize a board directory

       mkdir -p board/hol/hollabboard
       cp board/solidrun/mx6cuboxi/* board/hol/hollabboard
       mv board/hol/hollabboard/mx6cuboxi.c board/hol/hollabboard/hollabboard.c

4. Edit `board/hol/hollabboard/Makefile` and replace `mx6cuboxi.o` with `hollabboard.o`. Save the file.

   ```
   nano board/hol/hollabboard/Makefile
   ```
   ![Editing the Makefile](Makefile.png)

5. Using Nano, edit `board/hol/hollabboard/Kconfig` and replace the content with the text below. Also save this file.

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

## Modifying the board initialization

If you were building your own board you would be performing your board initialization in the `hollabboard.c` file. As we're using the HummingBoard Edge we just copied the initialization source directly. However, we are adding a new sensor and to make this work with the current implementation we're going to need to do some additional work.

1. Open `C:\HOLFirmware\u-boot\board\hol\hollabboard\hollabboard.c` in Visual Studio by selecting the File menu and then Open and finally File.

   ![Open the file in Visual Studio](VisualStudioFileOpen.png)

2. Below the DECLARE_GLOBAL_DATA_PTR line: 
   >Note: These 2 steps define the pad as a GPIO pad so that when the driver asks for a GPIO Interrupt on this pad Windows correctly creates it. 
   
   ![Paste the code in here](Declare_Global_Data.png)

   Place the following code:
   ``` c++
   #define GPIO_PAD_CTRL                                 \
        (PAD_CTL_HYS | PAD_CTL_SPEED_MED | PAD_CTL_DSE_40ohm)
   
   // Sets the EIM_DA1 pad on the SoC to behave as GPIO bank 3 pin 1 with    properties we specified in GPIO_PAD_CTRL above
   static iomux_v3_cfg_t const accelerometer[] = {
        IOMUX_PADS(PAD_EIM_DA1__GPIO3_IO01 | MUX_PAD_CTRL(GPIO_PAD_CTRL)),
   };
   
   static void setup_iomux_accel(void)
   {
        SETUP_IOMUX_PADS(accelerometer);
   }
   ```

3. Search for the function `board_init`:

   ![Board_init](BoardInit.png)
   
   and insert this line:
   
   ```c++
   setup_iomux_accel();
   ```

   ![Board_Init changes complete](BoardInitComplete.png)
4. Close the files and save them.

## Modify OP-TEE
OP-TEE is mostly board-independent. Right now, the only configuration that needs to be changed is the console UART. In the future, there may be other board-specific configurations that need to change as trusted I/O is implemented.

1. In the Ubuntu shell, change to the `/mnt/c/HOLFirmware/optee_os/` folder:

   ```
   cd /mnt/c/HOLFirmware/optee_os/
   ```

2. Using Nano. edit `core/arch/arm/plat-imx/conf.mk` to include our new board. Add the following to `mx6q-flavorlist`

       mx6qhollab \

   ![ConfMK Changes 1](ConfMK-1.png)

3. Add the following to the `conf.mk` file:

       ifneq (,$(filter $(PLATFORM_FLAVOR),mx6qhollab))
       CFG_DDR_SIZE ?= 0x80000000
       CFG_UART_BASE ?= UART1_BASE
       endif

   ![ConfMK changes 2](ConfMK-2.png)
4. Save the file.

## Setting up your build enviroment to build firmware_fit.merged

In order to build and load both OPTEE and U-Boot you will need to create a Flattened Image Tree (FIT) binary to flash onto your device. The build enviroment for FIT images is integrated into the build infrastructure. This will sign SPL for [high assurance boot](build-firmware.md#signing-and-high-assurance-boot-hab), and combine SPL, U-Boot, and OP-TEE into a single `firmware_fit.merged` file that can be tested manually, or built into an FFU image as part of a BSP.

1. Change to the folder `/mnt/c/HOLFirmware/imx-iotcore/`

   ```
   cd /mnt/c/HOLFirmware/imx-iotcore/
   ```

2. Copy `imx-iotcore/build/firmware/hummingboard` to `imx-iotcore/build/firmware/HOLLab_iMX6Q_2GB`

       pushd build/firmware/HummingBoardEdge_iMX6Q_2GB
       make clean
       popd
       mkdir -p build/firmware/HOLLab_iMX6Q_2GB
       cp -r build/firmware/HummingBoardEdge_iMX6Q_2GB/* build/firmware/HOLLab_iMX6Q_2GB

3. Using Nano, edit `build/firmware/HOLLab_iMX6Q_2GB/Makefile` and change the `UBOOT_CONFIG` and the OP-TEE `PLATFORM` for your board.

       UBOOT_CONFIG=hollabboard_nt_defconfig

       $(MAKE) -C $(OPTEE_ROOT) O=$(OPTEE_OUT) PLATFORM=imx-mx6qhollab \

       BUG:
       We've added the flag "EDK2_FLAGS=-D CONFIG_NOT_SECURE_UEFI=1" to the Makefile to disable fTPM. This is due to version incompatibilities in the repos as at 8/11/2019.

4. Run `make` in `imx-iotcore/build/firmware/HOLLab_iMX6Q_2GB` and verify that `firmware_fit.merged` is generated.

       
       cd build/firmware/HOLLab_iMX6Q_2GB/
       make
       
   >Note: You will be prompted for Administrator elevation during this build. If you don't click `Yes` before the timeout expires your build will fail.

   >Note: If you have already run make in the u-boot directory you will need to clean it using `make mrproper`

5. Verify that `firmware_fit.merged` is created.

## UEFI

UEFI is required to boot Windows. UEFI provides a runtime environment for the Windows bootloader, access to storage, hardware initialization, ACPI tables, and a description of the memory map. First we construct a minimal UEFI with only eMMC and debugger support. Then, we add devices one-by-one to the system.

1. Change to the `/mnt/c/HOLFirmware/imx-edk2-platforms/` directory

   ```
   cd /mnt/c/HOLFirmware/imx-edk2-platforms/
   ```


2. Copy `Platform\SolidRun\HUMMINGBOARD_EDGE_IMX6Q_2GB` to `Platform\hol\HOLLab_iMX6Q_2GB`.

       mkdir -p Platform/hol/HOLLab_iMX6Q_2GB
       cp -r Platform/SolidRun/HummingBoardEdge_iMX6Q_2GB/* Platform/hol/HOLLab_iMX6Q_2GB

1. Rename the `.dsc` and `.fdf` files to match the folder name.

       mv Platform/hol/HOLLab_iMX6Q_2GB/HummingBoardEdge_iMX6Q_2GB.dsc Platform/hol/HOLLab_iMX6Q_2GB/HOLLab_iMX6Q_2GB.dsc
       mv Platform/hol/HOLLab_iMX6Q_2GB/HummingBoardEdge_iMX6Q_2GB.fdf Platform/hol/HOLLab_iMX6Q_2GB/HOLLab_iMX6Q_2GB.fdf

### DSC and FDF file

using Nano edit the `Platform/hol/HOLLab_iMX6Q_2GB/HOLLab_iMX6Q_2GB.dsc` file and change the following settings as appropriate for your board:

 * `BOARD_NAME` - set to `HOLLab_iMX6Q_2GB`
 * `BOARD_DIR` - set to `Platform/hol/$(BOARD_NAME)`

   ![DSC Changes](DSCChanges.png)
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

1. using Nano, edit `DSDT.asl` and add the following ASL to define the new sensor:

       include ("Dsdt-Accel.asl")

   ![DSDT ASL change](ASL.png)

2. Copy the Dsdt-Accel.asl file into the AcpiTables directory:

       cp /mnt/c/Users/HOL/source/repos/IoTHOL/Labs/Lab2/Dsdt-Accel.asl .

## Building UEFI

1. Using Nano, edit `/mnt/c/HOLFirmware/imx-iotcore/build/firmware/HOLLab_iMX6Q_2GB/Makefile` to use your .dsc & .fdf files. Modify the entries for `EDK2_DSC` and `EDK2_PLATFORM` to:

       EDK2_DSC=HOLLab_iMX6Q_2GB
       EDK2_PLATFORM=hol/HOLLab_iMX6Q_2GB

   ![EDK2 Changes](EDK2Changes.png)

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
       
   >Note: The PhysicalDriveX number may vary on your machine. You can use `diskpart` to find the disk number.
   
   >Note: DD for Windows will show an error 87. This can be ignored.

6. Replace `uefi.fit` on the EFIESP partition/drive of the SD card with your `uefi.fit` from the `C:\HOLFirmware` directory.

7. Power on the system. You should see UEFI run after U-Boot, and UEFI should attempt to load Windows. The Administrator password is the default for Windows IoT Core - p@ssw0rd

   >Note: The current version of the u-boot source causes the screen buffer to become corrupted. This will display as a torn color image. Please continue to wait and the screen will go black and continue with the booting process.

# Testing the firmware

1. Once your device has booted and completed the Out Of Box Experience (OOBE), launch the `Windows IoT Core Dashboard`. The device should appear in the list of devices.

   >Note: If prompted by Windows Firewall grant access to private networks.

2. Right click on the device and select `Open device portal`. Use `administrator` as the user and `p@ssw0rd` as the password.

   ![Opening Device Portal](DevicePortal-1.png)

3. Select `Devices` and expand the nodes `ACPI ARM-based PC`, then `Microsoft ACPI-Compliant System`.

   ![Expanding ACPI devices](DevicePortal-2.png)

4. Scroll down to find the `ACPI\ADXL345A\1` entry and click on the gear icon.

   ![Inspecting the ADXL345 device](DevicePortal-3.png)

5. Your node should appear as in the image above. ProblemCode 28 is expected as this is Windows saying that it can't find a driver.

## Next Lab

[Lab 3 - Creating a new Board Support Package](/Labs/Lab3/Lab3_Creating_a_new_BSP.md)

## Previous Lab

[Lab 1 - Create a basic image](/Labs/Lab1/Lab1_Create_a_basic_image.md)