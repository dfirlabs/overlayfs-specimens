#!/bin/bash
#
# Script to generate overlayfs specimens on Linux


EXIT_SUCCESS=0;
EXIT_FAILURE=1;

# Checks the availability of a binary and exits if not available.
#
# Arguments:
#   a string containing the name of the binary
#
assert_availability_binary()
{
    local BINARY=$1;

    which ${BINARY} > /dev/null 2>&1;
    if test $? -ne ${EXIT_SUCCESS};
    then
        echo "Missing binary: ${BINARY}";
        echo "";

        exit ${EXIT_FAILURE};
    fi
}

# Creates a test image file
#
# Arguments:
#   a string containing the path of the image file
#   an integer containing the size of the image file
#   an integer containing the sector size
#   an array containing the arguments for mkfs.ext4
#
create_test_image_file()
{
    IMAGE_FILE1=$1;
    IMAGE_SIZE1=$2;
    SECTOR_SIZE1=$3;
    shift 3;
    local ARGUMENTS=("$@");

    sudo dd if=/dev/zero of=${IMAGE_FILE1} bs=${SECTOR_SIZE1} count=$(( ${IMAGE_SIZE1} / ${SECTOR_SIZE1})) 2> /dev/null;
    echo $? "Creating disk image ${IMAGE_FILE1}";

    sudo mkfs.ext4 -F -q ${ARGUMENTS[@]} ${IMAGE_FILE1};
    echo $? "Making EXT4 file system (${IMAGE_FILE1})";
}


# Unmounts the overlay filesystem and its different layers.
umount_overlay()
{
    if mountpoint -q ${MOUNT_POINT}/overlay; then
        sudo umount ${MOUNT_POINT}/overlay;
        echo "Unmounted ${MOUNT_POINT}/overlay"
    fi
    if mountpoint -q ${MOUNT_POINT}/lower; then
        sudo umount ${MOUNT_POINT}/lower;
        echo "Unmounted ${MOUNT_POINT}/lower"
    fi
    if mountpoint -q ${MOUNT_POINT}/upper; then
        sudo umount ${MOUNT_POINT}/upper;
        echo "Unmounted ${MOUNT_POINT}/upper"
    fi
}

# Creates test overlay files
create_test_overlay_files()
{
    IMAGE_FILE=$1;
    IMAGE_SIZE=$2;
    SECTOR_SIZE=$3;
    shift 3;
    local ARGUMENTS=("$@");

    umount_overlay

    create_test_image_file ${IMAGE_FILE}_lower.dd ${IMAGE_SIZE} ${SECTOR_SIZE} ${ARGUMENTS[@]};
    create_test_image_file ${IMAGE_FILE}_upper.dd ${IMAGE_SIZE} ${SECTOR_SIZE} ${ARGUMENTS[@]};

    rm -rf ${MOUNT_POINT}/lower ${MOUNT_POINT}/upper ${MOUNT_POINT}/overlay
    mkdir -p ${MOUNT_POINT}/lower ${MOUNT_POINT}/upper ${MOUNT_POINT}/overlay

    sudo mount -o loop,rw ${IMAGE_FILE}_lower.dd ${MOUNT_POINT}/lower;
    sudo mount -o loop,rw ${IMAGE_FILE}_upper.dd ${MOUNT_POINT}/upper;
    echo 'Lower/upper image files mounted'

    # create folders for overlay filesystem
    sudo chown $USER:$USER ${MOUNT_POINT}/upper
    mkdir ${MOUNT_POINT}/upper/upper
    mkdir ${MOUNT_POINT}/upper/workdir

    # generate test data in lower layer of overlay
    sudo chown $USER:$USER ${MOUNT_POINT}/lower
    echo 'aaaaaaaa' > ${MOUNT_POINT}/lower/a.txt
    echo '11111111' > ${MOUNT_POINT}/lower/1.txt

    mkdir ${MOUNT_POINT}/lower/deletedir
    touch ${MOUNT_POINT}/lower/deletedir/delete.txt

    mkdir ${MOUNT_POINT}/lower/replacedir
    touch ${MOUNT_POINT}/lower/replacedir/replace.txt

    mkdir ${MOUNT_POINT}/lower/testdir
    echo 'bbbbbbbb' > ${MOUNT_POINT}/lower/testdir/b.txt

    echo "Generated test data in lower layer."

    # remount lower directory as read-only
    sudo mount -f -o remount,ro ${IMAGE_FILE}_lower.dd ${MOUNT_POINT}/lower;

    # mount overlay filesystem
    sudo mount -t overlay -o lowerdir=${MOUNT_POINT}/lower,upperdir=${MOUNT_POINT}/upper/upper,workdir=${MOUNT_POINT}/upper/workdir none ${MOUNT_POINT}/overlay

      # generate test data in the overlay (i.e. the upper layer)
    echo 'cccccccc' > ${MOUNT_POINT}/overlay/c.txt;
    echo 'dddddddd' > ${MOUNT_POINT}/overlay/testdir/d.txt;

    mkdir ${MOUNT_POINT}/overlay/newdir;
    echo 'eeeeeeee' > ${MOUNT_POINT}/overlay/newdir/e.txt;

    rm -rf ${MOUNT_POINT}/overlay/deletedir;
    rm ${MOUNT_POINT}/overlay/1.txt;

    rm -fr ${MOUNT_POINT}/overlay/replacedir;
    mkdir ${MOUNT_POINT}/overlay/replacedir
    touch ${MOUNT_POINT}/overlay/replacedir/replace2.txt

    echo "Generated test data in upper layer."

    # generate a overlay file listing as seen by the operating system
    sudo ls -alRt ${MOUNT_POINT}/overlay > ${SPECIMENS_PATH}/overlay.txt;
    sudo ls -alRt ${MOUNT_POINT}/lower > ${SPECIMENS_PATH}/lower.txt;
    sudo ls -alRt ${MOUNT_POINT}/upper/upper > ${SPECIMENS_PATH}/upper.txt;
    sudo ls -alRt ${MOUNT_POINT}/upper/workdir > ${SPECIMENS_PATH}/workdir.txt;

    umount_overlay
}


# Check that the binaries used in this test exist
assert_availability_binary dd;
assert_availability_binary mkfs.ext4;
assert_availability_binary mount;

set -e;

SPECIMENS_PATH="specimens/overlayfs";
MOUNT_POINT="tmp";

mkdir -p ${SPECIMENS_PATH};

create_test_overlay_files ${SPECIMENS_PATH}/overlay 10485760 512
