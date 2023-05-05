#!/bin/zsh

scriptDir=${0:a:h}
cd "${scriptDir}"

sourcery_version=2.0.2

if which sourcery >/dev/null; then
    if [[ $(sourcery --version) != $sourcery_version ]]; then
        echo "warning: Compatible sourcery version not installed. Install sourcer $sourcery_version. Currently installed version is $(sourcery --version)"
        exit 1
    fi

    sourcery \
        --sources ./ \
        --sources ../../../Sources/ \
        --templates AutoMockable.stencil \
        --output GeneratedMocks/

else
  echo "warning: sourcery not installed"
fi



