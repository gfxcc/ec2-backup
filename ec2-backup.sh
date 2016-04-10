#!/bin/bash
#
# YongCao(ycao18)     Jignesh     Richard
#
# [INFO] [DEBUG] [ERROR]
#

METHOD="dd"
DIRECTORY=''
MOUNT_DIR=''
VOLUME=''
INSTANCE=''
REGION=$(cat ~/.aws/config | grep "region" | sed 's/region = //g')
AVAILABILITY_ZONE=''
IMAGE_ID=''
VOLUME_SIZE=''
DIR_SIZE=''
EC2_HOST=''
VISINDICATED=''
BACKUP_FLAG='--instance-type t2.micro'

#######################################
#
# Created by Jignesh
#

usage() {
    echo "usage: ec2-backup [-h] [-m method] [-v volume-id] dir"
    echo "	-m valid methods are 'dd' and 'rsync'; default is 'dd'"
    echo "	-v use given volume instead of creating a new one"
    echo "	ENVIRONMENT	EC2_BACKUP_VERBOSE	enable verbose mode"
    echo "			EC2_BACKUP_FLAGS_AWS	add custom flags for instanace"
    echo "			EC2_BACKUP_FLAGS_SSH	indicate ssh file"
    exit 0
}

while getopts 'hm:v:' opt; do
    case ${opt} in
        h)
            usage
            ;;
        m)
            METHOD=$OPTARG
            ;;
        v)
            VOLUME=$OPTARG
            ;;
    esac
done

# get last argument
#
for last; do true; done
DIRECTORY=$last

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

if [ -n "$METHOD" -a "$METHOD" != "dd" -a "$METHOD" != "rsync" ]; then
    echo "${0}: Valid methods are 'dd' and 'rsync'; default is 'dd'."
    exit 1
fi

if [ -z $DIRECTORY ]; then
    echo "${0}: No directory specified"
    exit 1
fi

if [ ! -d "$DIRECTORY" ]; then
    echo "${0}: ${DIRECTORY} No such directory"
    exit 1
fi


create_volume () {

    exit 0
}
####################################
#
#if -v is indicated, check the size of volume
#Create instance and attach volume, mount disk
#
#Created by Richard
#

check_volume () {

    VOLUME_SIZE=$(aws ec2 describe-volumes --volume-ids $VOLUME --query \
        'Volumes[*].[Size]' --output text)


    if [ $VOLUME_SIZE -ge `expr $DIR_SIZE \* 2` ];then

        AVAILABILITY_ZONE=$(aws ec2 describe-volumes --volume-ids \
            $VOLUME --query 'Volumes[*].[AvailabilityZone]' \
            --output text)

    else
        exit 1
    fi
}

if [[ $VOLUME != "" ]]; then
    check_volume
else
    create_volume
fi

#
# create instance
#
IMAGE_ID[0]='ami-fce3c696'
IMAGE_ID[1]='ami-06116566'
IMAGE_ID[2]='ami-9abea4fb'
IMAGE_ID[3]='ami-f95ef58a'
IMAGE_ID[4]='ami-87564feb'
IMAGE_ID[5]='ami-a21529cc'
IMAGE_ID[6]='ami-09dc1267'
IMAGE_ID[7]='ami-25c00c46'
IMAGE_ID[8]='ami-6c14310f'
IMAGE_ID[9]='ami-0fb83963'

if [[ $REGION = "us-east-1" ]]; then
    IMAGE_ID=IMAGE_ID[0]
elif [[ $REGION = "us-west-1" ]]; then
    IMAGE_ID=IMAGE_ID[1]
elif [[ $REGION = "us-west-2" ]]; then
    IMAGE_ID=IMAGE_ID[2]
elif [[ $REGION = "eu-west-1" ]]; then
    IMAGE_ID=IMAGE_ID[3]
elif [[ $REGION = "eu-central-1" ]]; then
    IMAGE_ID=IMAGE_ID[4]
elif [[ $REGION = "ap-northeast-1" ]]; then
    IMAGE_ID=IMAGE_ID[5]
elif [[ $REGION = "ap-northeast-2" ]]; then
    IMAGE_ID=IMAGE_ID[6]
elif [[ $REGION = "ap-southeast-1" ]]; then
    IMAGE_ID=IMAGE_ID[7]
elif [[ $REGION = "ap-southeast-2" ]]; then
    IMAGE_ID=IMAGE_ID[8]
else [[ $REGION = "sa-east-1" ]]; then
    IMAGE_ID=IMAGE_ID[9]
fi

if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
    aws ec2 create-key-pair --key-name ec2_backup_KP
else
    aws ec2 create-key-pair --key-name ec2_backup_KP &>/dev/null
fi

if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
    aws ec2 create-security-group --group-name ec2_backup_SG
else
    aws ec2 create_security-group --group-name ec2_backup_SG &>/dev/null
fi

if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
    aws ec2 authorize-security-group-ingress --group-name \
        ec2_backup_SG --port 22 --protocol tcp --cidr 0.0.0.0/0
else
    aws ec2 authorize-security-group-ingress --group-name \
        ec2_backup_SG --port 22 --protocol tcp --cidr 0.0.0.0/0 &>/dev/null
fi


if [[ $EC2_BACKUP_FLAGS_AWS != "" ]]; then
    INSTANCE=$(aws ec2 run-instances --image-id $IMAGE_ID \
        $BACKUP_FLAG --key-name ec2_backup_KP --security-groups \
        ec2_backup_SG --availability-zone $AVAILABILITY_ZONE \
        --output text --query 'Instances[*].InstanceId')
else
    INSTANCE=$(aws ec2 run-instances --image-id $IMAGE_ID \
        $EC2_BACKUP_FLAGS_AWS --key-name ec2_backup_KP \
        --security-groups ec2_backup_SG --availability-zone \
        $AVAILABILITY_ZONE --output text --query \
        'Instances[*].InstanceId')
fi

if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
    echo "Instance "$INSTANCE" was created"
fi

EC2_HOST=$(aws ec2 describe-instances --instance-ids $INSTANCE \
    --output text --query 'Reservations[*].Instances[*].\
    NetworkInterfaces.Association.PublicIp')


aws ec2 attach-volume --volume-id $VOLUME --instance-id $INSTANCE \
    --device /dev/xvdf

ssh $EC2_BACKUP_FLAGS_SSH ubuntu@$EC2_HOST sudo mkfs -t ext4 /dev/xvdf

MOUNT_DIR='~/MOUNT'

ssh $EC2_BACKUP_FLAGS_SSH ubuntu@$EC2_HOST sudo mount /dev/xvdf MOUNT_DIR


######################################
#
# created by YongCao (ycao18)
# execute backup dd/rsync
# trap CTRL-C signal
backup () {

    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[INFO] Start backup process"
    fi

    if [[ $METHOD = "dd" ]]; then
        DATE=`date +%F_%T`
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

    ec2-detach-volume $VOLUME -i $INSTANCE

}

trap backup 2
#
# backup work finished, print volume-id
#

echo $VOLUME

#
# terminal instance
#
if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
    ec2-stop-instances $INSTANCE
else
    ec2-stop-instances $INSTANCE &>/dev/null
fi


exit 0
