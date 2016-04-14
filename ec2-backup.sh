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
GIVEN_VOLUME_MODE=''
GIVEN_KEY_PAIR=''

clean () {
    echo "[ok]	clean process"
    if [[ $INSTANCE != "" ]]; then
        aws ec2 terminate-instances --instance-ids $INSTANCE &>/dev/null
        if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
            echo "[run]	terminate instance"
        fi

        limite=0
        while [ 1 ]; do
            if [ $limite -gt 50 ]; then
                echo "[error] fail to terminate instance, pleace check network"
                clean 1
                exit 1
            fi
            STATUS=$(aws ec2 describe-instances --instance-ids $INSTANCE \
                --output text --query 'Reservations[*].Instances[*].[State.Name]')
            if [[ $STATUS = "terminated" ]]; then
                if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
                    echo "[ok]	instance has terminated"
                fi
                break
            fi
            limite=`expr $limite + 1`

            if [ $(($limite%2)) -eq 0 ]; then
                echo -ne "-\r"
            else
                echo -ne "|\r"
            fi

            sleep 1
        done

    fi

    if [[ $GIVEN_KEY_PAIR = "" ]]; then
        aws ec2 delete-key-pair --key-name $KEY_PAIR_NAME &>/dev/null
        rm $HOME/$KEY_PAIR_NAME
        if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
            echo "[ok]	delete key-pair"
        fi
    fi

    if [[ $SECURITY_GROUP_NAME != "" ]]; then
        SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --group-name \
            $SECURITY_GROUP_NAME --query 'SecurityGroups[*].GroupId' --output text) &>/dev/null

        if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
            echo "[ok]	delete security group"
        fi
    fi

    if [ $1 -ne 0 ]; then
        if [[ $GIVEN_VOLUME_MODE = "" ]]; then
            if [[ $VOLUME_ID != "" ]]; then
                aws ec2 delete-volume --volume-id $VOLUME_ID &>/dev/null
                echo "[ok]	delete volume $VOLUME_ID"
            fi
        fi
    fi
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

create_volume () {
    VOLUME_SIZE=$(echo $DIR_SIZE '*' 2 | bc -l)

    if [ 1 -eq `echo "$VOLUME_SIZE < 1" | bc` ]; then
        VOLUME_SIZE="1"
    else
        VOLUME_SIZE=${VOLUME_SIZE.*}
        VOLUME_SIZE=$(expr $VOLUME + 1)
    fi
    VOLUME_ID=$(aws ec2 create-volume --size $VOLUME_SIZE \
        --availability-zone $AVAILABILITY_ZONE --volume-type \
        gp2 --output text | awk '{print $7}')

    if [[ "$VOLUME_ID" = "" ]]; then
        echo "[error]	failed to create volume"
        clean 1
        exit 1;
    fi

    if [[ $EC2_BACKUP_VERBOSE != ""  ]]; then
        echo "[ok]	volume $VOLUME_ID was created"
    fi
}

check_volume () {
    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[run]	check volume"
    fi

    aws ec2 detach-volume --volume-id $VOLUME_ID &>/dev/null

    VOLUME_SIZE=$(aws ec2 describe-volumes --volume-ids $VOLUME_ID \
        --query 'Volumes[*].[Size]' --output text &>/dev/null)

    if [[ $VOLUME_SIZE = "" ]]; then
        echo "[error]	invalid volume-id"
        clean 1
        exit 1
    fi

    if [ 1 -eq `echo "$VOLUME_SIZE > ($DIR_SIZE * 2)" | bc` ]; then

        AVAILABILITY_ZONE=$(aws ec2 describe-volumes --volume-ids \
            $VOLUME_ID --query 'Volumes[*].[AvailabilityZone]' \
            --output text) &>/dev/null
    else
        echo "[error]	it require larger volume"
        clean 1
        exit 1
    fi

    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[ok]	volume is valid"
    fi

}

check_argument () {
    for last; do true; done
    DIRECTORY=$last

    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    if [ -n "$METHOD" -a "$METHOD" != "dd" -a "$METHOD" != "rsync" ]; then
        echo "${0}: Valid methods are 'dd' and 'rsync'; default is 'dd'."
        usage
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

    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[ok]	argument check"
    fi
}
#
# t

transfer_size () {
    # get last argument
    #
    #ransfer K, M to G
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

    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[ok]	backup directory $DIRECTORY $DIR_SIZE GB"
    fi


}




create_instance () {
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

    if [[ $EC2_BACKUP_FLAGS_SSH = "" ]]; then
        KEY_PAIR_NAME="ec2_backup_KP"`date +%F_%T`
        aws ec2 create-key-pair --key-name $KEY_PAIR_NAME --query 'KeyMaterial' \
            --output text > $HOME/$KEY_PAIR_NAME

        if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
            echo "[ok]	key-pair $KEY_PAIR_NAME was created"
        fi
        EC2_BACKUP_FLAGS_SSH="-i $HOME/$KEY_PAIR_NAME"
    else
        GIVEN_KEY_PAIR="YES"
        KEY_PAIR_NAME=$(awk '{print $2}' <<< $EC2_BACKUP_FLAGS_SSH)
        KEY_PAIR_NAME=$(basename "$KEY_PAIR_NAME")
    fi

    chmod 700 $HOME/$KEY_PAIR_NAME

    SECURITY_GROUP_NAME="ec2_backup_security_group"`date +%F_%T`

    aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME \
        --description "ec2_backup_security_group" &>/dev/null
    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[ok]	security group $SECURITY_GROUP_NAME was created"
    fi

    aws ec2 authorize-security-group-ingress --group-name \
        $SECURITY_GROUP_NAME --port 22 --protocol tcp --cidr 0.0.0.0/0 &>/dev/null
    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[ok]	enable port 22"
    fi

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

    if [[ $? -ne 0 ]]; then
        echo "[ERROR]	failed to create instance"
        clean 1
        exit 1
    fi

    AVAILABILITY_ZONE=$(aws ec2 describe-instances --instance-ids $INSTANCE \
        --output text --query 'Reservations[*].Instances[*].[Placement.AvailabilityZone]')


    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[ok]	instance $INSTANCE was created"
    fi
}

ssh_process () {
    EC2_HOST=$(aws ec2 describe-instances --instance-ids $INSTANCE \
        --output text --query 'Reservations[*].Instances[*].NetworkInterfaces[*].
    [Association.PublicIp]')

    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[run]	waiting for instance, it might takes 20 seconds"
    fi

    limite=0
    while [ 1 ]; do
        if [ $limite -gt 50 ]; then
            echo "[error] fail to ssh 50 times, please check key-pair, network"
            clean 1
            exit 1
        fi
        STATUE=$(aws ec2 describe-instances --instance-ids $INSTANCE \
            --output text --query 'Reservations[*].Instances[*].[State.Name]')
        if [[ $STATUE = "running" ]]; then
            if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
                echo "[ok]	instance is running"
            fi
            break
        fi
        limite=`expr $limite + 1`

        if [ $(($limite%2)) -eq 0 ]; then
            echo -ne "-\r"
        else
            echo -ne "|\r"
        fi

        sleep 1
    done

    aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE \
        --device /dev/xvdf &>/dev/null
    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[ok]	volume $VOLUME_ID has been attached on instance $INSTANCE"
    fi

    MOUNT_DIR='/home/ubuntu/mount_point'

    # do while because ssh command may rejected
    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[run]	waiting for first time ssh to instance, it might takes 20 seconds"
    fi

    while [ 1 ]; do
        ssh $EC2_BACKUP_FLAGS_SSH -o StrictHostKeyChecking=no -v ubuntu@$EC2_HOST \
            "sudo mkfs -t ext4 /dev/xvdf" &>/dev/null

        if [ $? -eq 0 ]; then
            if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
                echo "[ok]	file system has been created on volume"
            fi
            break
        fi
        sleep 1
    done

    ssh $EC2_BACKUP_FLAGS_SSH -o StrictHostKeyChecking=no -v ubuntu@$EC2_HOST \
        "sudo mkdir $MOUNT_DIR" &>/dev/null

    ssh $EC2_BACKUP_FLAGS_SSH -o StrictHostKeyChecking=no -v ubuntu@$EC2_HOST \
        "sudo mount /dev/xvdf $MOUNT_DIR" &>/dev/null

    ssh $EC2_BACKUP_FLAGS_SSH -o StrictHostKeyChecking=no -v ubuntu@$EC2_HOST \
        "sudo chown ubuntu $MOUNT_DIR" &>/dev/null
}
######################################
#
#
# execute backup dd/rsync

backup_process () {
    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[ok]	start backup process, use $METHOD"
    fi

    if [[ $METHOD = "dd" ]]; then
        DATE=`date +%F_%T`
        tar cf - $DIRECTORY | ssh -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH \
            ubuntu@$EC2_HOST dd of=$MOUNT_DIR/$DATE obs=512k &>/dev/null
        if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
            echo "[ok]	dd finished"
        fi
    fi

    if [[ $METHOD = "rsync" ]]; then
        rsync -aRc -e "ssh -o StrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH" \
            $DIRECTORY ubuntu@$EC2_HOST:$MOUNT_DIR &>/dev/null
        if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
            echo "[ok]	rsync finished"
        fi
    fi

    ssh -oStrictHostKeyChecking=no $EC2_BACKUP_FLAGS_SSH ubuntu@$EC2_HOST \
        sudo umount $MOUNT_DIR &>/dev/null

    aws ec2 detach-volume --volume-id $VOLUME_ID &>/dev/null

    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[ok]	volume has been detached"
    fi

    #
    # backup work finished, print volume-id
    #

    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[ok]	---------volume-id $VOLUME_ID -------------"
    else
        echo $VOLUME_ID
    fi
}

trap ctrl_c INT

ctrl_c () {
    clean 130
    exit 130
}


ec2_backup_main_process () {

    while getopts 'hm:v:V' opt; do
        case ${opt} in
            h)
                usage
                ;;
            m)
                METHOD=$OPTARG
                ;;
            v)
                GIVEN_VOLUME_MODE="YES"
                VOLUME_ID=$OPTARG
                ;;
            V)
                EC2_BACKUP_VERBOSE="YES"
        esac
    done

    check_argument $@

    transfer_size

    create_instance

    if [[ $VOLUME_ID != "" ]]; then
        check_volume
    else
        create_volume
    fi

    ssh_process

    backup_process

    clean 0
    if [[ $EC2_BACKUP_VERBOSE != "" ]]; then
        echo "[successed]	volume-id:$VOLUME_ID"
    fi

    exit 0

}


ec2_backup_main_process $@


