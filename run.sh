#!/bin/bash

BANNER=$(cat << "EOF"
-----------------------------------------------------------------------
   _____  .___                .__   _____   .___      .__              
  /  _  \ |   |   ______ ____ |  |_/ ____\__| _/______|__|__  __ ____  
 /  /_\  \|   |  /  ___// __ \|  |\   __\/ __ |\_  __ \  \  \/ // __ \ 
/    |    \   |  \___ \ \ ___/|  |_|  | / /_/ | |  | \/  |\   / \ ___/ 
\____|__  /___| /____  > \___ >____/__| \____ | |__|  |__| \_/   \___ >
        \/           \/     \/               \/                     \/ 
                                    
----------------------------------------------------- 2023.12.26 ------
        AI selfdrive Script by: @ChenWeiFu , reference from @SeanChangX
-----------------------------------------------------------------------
EOF
)
echo -e "\n$BANNER\n"

SELECTED_PATH=$(realpath "$(pwd)")
USER_UID=$(id -u)
USER_GID=$(id -g)
IMAGE_NAME="wtarvasm533/ai-selfdrive"
echo "SELECTED_PATH:   $SELECTED_PATH"

# Detect user's os if not linux then exit
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
	echo -e "\e[31mThis script is only for linux"
	exit 1
fi

# Detect user's ubuntu version
LINUX_VERSION=$(lsb_release -d | grep -o 'Ubuntu.*')
echo -e "LINUX_VERSION:   $LINUX_VERSION\n"

# Check if docker is installed
if ! [ -x "$(command -v docker)" ]; then
	echo "Docker is not installed. Installing..."
	# install docker
	sudo curl -fsSL https://get.docker.com | sh
	# add user to docker group
	sudo usermod -aG docker $(whoami)
fi

# Check if image is installed
if ! docker image inspect $IMAGE_NAME &>/dev/null; then
	echo "$IMAGE_NAME image is not installed."
	echo "Pulling wtarvasm533/ai-selfdrive image..."
	docker pull $IMAGE_NAME
	# echo "Building $IMAGE_NAME image..."
	# docker build -t $IMAGE_NAME .
fi

# Check if data folder exists
if ! [ -d "$SELECTED_PATH/data" ]; then
	echo -e "\e[32mCreating data folder...\e[0m"
	mkdir "$SELECTED_PATH/data"
# if exists then backup data folder
else
	echo -e "\e[32mBacking up data folder...\e[0m"
	# Check if backup folder exists
	if ! [ -d "$SELECTED_PATH/backup" ]; then
		echo -e "\e[32mCreating backup folder...\e[0m"
		mkdir "$SELECTED_PATH/backup"
	fi
	# Backup data folder
	timestamp=$(date +%Y%m%d_%H%M%S)
	tar -cvf "$SELECTED_PATH/backup/data_backup_$timestamp.tar" -P "$SELECTED_PATH/data"
	# Remove old backup files (max 5 files)
	backup_count=$(ls -l "$SELECTED_PATH/backup" | grep -c '^-' )
	if [[ "$backup_count" -gt 5 ]]; then
		echo -e "\e[32mRemoving old backup files...\e[0m"
		excess_files=$((backup_count - 5))
		find "$SELECTED_PATH/backup" -type f -print0 | xargs -0 ls -t | tail -n "$excess_files" | xargs -d '\n' rm
	fi
fi

# NETWORK_NAME="ai-net"
# # Check if the network already exists
# if ! docker network inspect $NETWORK_NAME &> /dev/null; then
#     # If the network doesn't exist, create it
#     echo -e "\e[32mCreating Docker network: $NETWORK_NAME\e[0m"
#     docker network create --driver bridge $NETWORK_NAME
# else
#     # If the network already exists, skip creation
#     echo -e "\e[32mDocker network $NETWORK_NAME already exists. Skipping creation.\e[0m"
# fi


# Check user use nvidia gpu or not	(Haven't tested yet!!!)
if [[ "$1" == "gpu" ]]; then
	echo -e "\e[32mRunning ai-selfdrive container with GPU support...\e[0m"
else
	echo -e "\e[32mRunning ai-selfdrive container...\e[0m"
	# run container
	if docker ps --filter "name=ui" --format "{{.Names}}" | grep -q "ui"; then
		CONTAINER_NAME="replay"
	else
		CONTAINER_NAME="ui"
	fi
	docker container run -it --rm --name $CONTAINER_NAME \
		--env="DISPLAY" \
		--env="QT_X11_NO_MITSHM=1" \
		--volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
		--volume="$SELECTED_PATH/data:/home/data:rw" \
		--user="$USER_UID:$USER_GID" \
		--gpus all \
		--network host \
		$IMAGE_NAME
fi
