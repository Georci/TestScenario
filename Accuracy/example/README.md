# test instruction

1.  protect your private_key

    ```
        cast wallet import <key_store_name> -i
    ```

    execute it,then you should input your private_key and password,remember password.

2.  execute script

    ```
         forge script script/replay.s.sol --tc CreateEnv --rpc-url "<your rpc>" --broadcast --account "<key_store_name>" -vvvvv
    ```

    execute it ,then you should input your password
    rpc : https://lb.drpc.org/ogrpc?network=holesky&dkey=AvZwUDJNQ0H-rfHFUNlC228dOWBjNHER76RXhkHL9tz4

    example:

    ```
         forge script script/replay.s.sol --tc CreateEnv --rpc-url "https://1rpc.io/holesky" --broadcast --account "Metamask" -vvvvv
    ```

    then you should remember the key address:

           1. AttackerFirst
           2. AttackerSecond
           3. BEVO

    the firewall key address is:

        FirewallDeployer Address 0x386d2Db88D3b1809baaCd66C43665Be9A1775EDC
        param_detect Address 0x6107FC1c359ABac9644461E2e85A26e095750AFb
        proxy_registry Address 0x1D603a12BA49b38265031DFb7B9fA9917f85291B

3.  try attack

                ```
                    cast send <attacker Address> "attack()" --rpc-url "https://1rpc.io/holesky" --account "Metamask"
                ```

    example

                ```
                    cast send 0x50e15a7A6057e817B00E5Bb036728A090A152986 "attack()" --rpc-url "https://1rpc.io/holesky" --account "Metamask"
                ```

4.  key Address

            Firewall Address 0x28B29067ee136542C509F24CF5d225667237D550
            param_detect Address 0xc6402fd79576052379640a29adcf0d26040f2434
            proxy_registry Address 0x4ed7a7a906d767f9aeaa4f8d9b96332b43c62a4e
            reen_detect Address 0x9e31a838ca49a45dfc0a934eed64589e67f912cb
            auth_detect Address 0x5bb326cf885e0b46fc0ef4f98b335eed0250efe9

    BEVO Address 0xd32926Bb81358304AFa387f991b6C9AE326dAc22
    first attacker address 0x50e15a7A6057e817B00E5Bb036728A090A152986
    second attacker address 0xacbB992c5c8D9efc2364b0DD6aEbcD7171452Af2
