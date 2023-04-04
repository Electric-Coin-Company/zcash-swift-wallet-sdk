#!/bin/zsh

sourcery_version=2.0.1

if which sourcery >/dev/null; then
    if [[ $(sourcery --version) != $sourcery_version ]]; then
        echo "warning: Compatible sourcer version not installed. Install sourcer $sourcery_version. Currently installed version is $(sourcer --version)"
    fi

    sourcery \
        --sources ./ \
        --sources ../../../Sources/ \
        --templates AutoMockable.stencil \
        --output GeneratedMocks/

else
  echo "warning: sourcery not installed"
fi



