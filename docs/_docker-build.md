```bash
#!/bin/bash -eux

# This task is for building a docker image tarball for a Concourse task.
# Concourse uses runc at its container management, which requires certain artifacts
# to be present in the tarball.
# These artifacts are meta information about the rootfs (docker image).


rm -rf image.tgz
# let's build the actual docker image
# it will platform-automation:latest in `docker images`
docker build -t platform-automation .

# let's use a temp directory to make sure there are no conflicts
base=$(mktemp -d)
export_dir="$base"/export-dir
cidfile="$base"/container_id

mkdir -p "$export_dir"
pushd "$export_dir"
  # drop the image identifier as an artifact
  image_id=$(docker images --no-trunc "platform-automation" | awk "{if (\$2 == \"latest\") print \$3}")
  echo "$image_id" > image-id
  
  # drop the `docker inspect` as an artifact
  docker inspect "$image_id" > docker_inspect.json
  
  # provide metadata on the user and path
  echo '{"user":"root","env":["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","HOME=/root"]}' > metadata.json
  
  # export the files from the `docker build`
  mkdir rootfs
  docker run --cidfile "$cidfile" platform-automation /bin/bash
  docker export "$(cat "$cidfile")" | tar --exclude="dev/*" -xf - -C ./rootfs/
  docker stop "$(cat "$cidfile")"
popd

# compress all the things
tar -czf image.tgz -C "$export_dir" .
```