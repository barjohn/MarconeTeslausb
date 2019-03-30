### Building a teslausb image


To build a ready to flash one-step setup image for CIFS, do the following:

1. Clone pi-gen from https://github.com/RPi-Distro/pi-gen
1. Follow the instructions in the pi-gen readme to install the required dependencies
1. In the pi-gen folder, run:
    ```
    echo IMG_NAME=teslausb > config
    rm -rf stage2/EXPORT_NOOBS stage3 stage4 stage5
    mkdir stage7
    touch stage7/EXPORT_IMAGE
    cp stage2/prerun.sh stage7/prerun.sh
    ```
1. Copy teslausb/pi-gen-sources/00-teslausb-tweaks to the stage7 folder
1. Run `build.sh` or `build-docker.sh`, depending on how you configured pi-gen to build the image
1. Sit back and relax, this could take a while (for reference, on a dual-core 2.6 Ghz Intel Core i3 and 50 Mbps internet connection, it took under an hour)
If all went well, the image will be in the `deploy` folder. Use Etcher or similar tool to flash it.
