#!/bin/bash
#
# YongCao(ycao18)     Jignesh     Richard
#
# [INFO] [DEBUG] [ERROR]
#

METHOD="dd"
DIRECTORY=''
MOUNT_DIR=''
VOLUME_ID=''
INSTANCE=''
KEY_PAIR_NAME=''
SECURITY_GROUP_NAME=''
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
trap ctrl_c INT

ctrl_c () {
    if [[ $KEY_PAIR_NAME != '' ]]; then
        ec2-delete-keypair $KEY_PAIRNAME
    fi

    if [[ $SECURITY_GROUP_NAME != '' ]]; then
        aws ec2 delete-security-group --group-name \
            $SECURITY_GROUP_NAME
    fi

    exit 0
}

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
            VOLUME_ID=$OPTARG
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

#
# transfer K, M to G
#
DIR_SIZE="$(du -sh ${DIRECTORY} | awk '{print $1}')"

if [[ $DIR_SIZE = *K ]]; then
    DIR_SIZE=$(echo ${DIR_SIZE} | tr -cd "[0-9].")

    DIR_SIZE=$(echo $DIR_SIZE '/' 1024 | bc -l)
    DIR_SIZE=$(echo $DIR_SIZE '/' 1024 | bc -l)
elif [[ $DIR_SIZE = *M ]]; then
    DIR_SIZE=$(echo ${DIR_SIZE} | tr -cd "[0-9].")
    DIR_SIZE=$(echo $DIR_SIZE '/' 2014 | bc -l)

elif [[ $DIR_SIZE = *G ]]; then
    DIR_SIZE="$(echo ${DIR_SIZE} | tr -cd "[0-9].")"

fi

create_volume () {
    VOLUME_SIZE=$(echo $DIR_SIZE '*' 2 | bc -l)

    if [ 1 -eq `echo "$VOLUME_SIZE < 1" | bc` ]; then
        VOLUME_SIZE="1"
    else
        VOLUME_SIZE=${VOLUME_SIZE.*}
        VOLUME_SIZE=$(expr $VOLUME + 1)
    fi
    echo $AVAILABILITY_ZONE
    VOLUME_ID=$(aws ec2 create-volume --size $VOLUME_SIZE \
        --availability-zone $AVAILABILITY_ZONE --volume-type \
        gp2 --output text | awk '{print $7}')

    if [[ "$VOLUME_ID" = "" ]]; then
        echo "Failed to create volume"
        exit 1;
    fi

    if [[ $EC2_BACKUP_VERBOSE != ""  ]]; then
        echo "volume "$VOLUME_ID" was created"
    fi
}
####################################
#
#if -v is indicated, check the size of volume
#Create instance and attach volume, mount disk
#
#Created by Richard
#
check_volume () {

    VOLUME_SIZE=$(aws ec2 describe-volumes --volume-ids $VOLUME_ID \
        --query 'Volumes[*].[Size]' --output text)


    if [ $VOLUME_SIZE -ge `expr $DIR_SIZE \* 2` ];then

        AVAILABILITY_ZONE=$(aws ec2 describe-volumes --volume-ids \
            $VOLUME_ID --query 'Volumes[*].[AvailabilityZone]' \
            --output text)

    else
        exit 1
    fi
}


#
# create instance
#
IMAGE_IDs=(
'ami-fce3c696' 'ami-06116566'
'ami-9abea4fb' 'ami-f95ef58a'
'ami-87564feb' 'ami-a21529cc'
'ami-09dc1267' 'ami-25c00c46'
'ami-6c14310f' 'ami-0fb83963'
)

if [[ $REGION = "us-east-1" ]]; then
    IMAGE_ID=${IMAGE_IDs[0]}
elif [[ $REGION = "us-west-1" ]]; then
    IMAGE_ID=${IMAGE_IDs[1]}
elif [[ $REGION = "us-west-2" ]]; then
    IMAGE_ID=${IMAGE_IDs[2]}
elif [[ $REGION = "eu-west-1" ]]; then
    IMAGE_ID=${IMAGE_IDs[3]}
elif [[ $REGION = "eu-central-1" ]]; then
    IMAGE_ID=${IMAGE_IDs[4]}
elif [[ $REGION = "ap-northeast-1" ]]; then
    IMAGE_ID=${IMAGE_IDs[5]}
elif [[ $REGION = "ap-northeast-2" ]]; then
    IMAGE_ID=${IMAGE_IDs[6]}
elif [[ $REGION = "ap-southeast-1" ]]; then
    IMAGE_ID=${IMAGE_IDs[7]}
elif [[ $REGION = "ap-southeast-2" ]]; then
    IMAGE_ID=${IMAGE_IDs[8]}
else
    IMAGE_ID=${IMAGE_IDs[9]}
fi

KEY_PAIR_NAME="ec2_backup_KP"`date +%F_%T`
aws ec2 create-key-pair --key-name $KEY_PAIR_NAME --query 'KeyMaterial' --output text > $HOME/ec2_backup_KP.pem

chmod 700 $HOME/ec2_backup_KP.pem

SECURITY_GROUP_NAME="ec2_backup_security_group"`date +%F_%T`

if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
    aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME \
        --description "ec2_backup_security_group"
else
    aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME \
        --description "ec2_backup_security_group" &>/dev/null
fi

if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
    aws ec2 authorize-security-group-ingress --group-name \
        $SECURITY_GROUP_NAME --port 22 --protocol tcp --cidr 0.0.0.0/0
else
    aws ec2 authorize-security-group-ingress --group-name \
        $SECURITY_GROUP_NAME --port 22 --protocol tcp --cidr 0.0.0.0/0 &>/dev/null
fi

echo "ID="$IMAGE_ID
if [[ $EC2_BACKUP_FLAGS_AWS != "" ]]; then
    INSTANCE=$(aws ec2 run-instances --image-id $IMAGE_ID \
        $EC2_BACKUP_FLAGS_AWS --key-name $KEY_PAIR_NAME --security-groups \
        $SECURITY_GROUP_NAME --output text --query \
        'Instances[*].InstanceId')
else
    INSTANCE=$(aws ec2 run-instances --image-id $IMAGE_ID \
        $BACKUP_FLAG --key-name $KEY_PAIR_NAME \
        --security-groups $SECURITY_GROUP_NAME --output \
        text --query 'Instances[*].InstanceId')
fi

AVAILABILITY_ZONE=$(aws ec2 describe-instances --instance-ids $INSTANCE \
    --output text --query 'Reservations[*].Instances[*].Placement[*].AvailabilityZone')

if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
    echo "Instance "$INSTANCE" was created"
fi

echo hi
if [[ $VOLUME != "" ]]; then
    check_volume
else
    create_volume
fi


EC2_HOST=$(aws ec2 describe-instances --instance-ids $INSTANCE \
    --output text --query 'Reservations[*].Instances[*].NetworkInterfaces.Association.PublicIp')

echo $EC2_HOST

while [ 1 ]; do
    STATUE=$(aws ec2 describe-instances --instance-ids $INSTANCE \
        --output text --query 'Reservations[*].Instances[*].State[*].Name')
    echo $STATUE
    if [[ $STATUE = "running" ]]; then
        break
    fi
    sleep 1
done

aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE \
    --device /dev/xvdf

if [[ $EC2_BACKUP_FLAGS_SSH = "" ]]; then
    EC2_BACKUP_FLAGS_SSH="-i $HOME/ec2_backup_KP.pem"
fi

MOUNT_DIR='/home/ubuntu/mount_point'

echo "ssh $EC2_BACKUP_FLAGS_SSH -o StrictHostKeyChecking=no -v ubuntu@$EC2_HOST "sudo mkfs -t ext4 /dev/xvdf""

# do while because ssh command may rejected
while [ 1 ]; do
    ssh $EC2_BACKUP_FLAGS_SSH -o StrictHostKeyChecking=no -v ubuntu@$EC2_HOST \
        "sudo mkfs -t ext4 /dev/xvdf"

    if [ $? -eq 0 ]; then
        break
    fi
    sleep 1
done

ssh $EC2_BACKUP_FLAGS_SSH -o StrictHostKeyChecking=no -v ubuntu@$EC2_HOST \
    "sudo mkdir $MOUNT_DIR"

ssh $EC2_BACKUP_FLAGS_SSH -o StrictHostKeyChecking=no -v ubuntu@$EC2_HOST \
    "sudo mount /dev/xvdf $MOUNT_DIR"

ssh $EC2_BACKUP_FLAGS_SSH -o StrictHostKeyChecking=no -v ubuntu@$EC2_HOST \
    "sudo chown ubuntu $MOUNT_DIR"
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
            tar cf - $DIRECTORY | ssh -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH \
                ubuntu@$EC2_HOST dd of=$MOUNT_DIR/$DATE obs=512k
        else
            tar cf - $DIRECTORY | ssh -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH \
                ubuntu@$EC2_HOST dd of=$MOUNT_DIR/$DATE obs=512k &>/dev/null
        fi
    fi

    if [[ $METHOD = "rsync" ]]; then

        if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
            rsync -aRc -e "ssh -o StrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH" $DIRECTORY ubuntu@$EC2_HOST:$MOUNT_DIR
        else
            rsync -aRc -e "ssh -o StrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH" $DIRECTORY ubuntu@$EC2_HOST:$MOUNT_DIR &>/dev/null
        fi
    fi

    ###

    ssh -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH ubuntu@$EC2_HOST sudo umount $MOUNT_DIR

    aws ec2 detach-volume --volume-id $VOLUME_ID

}

backup
#
# backup work finished, print volume-id
#

echo $VOLUME_ID

#
# terminal instance
#
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --group-name $SECURITY_GROUP_NAME --query 'SecurityGroups[*].GroupId' --output text)

if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
    aws ec2 terminate-instances --instance-ids $INSTANCE
    aws ec2 delete-key-pair --key-name $KEY_PAIR_NAME
    while [ 1 ]; do
        aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID &>/dev/null
        if [ $? -eq 0 ]; then
            break;
        fi
        sleep 10
    done
else
    aws ec2 terminate-instances --instance-ids $INSTANCE &>/dev/null
    aws ec2 delete-key-pair --key-name $KEY_PAIR_NAME &>/dev/null
    while [ 1 ]; do
        aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID &>/dev/null
        if [ $? -eq 0 ]; then
            break;
        fi
        sleep 10
    done
fi

exit 0
