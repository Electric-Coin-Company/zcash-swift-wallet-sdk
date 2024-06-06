#!/bin/zsh

scriptDir=${0:a:h}
cd "${scriptDir}"

sourcery_version=2.2.5

if which sourcery >/dev/null; then
    if [[ $(sourcery --version) != $sourcery_version ]]; then
        echo "warning: Compatible sourcery version not installed. Install sourcery $sourcery_version. Currently installed version is $(sourcery --version)"
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
