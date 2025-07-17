# Repack Debs

This repository repacks erlang debians in `.debs/` so that they install under `/usr/local/erlang/$otp_ver`, allowing for multiple versions to be installed

To use an installation, source the activation file.

For example, to activate OTP 22:

```
. /usr/local/erlang/22/activate
# OR
source /usr/local/erlang/22/activate
```

## What to be aware of

The repack will mean that Openssl, WX & sctp are no longer required libraries.

To use erlang libraries that depend on these packages, you will need to install these separately.

## Where do I find debs?

Inside the `.debs/` directory, there is a shell script which will download OTP versions from 19 - 27, downloading the latest version at the time of writing this.
