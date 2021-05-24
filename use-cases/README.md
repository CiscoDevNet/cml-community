# CML Use Cases

This directory consists of Git submodules for other repositories that contain uses cases for CML and build off of
CML's powerful REST API (and Python Client Library).

## Using

By default, git doesn't pull down the submodules content.  You can cause it to clone all of the submodules by doing the
following:

```sh
git submodule init
git submodule update
```

If you haven't yet cloned the `cml-community` repo, you can use the following command to clone it and pull down all the
submodules:

```sh
git clone --recuse-submodules https://github.com/CiscoDevNet/cml-community
```

## Contributing

If you have a Git repo (doesn't even have to be on GitHub) that contains a use case for CML, submit a pull request or
issue to get it added.  We'd love to see how you're using CML.
