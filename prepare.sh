if [ ! -d lib ]; then 
    mkdir -p  lib
fi
pushd .
cd lib
touch libzcashlc.a
popd