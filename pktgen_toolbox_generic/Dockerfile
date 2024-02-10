# Author Mustafa Bayramov
# This image uses as base photon_dpdk23.11 build it include dev tool chain and set of
# tools to benchmark system including packet generation , IO , CPU and memory.


FROM spyroot/dpdk_generic_tester:latest
LABEL maintainer="Mustafa Bayramov <spyroot@gmail.com>"
LABEL description="A packet generation and dev toolbox it include iperf3, netsniff-ng, Intel MLC, fio, DPKD and many other tools"

RUN yum install -y tree lua lua-devel lua-libs \
    fio python3-curses ncurses ncurses-devel \
    ncurses-compat ncurses-libs ncurses-terminfo \
    userspace-rcu userspace-rcu-devel libnetfilter_conntrack libsodium libsodium-devel \
    libnetconf2 libnetconf2-devel libnl libnl-devel \
    libnetfilter_conntrack-devel go rust cppcheck python3-autopep8  \
    nodejs nodejs-devel fontconfig socat && \
    yum clean all && \
    rm -rf /var/cache/yum

WORKDIR /root/
RUN git clone https://github.com/vim/vim.git && \
    cd vim && \
    ./configure --with-features=huge \
    --enable-shared \
    --enable-python3interp vi_cv_path_python3="/usr/bin/python3" \
    --enable-cscope --enable-multibyte --enable-perlinterp --enable-luainterp --prefix=/usr && \
    make -j 32 && \
    make install && \
    cd .. && rm -rf vim

WORKDIR /root/
COPY vimrc /root/.vimrc
COPY bashrc ~/.bashrc

RUN curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
RUN vim -c "PlugInstall" -c "qa!"
RUN python3 /root/.vim/plugged/YouCompleteMe/install.py --clang-completer --clangd-completer --go-completer --rust-completer --force-sudo

RUN git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
RUN /root/.fzf/install --key-bindings --completion --update-rc

WORKDIR /root/
RUN git clone https://github.com/kdlucas/byte-unixbench.git ~/unixbench
RUN mkdir -p ~/mlc && wget https://downloadmirror.intel.com/793041/mlc_v3.11.tgz -P ~/ && tar -xzvf ~/mlc_v3.11.tgz -C ~/mlc

RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
RUN bash ~/miniconda.sh -b -p $HOME/miniconda
RUN eval "$(~/miniconda/bin/conda shell.bash hook)" && conda init
RUN yum install -y python3-curses && pip3 install 'glances[all]'

RUN git clone https://github.com/libnet/libnet.git ~/libnet && cd ~/libnet && \
    ./autogen.sh && ./configure > configure.log && make -j 32 && make install \
    && cd .. && rm -rf ~/libnet

RUN git clone https://github.com/netsniff-ng/netsniff-ng.git ~/netsniff && \
    cd ~/netsniff && ./configure > configure.log && make -j 32 && make install && \
    cd .. && rm -rf ~/netsniff

RUN rm -rf ~/mlc/Windows && rm -rf ~/mlc_v3.11.tgz && \
    rm -rf /root/build && rm -rf /root/vim && rm -rf /root/intel-ipsec-mb
RUN yum clean all

RUN git clone --recursive https://github.com/jqlang/jq.git ~/jq && \
		cd ~/jq && autoreconf -i && \
		./configure && make -j 32 && make install && cd .. && rm -rf ~/jq

RUN git clone https://github.com/powerline/fonts.git --depth=1 ~/fs && \
    cd ~/fs && ./install.sh && cd / && rm -rf ~/fs

RUN git clone https://github.com/sharkdp/fd.git ~/fd_find && \
    cd ~/fd_find && make && make install && cd / && rm -rf ~/fd_find

RUN pip3 install yamllint gitlab_lint pynvim jedi
RUN eval "$(~/miniconda/bin/conda shell.bash hook)" && conda install -y shellcheck
COPY *.sh /
COPY yamllint_config ~/.config/yamllint/config

RUN go install github.com/google/yamlfmt/cmd/yamlfmt@latest && /root/go/bin/yamlfmt
RUN go install github.com/justjanne/powerline-go@latest

RUN vim -c "PlugUpdate" -c "qa!"

#docker exec -it --env COLUMNS=`tput cols` --env LINES=`tput lines` container_name bash
COPY bashrc /root/bashrc_template
RUN cat /root/bashrc_template >> /root/.bashrc

WORKDIR /
CMD ["ldconfig; /bin/bash"]