# This Dockerfile builds an image to test or use the shell environment defined
# in the basnijholt/dotfiles repository (https://github.com/basnijholt/dotfiles).
# It replicates the cross-platform shell configuration described in the README.

FROM ubuntu:25.04

# Install git and zsh (only Git and Git LFS are required!)
RUN apt-get update && apt-get install -y git zsh git-lfs

# Ensure any git@github.com URLs in submodules are fetched via HTTPS in the
# container (no SSH keys in build context)
RUN git config --global url."https://github.com/".insteadOf git@github.com:

# Clone the public branch with submodules (shallow)
RUN git clone --depth 1 --branch public --single-branch \
    --recurse-submodules -j8 --shallow-submodules \
    https://github.com/basnijholt/dotfiles.git ~/dotfiles

# Install the dotfiles
RUN cd ~/dotfiles && ./install || true

# Set the working directory and entrypoint
WORKDIR /root/dotfiles
CMD ["/bin/zsh"]
