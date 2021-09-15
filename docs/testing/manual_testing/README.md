# Manual testing

We aim to automate as much as we possibly can. Still manual testing is really important for Quality Assurance. 

Here you'll find our manual testing scripts. When developing a new feature you can add your own that provide the proper steps to properly test it. 


## Running Darksidewalletd tests

1. clone [lightwalletd](https://github.com/zcash/lightwalletd.git)
`git clone https://github.com/zcash/lightwalletd.git`

2. on `lightwalletd`'s repo, compile and run lightwalletd in _darkside_ mode
```` bash
make
./lightwalletd --log-file /dev/stdout --darkside-very-insecure  --darkside-timeout 1000 --gen-cert-very-insecure --data-dir . --no-tls-very-insecure
````

3. open Demo App workspace `ZcashLightClientSample.xcworkspace`
4. go to the manage schemes section
5. verify that the `ZcashLightClientKit-Unit-Tests` scheme is shown and shared
6. run the `AdvancedReOrgTests` test suite

## Running DerivationTool tests

1. open Demo App workspace `ZcashLightClientSample.xcworkspace`
2. go to the manage schemes section
3. verify that the `ZcashLightClientKit-Unit-DerivationToolTests` scheme is shown and shared
6. run the `ZcashLightClientKit-Unit-DerivationToolTests` test suite