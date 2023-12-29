FROM ubuntu:20.04

ARG USERNAME=selfdrive
ARG USERPASSWD=ubuntu
ARG SHELL=bash

LABEL org.opencontainers.image.authors="weifu"
LABEL shell="${SHELL}"

ENV DATA=/home/${USERNAME}/data
ENV USERNAME=${USERNAME}
ENV SHELL=/bin/${SHELL}
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV TERM=xterm-256color
ENV LIBGL_ALWAYS_SOFTWARE=1
ENV XDG_RUNTIME_DIR=/home/${USERNAME}

RUN apt update && \
    apt dist-upgrade -y && \
    apt install -y \
    sudo \
    vim \
    curl \
    wget \
    tmux \
    htop \
    tree \
    git \
    git-extras \
    gnupg2 \
    net-tools \
    python3 \
    python-is-python3 \
    locales \
    locales-all \
    pip && \
    apt install bash-completion -y

RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends tzdata
RUN TZ=Asia/Taipei && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

RUN useradd -ms /bin/${SHELL} ${USERNAME} && \
    sudo adduser ${USERNAME} sudo && \
    echo "${USERNAME}:${USERPASSWD}" | chpasswd && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers

USER ${USERNAME}
WORKDIR /home/${USERNAME}

COPY custom-config /home/${USERNAME}/.custom-config
RUN echo '\n# AI selfdrive Environment Configuration' >> /home/${USERNAME}/.bashrc && \
    sed -n '/# AI sel/,/# / p' .custom-config | grep -v '#' >> /home/${USERNAME}/.bashrc

RUN sudo apt-get update && \
    sudo apt-get install -y \
    python3-dev

RUN curl -sSL https://install.python-poetry.org | python3 -
RUN echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc

RUN git clone -b v0.9.1 https://github.com/commaai/openpilot

RUN git clone https://github.com/wkentaro/gdown.git
WORKDIR /home/${USERNAME}/gdown
RUN pip install gdown
WORKDIR /home/${USERNAME}
RUN rm -rf gdown

WORKDIR /home/${USERNAME}/openpilot

RUN git submodule update --init
RUN rm -rf tools
RUN sudo apt-get install -y curl unzip
RUN wget --load-cookies /tmp/cookies.txt \
    "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies \
    /tmp/cookies.txt --keep-session-cookies --no-check-certificate \
    'https://docs.google.com/uc?export=download&id=1Gd3kd7XP11nZhrnxWBaWcgmaD7Awm1C4' \
    -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1Gd3kd7XP11nZhrnxWBaWcgmaD7Awm1C4" \
    -O tools.zip && rm -rf /tmp/cookies.txt
RUN unzip tools.zip && \
    rm tools.zip
RUN wget --load-cookies /tmp/cookies.txt \
    "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies \
    /tmp/cookies.txt --keep-session-cookies --no-check-certificate \
    'https://docs.google.com/uc?export=download&id=1T41BOQRpZyYgjxgqCSsvll59DnCBnnVd' \
    -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1T41BOQRpZyYgjxgqCSsvll59DnCBnnVd" \
    -O pyproject.toml && rm -rf /tmp/cookies.txt
RUN wget --load-cookies /tmp/cookies.txt \
    "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies \
    /tmp/cookies.txt --keep-session-cookies --no-check-certificate \
    'https://docs.google.com/uc?export=download&id=1G2j7X_7Ynaz0pQv404ARmNN_eLyX_SFe' \
    -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1G2j7X_7Ynaz0pQv404ARmNN_eLyX_SFe" \
    -O update_requirements.sh && rm -rf /tmp/cookies.txt
RUN chmod +rwx update_requirements.sh

WORKDIR /home/${USERNAME}
RUN sudo apt-get install python3.8-venv
RUN python3 -m venv ~/sconsvenv

# clean up
RUN sudo apt autoremove -y && \
    sudo apt clean -y && \
    sudo rm -rf /var/lib/apt/lists/*


WORKDIR /home/${USERNAME}/openpilot
RUN . ~/sconsvenv/bin/activate && \
    tools/ubuntu_setup.sh; exit 0
RUN . ~/sconsvenv/bin/activate && \
    pip install scons==4.4.0

COPY requirements.txt /home/${USERNAME}/requirements.txt
WORKDIR /home/${USERNAME}
RUN . ~/sconsvenv/bin/activate && \
    pip3 install -r requirements.txt

WORKDIR /home/${USERNAME}/openpilot
RUN . ~/sconsvenv/bin/activate && \
    scons -i
RUN . ~/sconsvenv/bin/activate && \
    pip install --upgrade pip && \
    pip install --upgrade setuptools

WORKDIR /home/${USERNAME}
COPY requirements1.txt /home/${USERNAME}/requirements1.txt
RUN . ~/sconsvenv/bin/activate && \
    pip3 install -r requirements1.txt

WORKDIR /home/${USERNAME}/openpilot
RUN sed -i '422s/^/#/' SConstruct && \
    sed -i '423s/^/#/' SConstruct && \
    sed -i '432s/^/#/' SConstruct && \
    sed -i '439s/^/#/' SConstruct
RUN . ~/sconsvenv/bin/activate && \
    scons -u -j$(nproc)
RUN sed -i '422s/^#//' SConstruct && \
    sed -i '423s/^#//' SConstruct && \
    sed -i '432s/^#//' SConstruct 
RUN . ~/sconsvenv/bin/activate && \
    pip install future-fstrings && \
    scons -u -j$(nproc)

RUN echo 'export PYTHONPATH=/home/${USERNAME}/openpilot' >> /home/${USERNAME}/.bashrc && \
    /bin/bash -c "source /home/${USERNAME}/.bashrc"

# WORKDIR /home/${USERNAME}
COPY .tmux.conf /home/${USERNAME}/.tmux.conf
COPY tmux.sh /home/${USERNAME}/openpilot/tmux.sh
RUN sudo chmod +x tmux.sh
# RUN ./tmux.sh
# RUN tmux new-session -d -s ai-seldri
# RUN tmux split-window -v -p 80 -t ai-seldri:1
# RUN tmux send-keys -t ai-seldri 'cd openpilot' C-m
 
SHELL ["/bin/bash", "-c"]
CMD ["bash"]
# CMD ["bash"]


# RUN wget --load-cookies /tmp/cookies.txt \
#     "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies \
#     /tmp/cookies.txt --keep-session-cookies --no-check-certificate \
#     'https://docs.google.com/uc?export=download&id=1Mh5-4-mfFzHLQVDTrQj5tSxPnIzNM-Bo' \
#     -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1Mh5-4-mfFzHLQVDTrQj5tSxPnIzNM-Bo" \
#     -O aJLL.zip && rm -rf /tmp/cookies.txt