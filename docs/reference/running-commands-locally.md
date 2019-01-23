This topic describes how to execute commands locally with Docker.

If you wish to use the underlying `om` and `p-automator` CLI tools from your local workstation,
we recommend using docker to execute commands.

With `p-automator` in particular, using Docker is necessary,
as the IaaS CLIs upon which we depend can be tricky to install.
With `om` it's more a matter of convenience -
you can just as easily download the binary if it's available for your system.

##Executing Commands

To execute commands in Docker:

1. First import the image:

```bash
docker import ${PLATFORM_AUTOMATION_IMAGE_TGZ} pcf-automation-image
```

Where `${PLATFORM_AUTOMATION_IMAGE_TGZ}` is the image file downloaded from Pivnet.

2. Then, you can use `docker run` to pass it arbitrary commands.
Here, we're running the `p-automator` CLI to see what commands are available:

```bash
docker run -it --rm -v $PWD:/workspace -w /workspace pcf-automation-image \
p-automator -h
```

Note:  that this will have access read and write files in your current working directory.
If you need to mount other directories as well, you can add additional `-v` arguments.

##Useful Commands

It can be very useful to pull configuration for the director and tiles locally using Docker.

1. To get the staged config for a product:

```bash
docker run -it --rm -v $PWD:/workspace -w /workspace pcf-automation-image \
om --env ${ENV_FILE} staged-config --product-name ${PRODUCT_SLUG} --include-placeholders
```

`${ENV_FILE}` is the [env file] required for all tasks.
`${PRODUCT_SLUG}` is the name of the product downloaded from [pivnet].
The resulting file can then be parameterized, saved, and committed to a config repo.

2. To get the director configuration:

```bash
docker run -it --rm -v $PWD:/workspace -w /workspace pcf-automation-image \
om --env ${ENV_FILE} staged-director-config --include-placeholders
```
