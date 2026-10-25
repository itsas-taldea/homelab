# GitLab Runners

> https://docs.gitlab.com/runner/#gitlab-runner-versions
> If you host your own runners but host your repositories on GitLab.com, keep GitLab Runner updated to the latest
> version, as GitLab.com is updated continuously.

> https://docs.gitlab.com/runner/#runner-registration
> Runners usually process jobs on the same machine where you installed GitLab Runner. However, you can also have a
> runner process jobs in a container, in a Kubernetes cluster, or in auto-scaled instances in the cloud.

> https://docs.gitlab.com/runner/#executors
> When you register a runner, you must choose an executor.
> An executor determines the environment each job runs in.
>
> (...)
>
> If you want your CI/CD job to run commands in a custom Docker container, you might install GitLab Runner on a Linux
> server and register a runner that uses the Docker executor.
>
> (...)
>
> When you install GitLab Runner in a Docker container and choose the Docker executor to run your jobs, it’s sometimes
> referred to as a “Docker-in-Docker” configuration.

> https://docs.gitlab.com/runner/#configuring-runners
> You can configure the runner by editing the `config.toml` file. This is a file that is installed during the runner installation process.
> In this file you can edit settings for a specific runner, or for all runners.
> You can specify settings like logging and cache. You can set concurrency, memory, CPU limits, and more.

> https://docs.gitlab.com/runner/#monitoring-runners
> You can use Prometheus to monitor your runners. You can view things like the number of currently-running jobs and how
> much CPU your runners are using.

> https://docs.gitlab.com/runner/#who-has-access-to-runners-in-the-gitlab-ui
> There are three types of runners, based on who you want to have access:
>
> - Shared runners are for use by all projects.
> - Group runners are for all projects and subgroups in a group.
> - Project runners are for individual projects.

## Runner SaaS

> https://docs.gitlab.com/ee/ci/runners/index.html#how-saas-runners-work
> Jobs handled by SaaS runners on GitLab.com time out after 3 hours, regardless of the timeout configured in a project.

## Run GitLab Runner in a container

> https://docs.gitlab.com/runner/install/docker.html
> This setup delegates full control over the Docker daemon to each GitLab Runner container.
> The effect is that isolation guarantees break if you run GitLab Runner inside a Docker daemon that also runs other payloads.

> To set the container’s timezone, in the docker run command, use the flag --env TZ=<TIMEZONE>.
> [View a list of available time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

```
docker run -d --name gitlab-runner --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner:Z \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
```

> https://docs.gitlab.com/runner/install/docker.html#update-configuration
> If you change the configuration in config.toml, you might need to restart the runner to apply the change.
> Make sure to restart the whole container instead of using gitlab-runner restart.

> https://docs.gitlab.com/runner/install/docker.html#upgrade-version
> - Pull the latest version (or a specific tag).
> - Stop and remove the existing container.
> - Start the container as you did originally.

> https://docs.gitlab.com/runner/executors/docker.html#allow-docker-pull-policies
> In the .gitlab-ci.yml file, you can specify a pull policy. This policy determines how a CI/CD job fetches images.
> To restrict which pull policies can be used in the .gitlab-ci.yml file, use allowed_pull_policies.

## Registering runners

Since GitLab 16.0, the runner needs to be defined through the GitLab UI (in either the group or project settings).
Tags, description, and timeout are defined through the web form and a token is generated.
Then, the register command needs to be executed through the gitlab-runner.

> https://docs.gitlab.com/runner/register/index.html#docker

```
register \
  --non-interactive \
  --executor "docker" \
  --docker-image alpine:latest \
  --url "https://gitlab.com/" \
  --token "RUNNER_TOKEN" \
```

## Advanced configuration

> https://docs.gitlab.com/runner/configuration/advanced-configuration.html#example-2-mount-a-host-directory-as-a-data-volume
> When you want to store directories outside the container, you can mount a directory from your Docker daemon’s host into a container:
> [runners.docker]
>   volumes = ["/path/to/bind/from/host:/path/to/bind/in/container:rw"]

## Running gitlab-runner on podman on a LXC container with an NFS mount on Proxmox

In order to mount an NFS share on an LXC container on Proxmox, it needs to be a *privileged* container with feature
``mount=1``; and `nesting=1`, which is enabled by default.

> TODO:
> Test the effect of removing `mount` or `nesting`.

For instance, in the web console of a Debian 12 LXC:

```sh
# Intall podman with docker compatibility, and NFS utilities
$ apt install podman-docker nfs-common
# Edit fstab (see e.g. CT112.orion.fstab)
$ mount -av
# Podman does not creater the bind dirs, it fails if they don't exist
$ mkdir -p /srv/gitlab-runner/config
# Start a runner in a container
$ docker run -d --name gitlab-runner --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner:Z \
  -v /var/run/docker.sock:/var/run/docker.sock \
  docker.io/gitlab/gitlab-runner:latest
$ docker exec -it gitlab-runner bash
# Add the runner through the GitLab UI, and execute the register command with the token
# exit
```

Then, edit the runner configuration in `/srv/gitlab-runner/config/config.toml` to bind volumes and use data on the host,
to use images not available in registries but only locally, or to support `docker:dind` as a privileged service:

```toml
[[runners]]
  environment = [
    "DOCKER_TLS_CERTDIR="
  ]
  [runners.docker]
    privileged = false
    services_privileged = true
    allowed_privileged_services = [
      "docker.io/library/docker:dind",
      "docker:dind"
    ]
    volumes = ["/cache", "/tools/ubuntu22/Xilinx:/tools/Xilinx:ro"]
    allowed_pull_policies = ["always", "if-not-present", "never"]
```

Last, restart the container:

```sh
$ docker restart gitlab-runner
```
