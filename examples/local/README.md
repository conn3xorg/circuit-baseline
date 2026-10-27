# Local example

Applies circuit-baseline to a throwaway Rocky Linux 10 container with systemd. You need Conn3x and Podman.

```sh
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The second plan says `No changes.` To look at the result:

```sh
ssh -p 2222 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 sshd -T | grep -Ei "^(passwordauthentication|permitrootlogin) "
```

`up.sh` listens on `127.0.0.1:2222`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

The container runs with `--privileged` so it can set its own network sysctls. With rootless Podman that stays inside the container. A container also can't set the clock, so the example sets `chrony_set_clock = false`.

`./down.sh` removes the container, the key and the state.
