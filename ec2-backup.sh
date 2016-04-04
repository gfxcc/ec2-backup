#!/bin/sh
#
# YongCao     Jignesh     Richard
#
# [INFO] [DEBUG] [ERROR]
#

METHOD="dd"
DIRECTORY=''
MOUNT_DIR=''
EC2_BACKUP_VOLUME=''
EC2_BACKUP_INSTANCE=''




#####################################














######################################
#
# execute backup dd/rsync
#

if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
    echo "[INFO] Start backup process"
fi

if [[ $METHOD = "dd" ]]; then
    DATE=`date +%F/%T`
    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        tar cvf $DIRECTORY | ssh $EC2_BACKUP_FLAGS_SSH \
            ubuntu@$EC2_HOST dd of=$MOUNT_DIR/$DATE obs=512k
    else
        tar cf $DIRECTORY &>/dev/null | ssh $EC2_BACKUP_FLAGS_SSH \
            ubuntu@$EC2_HOST dd of=$MOUNT_DIR/$DATE obs=512k &>/dev/null
    fi
fi

if [[ $METHOD = "rsync" ]]; then

    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        rsync -avRc -e "ssh $EC2_BACKUP_FLAGS_SSH" $DIRECTORY ubuntu\
            @$EC2_HOST:$MOUNT_DIR
    else
        rsync -aRc -e "ssh $EC2_BACKUP_FLAGS_SSH" $DIRECTORY ubuntu\
            @$EC2_HOST:$MOUNT_DIR &>/dev/null
    fi
fi

###

ssh $EC2_BACKUP_FLAGS_SSH ubuntu@$EC2_HOST sudo umount $MOUNT_DIR

ec2-detach-volume $EC2_BACKUP_VOLUME -i $EC2_BACKUP_INSTANCE

#
# terminal instance
#


