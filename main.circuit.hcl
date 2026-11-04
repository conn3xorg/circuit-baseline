# Facts tell each host's family apart, since Debian and Ubuntu name the
# sshd and chrony units differently from the Red Hat family.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }
}

locals {
  debian = { for name, f in data.conn3x_host.facts : name => f.os_family == "debian" }

  sshd_file = "/etc/ssh/sshd_config.d/00-conn3x-baseline.conf"
}

circuit "baseline" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "tzdata" {
    package {
      name = "tzdata"
    }
  }

  step "timezone" {
    timezone {
      name = var.timezone
    }
  }

  step "chrony" {
    package {
      name = "chrony"
    }
  }

  # Only when chrony_set_clock is false. In a container, or on a VM whose
  # hypervisor owns the clock, chronyd can't set the time and exits, so -x
  # has it track time without setting it. The rest of each line is the
  # distro's default.
  step "chrony_no_clock" {
    for_each = var.chrony_set_clock ? {} : { no_clock = "-x" }
    line {
      path   = local.debian[each.key] ? "/etc/default/chrony" : "/etc/sysconfig/chronyd"
      regexp = local.debian[each.key] ? "^DAEMON_OPTS=" : "^OPTIONS="
      line   = local.debian[each.key] ? "DAEMON_OPTS=\"-F 1 -x\"" : "OPTIONS=\"-F 2 -x\""
    }
    notify = [handler.restart_chrony]
  }

  step "chrony_running" {
    service {
      name    = local.debian[each.key] ? "chrony" : "chronyd"
      state   = "started"
      enabled = true
    }
  }

  # Minimal images, such as Rocky Linux's container images, ship without it.
  step "sysctl_d" {
    directory {
      path = "/etc/sysctl.d"
    }
  }

  step "sysctl" {
    for_each = var.sysctl
    sysctl {
      name  = item.key
      value = item.value
    }
  }

  # sshd uses the first value it reads for each keyword, and the Include
  # sits at the top of sshd_config on every supported distro, so a drop-in
  # that sorts first wins over sshd_config and the distro's own drop-ins.
  #
  # The new drop-in is tested before it replaces the old one, through a copy
  # of sshd_config that includes every drop-in in the order sshd reads them,
  # with the new one in this one's place. Leaving the old one out lets a fix
  # through on a host where the old one is what sshd rejects.
  step "sshd" {
    file {
      path    = local.sshd_file
      content = join("", [for k, v in var.sshd_settings : "${k} ${v}\n"])
      mode    = "0600"
      validate = join("; ", [
        "set -e",
        "c=%s",
        "m=$(mktemp)",
        "trap 'rm -f \"$m\"' EXIT",
        "inc=",
        "for f in $({ ls -1d /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true; echo ${local.sshd_file}; } | LC_ALL=C sort -u); do if [ \"$f\" = ${local.sshd_file} ]; then inc=\"$inc $c\"; else inc=\"$inc $f\"; fi; done",
        "sed \"s#^Include /etc/ssh/sshd_config\\.d/\\*\\.conf\\$#Include$inc#\" /etc/ssh/sshd_config > \"$m\"",
        "grep -qxF \"Include$inc\" \"$m\" || { echo 'sshd_config has no Include /etc/ssh/sshd_config.d/*.conf line to test the new drop-in in.' >&2; exit 1; }",
        "/usr/sbin/sshd -t -f \"$m\"",
      ])
    }
  }

  # Check the new settings before the handler reloads sshd, so a bad value
  # fails the apply instead of taking sshd down.
  step "sshd_check" {
    command {
      command  = "/usr/sbin/sshd -t"
      triggers = { sshd = conn3x_file.baseline__sshd[each.key].revision }
    }
    notify = [handler.reload_sshd]
  }

  handler "restart_chrony" {
    service {
      name = local.debian[each.key] ? "chrony" : "chronyd"
    }
  }

  handler "reload_sshd" {
    service {
      name   = local.debian[each.key] ? "ssh" : "sshd"
      action = "reload"
    }
  }
}
