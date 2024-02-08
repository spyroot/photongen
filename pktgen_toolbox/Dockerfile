FROM spyroot/dpdk_native_tester:latest
LABEL maintainer="Mustafa Bayramov <spyroot@gmail.com>"
LABEL description="A DPDK 23.11 LTS with pkt gen and photon OS"

RUN yum install -y lua lua-devel lua-libs \
	ncurses ncurses-devel ncurses-compat ncurses-libs ncurses-terminfo

WORKDIR /root/
RUN git clone https://github.com/vim/vim.git && \
    cd vim && \
    ./configure --with-features=huge \
    --enable-python3interp vi_cv_path_python3="/usr/bin/python3" --enable-cscope --enable-multibyte --enable-perlinterp --enable-luainterp --prefix=/usr && \
    make -j 32 && \
    make install

WORKDIR /root/
RUN git clone https://github.com/llvm/llvm-project.git 
RUN cd llvm-project && mkdir build && cd build && \
   cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" ../llvm && \
   make install clang-tidy -j 32

COPY vimrc /root/.vimrc
RUN curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
RUN vim -c "PlugInstall" -c "qa!"
RUN python3 /root/.vim/plugged/YouCompleteMe/install.py --system-libclang --clang-completer --force-sudo

RUN git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
RUN /root/.fzf/install --key-bindings --completion --update-rc

RUN rm -rf /root/llvm-project/
RUN rm -rf /root/build
RUN rm -rf /root/vim
RUN rm -rf /root/intel-ipsec-mb
RUN yum clean all

COPY start.sh /start.sh
WORKDIR /
CMD ["ldconfig; /bin/bash"]

