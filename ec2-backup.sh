#!/bin/sh
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
BACKUP_FLAG='--count 1 --instance-type t2.micro'

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

if [[ -n "$METHOD" -a "$METHOD" != "dd" -a "$METHOD" != "rsync" ]]; then
    echo "${0}: Valid methods are 'dd' and 'rsync'; default is 'dd'."
    exit 1
fi

if [ -z $DIR ]; then
    echo "${0}: No directory specified"
    exit 1
fi

if [ ! -d "$DIRECTORY" ]; then
    echo "${0}: ${DIRECTORY} No such directory" 	
    exit 1
fi

####################################
#
#if -v is indicated, check the size of volume
#Create instance and attach volume, mount disk
#
#Created by Richard
#

function CheckVolumeSize {

VOLUME_SIZE=$(aws ec2 describe-volumes --volume-ids $VOLUME --query \
    'Volumes[*].[Size]' --output text)

if [ $VOLUME_SIZE -ge `expr $DIR_SIZE \\* 2` ];then

    AVAILABILITY_ZONE=$(aws ec2 describe-volumes --volume-ids \
        $VOLUME --query 'Volumes[*].[AvailabilityZone]' \
        --output text)

else
    exit 1
fi
}

function CreateInstance{

INSTANCEID=('ami-fce3c696' 'ami-06116566'\
    'ami-9abea4fb' 'ami-f95ef58a'\
    'ami-87564feb' 'ami-a21529cc'\
    'ami-09dc1267' 'ami-25c00c46'\
    'ami-6c14310f' 'ami-0fb83963')

aws ec2 create-key-pair --key-name CS615KEY

aws ec2 create-security-group --group-name MY-SG 

aws ec2 authorize-security-group-ingress --group-name MY-SG --port 22 \
    --protocol tcp --cidr 0.0.0.0/0

if [[ $EC2_BACKUP_FLAGS_AWS != "" ]]; then
    INSTANCE=$(aws ec2 run-instances --image-id $IMAGE_ID --count 1 \
        $BACKUP_FLAG --key-name CS615KEY --security-groups MY-SG \
        --availability-zone $AVAILABILITY_ZONE  --output text --query\
        'Instances[*].InstanceId')
fi
else
    INSTANCE=$(aws ec2 run-instances --image-id $IMAGE_ID $BACKUP_FLAG \
        --key-name CS615KEY --security-groups MY-SG --availability-zone\
        $AVAILABILITY_ZONE --output text --query 'Instances[*].InstanceId')
fi

EC2_HOST=$(aws ec2 describe-instances --instance-ids $INSTANCE --query \
    'Reservations[*].Instances[*].NetworkInterfaces.Association.\
    PublicIp' --output text)
}

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
function backup {

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
