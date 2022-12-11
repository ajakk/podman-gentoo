#!/usr/bin/env bash

if [[ -z ${1} ]]; then
    echo "Needs an argument"
    exit 1
fi

jobs=$(($(nproc)/4))

DOCKERFILE="\
FROM FROMIMAGE

ENV FEATURES \"binpkg-multi-instance\"

RUN ln -srf /etc/portage/world /var/lib/portage/world
RUN mkdir -p /etc/portage/package.unmask
RUN mkdir -p /etc/portage/env
RUN mkdir -p /etc/portage/package.env

ENV MAKEOPTS=\"-j${jobs} -l${jobs}\"
RUN emerge -vuDN @world --with-bdeps=y --quiet=y --buildpkg --usepkg
RUN perl-cleaner --all
RUN emerge --depclean
RUN emerge @preserved-rebuild
RUN eselect news read >/dev/null

CMD \"/bin/bash\""

PODMAN_ARGS="--cap-add=CAP_SYS_ADMIN,CAP_NET_ADMIN,CAP_SYS_PTRACE
--volume ${2}/:/etc/portage
--volume /var/cache/distfiles:/var/cache/distfiles
--volume /var/db/repos:/var/db/repos
--volume ${3}:/var/cache/binpkgs"

target="gentoo/stage3:systemd"

if [[ -n $(podman images localhost/${1} -q) ]] 2>&1 >/dev/null; then
    echo "Rebuilding ${1}"
    target="localhost/${1}"
else
    echo "Building ${1}"
fi

echo "${DOCKERFILE}" | sed "s FROMIMAGE ${target} " | podman build --squash-all ${PODMAN_ARGS} --tag "localhost/${1}" -f - || exit

podman image prune -f
podman push --tls-verify=false "localhost/${1}" "${4}/${1}:latest"
