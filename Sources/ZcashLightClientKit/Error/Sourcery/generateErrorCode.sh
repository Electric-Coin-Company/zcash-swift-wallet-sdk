#!/bin/zsh

scriptDir=${0:a:h}
cd "${scriptDir}"

sourcery_version=2.0.2

if which sourcery >/dev/null; then
    if [[ $(sourcery --version) != $sourcery_version ]]; then
        echo "warning: Compatible sourcer version not installed. Install sourcer $sourcery_version. Currently installed version is $(sourcer --version)"
        exit 1
    fi

    sourcery \
        --disableCache \
        --parseDocumentation \
        --verbose \
        --sources ./ \
        --sources ../ \
        --templates ZcashErrorCode.stencil \
        --output ../ZcashErrorCode.swift

    sourcery \
        --disableCache \
        --parseDocumentation \
        --verbose \
        --sources ./ \
        --sources ../ \
        --templates ZcashError.stencil \
        --output ../ZcashError.swift

else
    echo "warning: sourcery not installed"
fi
